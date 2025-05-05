@echo off
setlocal EnableDelayedExpansion

:: Prompt for Jenkins credentials and GitHub details
set /p JENKINS_URL="Enter Jenkins URL (e.g., http://localhost:8080): "
set /p JENKINS_USER="Enter Jenkins username: "
set /p JENKINS_PASS="Enter Jenkins password (or API token): "
set /p JOB_NAME="Enter the name of the new Jenkins job (e.g., Multibranch_Test): "
set /p GITHUB_REPO="Enter GitHub repository URL (e.g., https://github.com/labbuddy-development/jenkins_test.git): "
set /p GITHUB_USER="Enter GitHub username: "
set /p GITHUB_TOKEN="Enter GitHub personal access token: "

:: Normalize JENKINS_URL (remove trailing slash)
set "JENKINS_URL=!JENKINS_URL: =!"
if "!JENKINS_URL:~-1!"=="/" set "JENKINS_URL=!JENKINS_URL:~0,-1!"

:: Step 1: Attempt to fetch Jenkins CSRF crumb
echo Fetching CSRF crumb from !JENKINS_URL!/crumbIssuer...
curl -s -u "!JENKINS_USER!:!JENKINS_PASS!" "!JENKINS_URL!/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb)" > crumb.txt
if !ERRORLEVEL! neq 0 (
    echo Failed to fetch CSRF crumb. Check if curl is installed or if Jenkins URL/credentials are correct.
    del crumb.txt
    exit /b 1
)

:: Read the crumb from the file and validate it
set /p CRUMB=<crumb.txt
del crumb.txt
if "!CRUMB!"=="" (
    echo CSRF crumb is empty. This might happen if CSRF protection is disabled in Jenkins.
    echo Trying to proceed without a CSRF crumb...
    set "CRUMB="
) else (
    :: Verify crumb format (should be like "Jenkins-Crumb:crumb_value")
    echo CSRF crumb fetched: !CRUMB!
    echo !CRUMB! | findstr /R "^[A-Za-z-]*:[0-9a-f]*$" >nul
    if !ERRORLEVEL! neq 0 (
        echo Invalid CSRF crumb format. Expected format: "Jenkins-Crumb:crumb_value".
        echo Trying to proceed without a CSRF crumb...
        set "CRUMB="
    )
)

:: Step 2: Create a new credential in Jenkins
echo Creating a new credential in Jenkins for GitHub access...
:: Generate a unique credential ID (using timestamp for simplicity)
for /f "tokens=1-4 delims=/:." %%a in ("!TIME!") do set "CREDENTIAL_ID=github-credential-%%a%%b%%c%%d"

:: Create credential.json with proper JSON formatting
(
echo {
echo   "credentials": {
echo     "scope": "GLOBAL",
echo     "id": "!CREDENTIAL_ID!",
echo     "username": "!GITHUB_USER!",
echo     "password": "!GITHUB_TOKEN!",
echo     "description": "GitHub credential for !GITHUB_USER!",
echo     "$class": "com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl"
echo   }
echo }
) > credential.json

:: Debug: Display the contents of credential.json to verify
echo Verifying credential.json contents:
type credential.json
echo.

:: Send the request to create the credential in the global domain
if defined CRUMB (
    echo Using CSRF crumb to create credential: !CRUMB!
    curl -s -u "!JENKINS_USER!:!JENKINS_PASS!" -H "!CRUMB!" -X POST "!JENKINS_URL!/credentials/store/system/domain/_/createCredentials" --data-binary "@credential.json" -H "Content-Type: application/json"
) else (
    echo CSRF crumb not used for credential creation.
    curl -s -u "!JENKINS_USER!:!JENKINS_PASS!" -X POST "!JENKINS_URL!/credentials/store/system/domain/_/createCredentials" --data-binary "@credential.json" -H "Content-Type: application/json"
)
if !ERRORLEVEL! neq 0 (
    echo Failed to create GitHub credential in Jenkins. Check the Jenkins URL, credentials, or CSRF settings.
    echo Also, ensure the credential.json file contains valid JSON and the GitHub username/token do not contain special characters that break JSON.
    del credential.json
    exit /b 1
)

:: Clean up credential.json
del credential.json
echo Successfully created credential with ID: !CREDENTIAL_ID!

:: Step 3: Create config.xml for the Multibranch Pipeline
echo Creating config.xml for the Multibranch Pipeline...
(
echo ^<?xml version='1.1' encoding='UTF-8'?^>
echo ^<org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject plugin="workflow-multibranch@2.26"^>
echo   ^<actions/^>
echo   ^<description^>Testing the multi branch pipeline with github repo^</description^>
echo   ^<displayName^>!JOB_NAME!^</displayName^>
echo   ^<properties/^>
echo   ^<sources class="jenkins.branch.MultiBranchProject$BranchSourceList" plugin="branch-api@2.7.0"^>
echo     ^<data^>
echo       ^<jenkins.branch.BranchSource^>
echo         ^<source class="jenkins.plugins.git.GitSCMSource" plugin="git@5.0.0"^>
echo           ^<id^>!JOB_NAME!-source^</id^>
echo           ^<remote^>!GITHUB_REPO!^</remote^>
echo           ^<credentialsId^>!CREDENTIAL_ID!^</credentialsId^>
echo           ^<traits^>
echo             ^<jenkins.plugins.git.traits.BranchDiscoveryTrait/^>
echo             ^<jenkins.plugins.git.traits.PruneStaleBranchTrait/^>
echo           ^</traits^>
echo         ^</source^>
echo         ^<strategy class="jenkins.branch.DefaultBranchPropertyStrategy"^>
echo           ^<properties class="java.util.Arrays$ArrayList"^>
echo             ^<a class="jenkins.branch.BranchProperty-array"/^>
echo           ^</properties^>
echo         ^</strategy^>
echo       ^</jenkins.branch.BranchSource^>
echo     ^</data^>
echo     ^<owner class="org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject" reference="../.."/^>
echo   ^</sources^>
echo   ^<factory class="org.jenkinsci.plugins.workflow.multibranch.WorkflowBranchProjectFactory"^>
echo     ^<owner class="org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject" reference="../.."/^>
echo     ^<scriptPath^>Jenkinsfile^</scriptPath^>
echo   ^</factory^>
echo   ^<triggers^>
echo     ^<org.jenkinsci.plugins.workflow.multibranch.PipelineTriggerSchedule^>
echo       ^<spec/^>
echo       ^<interval^>120000^</interval^>
echo     ^</org.jenkinsci.plugins.workflow.multibranch.PipelineTriggerSchedule^>
echo   ^</triggers^>
echo   ^<orphanedItemStrategy class="com.cloudbees.hudson.plugins.folder.computed.DefaultOrphanedItemStrategy" plugin="cloudbees-folder@6.815.v0dd5a_cb_40e0e"^>
echo     ^<pruneDeadBranches^>true^</pruneDeadBranches^>
echo     ^<daysToKeep^>2^</daysToKeep^>
echo     ^<numToKeep^>2^</numToKeep^>
echo   ^</orphanedItemStrategy^>
echo ^</org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject^>
) > config.xml

:: Step 4: Create the new job using the Jenkins REST API
echo Creating new Multibranch Pipeline job: !JOB_NAME!...
if defined CRUMB (
    echo Using CSRF crumb to create job: !CRUMB!
    curl -s -u "!JENKINS_USER!:!JENKINS_PASS!" -H "!CRUMB!" -X POST "!JENKINS_URL!/createItem?name=!JOB_NAME!" --data-binary "@config.xml" -H "Content-Type: application/xml"
) else (
    echo CSRF crumb not used for job creation. If this fails, enable CSRF protection in Jenkins or use an API token.
    curl -s -u "!JENKINS_USER!:!JENKINS_PASS!" -X POST "!JENKINS_URL!/createItem?name=!JOB_NAME!" --data-binary "@config.xml" -H "Content-Type: application/xml"
)
if !ERRORLEVEL! neq 0 (
    echo Failed to create Jenkins job. Check the Jenkins URL, credentials, job name, or configuration.
    echo If using a password, try using an API token instead: Jenkins > Your Username > Configure > API Token > Generate.
    echo If the error persists, ensure CSRF protection is enabled: Manage Jenkins > Configure Global Security > Check "Enable CSRF Protection".
    del config.xml
    exit /b 1
)

:: Clean up
del config.xml
echo Successfully created Multibranch Pipeline job: !JOB_NAME!
echo You can now view it at: !JENKINS_URL!/job/!JOB_NAME!/
exit /b 0
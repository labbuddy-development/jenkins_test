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

:: Create JSON for the credential creation request
(
echo {
echo   "": "0",
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

:: FIXED METHOD 1: Use the Jenkins form-based credential creation API
echo Attempting to create credential using form-based API...
if defined CRUMB (
    curl -s -X POST -u "!JENKINS_USER!:!JENKINS_PASS!" ^
         -H "!CRUMB!" ^
         "!JENKINS_URL!/credentials/store/system/domain/_/createCredentials" ^
         --form "json=<credential.json"
) else (
    curl -s -X POST -u "!JENKINS_USER!:!JENKINS_PASS!" ^
         "!JENKINS_URL!/credentials/store/system/domain/_/createCredentials" ^
         --form "json=<credential.json"
)

:: If the credential creation fails, try an alternative method
if !ERRORLEVEL! neq 0 (
    echo First credential creation attempt failed. Trying alternative method...
    
    :: FIXED METHOD 2: Use the Jenkins script console to create the credential
    echo Creating a single-line Groovy script for credential creation...
    
    :: Create a single-line groovy script (escaping special characters)
    set "GROOVY_SCRIPT=import com.cloudbees.plugins.credentials.impl.*; import com.cloudbees.plugins.credentials.*; import com.cloudbees.plugins.credentials.domains.*; def credentialsId = '!CREDENTIAL_ID!'; def username = '!GITHUB_USER!'; def password = '!GITHUB_TOKEN!'; def description = 'GitHub credential for !GITHUB_USER!'; def credentials = new UsernamePasswordCredentialsImpl(CredentialsScope.GLOBAL, credentialsId, description, username, password); SystemCredentialsProvider.getInstance().getStore().addCredentials(Domain.global(), credentials); println('Credential created successfully with ID: ' + credentialsId);"
    
    echo !GROOVY_SCRIPT! > groovy_oneline.txt
    
    if defined CRUMB (
        curl -s -X POST -u "!JENKINS_USER!:!JENKINS_PASS!" ^
             -H "!CRUMB!" ^
             "!JENKINS_URL!/scriptText" ^
             --data-urlencode "script=!GROOVY_SCRIPT!"
    ) else (
        curl -s -X POST -u "!JENKINS_USER!:!JENKINS_PASS!" ^
             "!JENKINS_URL!/scriptText" ^
             --data-urlencode "script=!GROOVY_SCRIPT!"
    )
    
    del groovy_oneline.txt
    

)

:: Clean up credential.json
del credential.json
echo Credential creation attempt complete. Verify in Jenkins that credential ID: !CREDENTIAL_ID! exists.

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
echo     ^<com.cloudbees.hudson.plugins.folder.computed.PeriodicFolderTrigger plugin="cloudbees-folder@6.815.v0dd5a_cb_40e0e"^>
echo       ^<spec^>H/5 * * * *^</spec^>
echo       ^<interval^>300000^</interval^>
echo     ^</com.cloudbees.hudson.plugins.folder.computed.PeriodicFolderTrigger^>
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
    del config.xml
    exit /b 1
)

:: Clean up
del config.xml
echo Successfully created Multibranch Pipeline job: !JOB_NAME!
echo You can now view it at: !JENKINS_URL!/job/!JOB_NAME!/
exit /b 0
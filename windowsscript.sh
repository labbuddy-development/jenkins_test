# PowerShell Script to Install and Configure Jenkins on Windows

# Set variables
$jenkinsUrl = "http://localhost:8080"
$adminUser = "admin"
$adminPassword = "labuddy@123"
$jenkinsHome = "$Env:ProgramData\Jenkins"

# Install Chocolatey (if not already installed)
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# Install Java, Jenkins, curl, and wget
choco install openjdk --version=21 -y
choco install jenkins -y
choco install curl wget -y

# Wait for Jenkins service to start
Start-Sleep -Seconds 30

# Disable Jenkins Setup Wizard
$jenkinsXml = "$Env:ProgramData\Jenkins\jenkins.xml"
if (Test-Path $jenkinsXml) {
    (Get-Content $jenkinsXml) -replace '<arguments>.*?</arguments>', '<arguments>-Djenkins.install.runSetupWizard=false</arguments>' | Set-Content $jenkinsXml
    Restart-Service jenkins
    Start-Sleep -Seconds 30
}

# Create init Groovy script for admin user
$groovyInitPath = "$jenkinsHome\init.groovy.d"
New-Item -ItemType Directory -Force -Path $groovyInitPath

@'
#!groovy
import jenkins.model.*
import hudson.security.*
def instance = Jenkins.getInstance()
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "labuddy@123")
instance.setSecurityRealm(hudsonRealm)
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)
instance.setInstallState(jenkins.install.InstallState.INITIAL_SETUP_COMPLETED)
instance.save()
'@ | Out-File "$groovyInitPath\basic-security.groovy" -Encoding UTF8

# Disable CSRF
@'
#!groovy
import jenkins.model.*
instance = Jenkins.getInstance()
instance.setCrumbIssuer(null)
instance.save()
'@ | Out-File "$groovyInitPath\disable-csrf.groovy" -Encoding UTF8

# Restart Jenkins to apply Groovy scripts
Restart-Service jenkins
Start-Sleep -Seconds 60

# Download Jenkins CLI
Invoke-WebRequest "$jenkinsUrl/jnlpJars/jenkins-cli.jar" -OutFile "$env:TEMP\jenkins-cli.jar"

# Create plugin list
$plugins = @"
antisamy-markup-formatter
git
ldap
mailer
matrix-auth
pam-auth
pipeline-model-definition
pipeline-stage-view
pipeline-github-lib
ssh-slaves
timestamper
email-ext
workflow-aggregator
workflow-job
github-branch-source
gradle
ant
dark-theme
ws-cleanup
cloudbees-folder
github
workflow-basic-steps
"@ -split "`n"

# Install Jenkins plugins
foreach ($plugin in $plugins) {
    if ($plugin.Trim()) {
        java -jar "$env:TEMP\jenkins-cli.jar" -s $jenkinsUrl -auth "${adminUser}:$adminPassword" install-plugin $plugin.Trim()
    }
}

# Final Jenkins restart
Restart-Service jenkins

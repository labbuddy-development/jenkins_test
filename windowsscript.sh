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

# Install required packages
choco install openjdk --version=21 -y
choco install jenkins -y
choco install curl wget -y

# Wait for Jenkins installation
Start-Sleep -Seconds 30

# Fix jenkins.xml to skip setup wizard
$jenkinsXml = "$jenkinsHome\jenkins.xml"
if (Test-Path $jenkinsXml) {
    (Get-Content $jenkinsXml) -replace '<arguments>.*?</arguments>', '<arguments>-Djenkins.install.runSetupWizard=false</arguments>' | Set-Content $jenkinsXml
}

# Start Jenkins service (fix service name if different)
Start-Service jenkins
Start-Sleep -Seconds 60

# Confirm Jenkins is running
if (-not (Get-Service jenkins -ErrorAction SilentlyContinue)) {
    Write-Error "Jenkins service not found. Check if Jenkins installed properly."
    exit 1
}

# Create Groovy init script directory with admin rights
$groovyInitPath = "$jenkinsHome\init.groovy.d"
if (-not (Test-Path $groovyInitPath)) {
    New-Item -ItemType Directory -Force -Path $groovyInitPath
}

# Write admin user script
$basicSecurityScript = @'
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
'@

$basicSecurityScript | Set-Content -Path "$groovyInitPath\basic-security.groovy" -Encoding UTF8 -Force

# Write disable CSRF script
$disableCsrfScript = @'
#!groovy
import jenkins.model.*
instance = Jenkins.getInstance()
instance.setCrumbIssuer(null)
instance.save()
'@

$disableCsrfScript | Set-Content -Path "$groovyInitPath\disable-csrf.groovy" -Encoding UTF8 -Force

# Restart Jenkins to apply Groovy scripts
Restart-Service jenkins
Start-Sleep -Seconds 60

# Download Jenkins CLI (try multiple times if necessary)
$cliPath = "$env:TEMP\jenkins-cli.jar"
$cliDownloaded = $false
for ($i = 0; $i -lt 5; $i++) {
    try {
        Invoke-WebRequest "$jenkinsUrl/jnlpJars/jenkins-cli.jar" -OutFile $cliPath -UseBasicParsing -ErrorAction Stop
        $cliDownloaded = $true
        break
    } catch {
        Start-Sleep -Seconds 15
    }
}
if (-not $cliDownloaded) {
    Write-Error "Failed to download Jenkins CLI after multiple attempts."
    exit 1
}

# Install plugins
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

foreach ($plugin in $plugins) {
    if ($plugin.Trim()) {
        java -jar $cliPath -s $jenkinsUrl -auth "${adminUser}:$adminPassword" install-plugin $plugin.Trim()
    }
}

# Final Jenkins restart
Restart-Service jenkins

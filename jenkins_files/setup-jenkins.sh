#!/bin/bash
set -e

echo "Starting Jenkins offline setup..."

# Install necessary packages
sudo apt update
sudo apt install -y openjdk-21-jdk curl wget

# Add Jenkins GPG key and repo
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | sudo tee /etc/apt/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install -y jenkins

# Disable Jenkins setup wizard
echo 'JAVA_ARGS="-Djenkins.install.runSetupWizard=false"' | sudo tee /etc/default/jenkins

# Create admin user and disable CSRF via Groovy
sudo mkdir -p /var/lib/jenkins/init.groovy.d

cat <<'EOF' | sudo tee /var/lib/jenkins/init.groovy.d/basic-security.groovy
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
EOF

cat <<'EOF' | sudo tee /var/lib/jenkins/init.groovy.d/disable-csrf.groovy
#!groovy
import jenkins.model.*
def instance = Jenkins.getInstance()
instance.setCrumbIssuer(null) // Disable CSRF protection
instance.save()
EOF

# Set ownership
sudo chown -R jenkins:jenkins /var/lib/jenkins

# Start Jenkins
sudo systemctl restart jenkins
sleep 60

# Download Jenkins CLI
wget http://localhost:8080/jnlpJars/jenkins-cli.jar -O /tmp/jenkins-cli.jar

# Define required plugins
cat <<EOF > /tmp/plugins.txt
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
EOF

# Install plugins using Jenkins CLI
for plugin in $(cat /tmp/plugins.txt); do
  java -jar /tmp/jenkins-cli.jar -s http://localhost:8080 -auth admin:labuddy@123 install-plugin "$plugin"
done

# Final Jenkins restart
sudo systemctl restart jenkins

echo "Jenkins setup complete."

pipeline {
    agent any

    triggers {
        // Poll SCM for changes in any branch, checking every 2 minutes
        pollSCM('H/2 * * * *')
    }

    stages {
        stage('Checkout') {
            steps {
                // Checkout the specific branch dynamically using the BRANCH_NAME variable
                checkout scmGit(
                    branches: [[name: "*/${env.BRANCH_NAME}"]],
                    extensions: [],
                    userRemoteConfigs: [[
                        credentialsId: 'aa2cabb1-2bd4-4521-bbf0-dc9b47a7f758',
                        url: 'https://github.com/labbuddy-development/jenkins_test.git'
                    ]]
                )
            }
        }
        stage('Check Readme Change') {
            when {
                // Only proceed if README.md has changed
                changeset pattern: "(?i)^README\\.md\\$", caseSensitive: false
            }
            stages {
                stage('Run Tests') {
                    steps {
                        bat '''
                            python test.py
                        '''
                    }
                }
            }
        }
    }
}

// Note: The following configurations should be set up in Jenkins to fully implement the requested features:
// 1. Enable "GitHub Branch Source Plugin" to automatically detect and create jobs for new branches
// 2. Configure the Jenkins job as a "Multibranch Pipeline" to handle multiple branches
// 3. Enable "Prune stale branches" in the Branch Source configuration to automatically delete jobs for deleted branches
// 4. The pollSCM trigger ensures the pipeline runs when changes are detected in any branch
pipeline {
    agent any

    triggers {
        // Poll SCM for changes in any branch, checking every 2 minutes
        pollSCM('H/2 * * * *')
    }

    stages {
        stage('Checkout') {
            steps {
                // Checkout the specific branch with full commit history (no shallow clone)
                checkout scmGit(
                    branches: [[name: "*/${env.BRANCH_NAME}"]],
                    extensions: [[$class: 'CloneOption', shallow: false, depth: 0, noTags: false, reference: '']],
                    userRemoteConfigs: [[
                        credentialsId: ' github-credential-17093581', // it should be changed if using evry new job
                        url: 'https://github.com/labbuddy-development/jenkins_test.git' // it should be changed if using evry new job
                    ]]
                )
            }
        }
        stage('Debug Changeset') {
            steps {
                script {
                    // Print the list of changed files to debug the changeset condition
                    def changeLogSets = currentBuild.changeSets
                    for (changeLogSet in changeLogSets) {
                        for (entry in changeLogSet) {
                            for (file in entry.affectedFiles) {
                                echo "Changed file: ${file.path}"
                            }
                        }
                    }
                }
            }
        }
        stage('Check Readme Change') {
            when {
                // Trigger this stage if README.md (case-insensitive) is modified in any directory
                anyOf {
                    changeset pattern: /(?i).*README\.md/, caseSensitive: false
                    expression {
                        // Fallback: Check changeset manually for README.md
                        def changeLogSets = currentBuild.changeSets
                        for (changeLogSet in changeLogSets) {
                            for (entry in changeLogSet) {
                                for (file in entry.affectedFiles) {
                                    if (file.path.toLowerCase().contains('readme.md')) {
                                        return true
                                    }
                                }
                            }
                        }
                        return false
                    }
                }
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
// 1. Make Sure "GitHub Branch Source Plugin" is enabled to automatically detect and create jobs for new branches
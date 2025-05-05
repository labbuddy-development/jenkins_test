pipeline {
    agent any

    // triggers {
    //     // Poll SCM for changes in any branch, checking every 2 minutes
    //     pollSCM('H/2 * * * *')
    // }

    stages {
        stage('Checkout') {
            steps {
                // Checkout the specific branch with full commit history (no shallow clone)
                checkout scmGit(
                    branches: [[name: "*/${env.BRANCH_NAME}"]],
                    extensions: [[$class: 'CloneOption', shallow: false, depth: 0, noTags: false, reference: '']],
                    userRemoteConfigs: [[
                        credentialsId: 'aa2cabb1-2bd4-4521-bbf0-dc9b47a7f758',
                        url: 'https://github.com/labbuddy-development/jenkins_test.git'
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
// 1. Enable "GitHub Branch Source Plugin" to automatically detect and create jobs for new branches
// 2. Configure the Jenkins job as a "Multibranch Pipeline" to handle multiple branches
// 3. Enable "Prune stale branches" in the Branch Source configuration to automatically delete jobs for deleted branches
// 4. Set up a GitHub webhook to trigger builds immediately on push (recommended over pollSCM)
// 5. Ensure README.md is modified and pushed to the repository to trigger the 'Check Readme Change' stage
// 6. Check the 'Debug Changeset' stage output in the build log to verify which files Jenkins detects as changed
// 7. SCM settings updated in the Jenkinsfile to disable shallow clone and fetch full commit history
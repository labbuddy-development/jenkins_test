pipeline {
    agent any

    triggers {
        cron('H/2 * * * *') // runs every 2 minutes
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scmGit(branches: [[name: '*/main']], extensions: [], userRemoteConfigs: [[credentialsId: 'aa2cabb1-2bd4-4521-bbf0-dc9b47a7f758', url: 'https://github.com/labbuddy-development/jenkins_test.git']])
            }
        }
        stage('Run Tests') {
            steps {
                bat '''
                    python test.py
                '''
            }
        }
    }
}

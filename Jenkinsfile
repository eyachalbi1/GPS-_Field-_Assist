pipeline {
    agent any

    environment {
        BACKEND_DIR = 'backend'
        MOBILE_DIR = 'mobile'
        DOCKER_IMAGE = 'gps-field-assist-backend'
        REGISTRY = 'localhost:5000'
        SONAR_HOST_URL = 'http://sonarqube:9000'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    echo "Code source récupéré depuis ${env.GIT_URL}"
                }
            }
        }

        stage('Backend - Install') {
            steps {
                dir("${BACKEND_DIR}") {
                    sh '''
                        python -m pip install --upgrade pip
                        pip install -r requirements.txt
                    '''
                }
            }
        }

        stage('Backend - Lint') {
            steps {
                dir("${BACKEND_DIR}") {
                    sh 'flake8 .'
                }
            }
            post {
                always {
                    publishHTML([
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'htmlcov',
                        reportFiles: 'index.html',
                        reportName: 'Flake8 Lint Report'
                    ])
                }
            }
        }

        stage('Backend - Test') {
            steps {
                dir("${BACKEND_DIR}") {
                    sh '''
                        pytest tests/ --cov=src --cov-report=html --cov-report=term --cov-report=xml
                    '''
                }
            }
            post {
                always {
                    publishHTML([
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'htmlcov',
                        reportFiles: 'index.html',
                        reportName: 'Test Coverage Report'
                    ])
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    dir("${BACKEND_DIR}") {
                        sh '''
                            sonar-scanner \
                              -Dsonar.projectKey=gps-field-assist \
                              -Dsonar.projectName="GPS Field Assist" \
                              -Dsonar.sources=. \
                              -Dsonar.exclusions=**/tests/**,**/__pycache__/**,**/htmlcov/**,**/*.bat,**/*.sh \
                              -Dsonar.python.coverage.reportPaths=coverage.xml \
                              -Dsonar.host.url=${SONAR_HOST_URL}
                        '''
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Backend - Docker Build') {
            steps {
                script {
                    sh "docker build -t ${DOCKER_IMAGE}:${env.BUILD_ID} ./backend"
                    sh "docker tag ${DOCKER_IMAGE}:${env.BUILD_ID} ${DOCKER_IMAGE}:latest"
                }
            }
        }

        stage('Backend - Docker Deploy') {
            steps {
                script {
                    sh 'docker-compose down backend || true'
                    sh 'docker-compose up -d backend'
                    sh 'sleep 10'
                    sh 'curl -f http://localhost:8001/health || exit 1'
                }
            }
        }

        stage('Flutter - Setup') {
            steps {
                dir("${MOBILE_DIR}") {
                    sh 'flutter pub get'
                }
            }
        }

        stage('Flutter - Analyze') {
            steps {
                dir("${MOBILE_DIR}") {
                    sh 'flutter analyze'
                }
            }
        }

        stage('Flutter - Build APK') {
            steps {
                dir("${MOBILE_DIR}") {
                    sh 'flutter build apk --release'
                }
            }
        }

        stage('Archive APK') {
            steps {
                archiveArtifacts artifacts: 'mobile/build/app/outputs/flutter-apk/app-release.apk', fingerprint: true
                archiveArtifacts artifacts: 'backend/htmlcov/**/*', fingerprint: true
            }
        }

        stage('Cleanup') {
            steps {
                script {
                    sh 'docker system prune -f --filter "until=24h" || true'
                }
            }
        }
    }

    post {
        success {
            slackSend channel: '#deployments', message: "✅ Build #${env.BUILD_NUMBER} réussi - Application déployée sur http://localhost:8001"
            emailext (
                subject: "✅ GPS Field Assist - Build #${env.BUILD_NUMBER} SUCCESS",
                body: "Le build ${env.BUILD_NUMBER} a été déployé avec succès.\n\nBackend: http://localhost:8001\nAPK disponible dans les artifacts.",
                to: "devops@tunav-it.com"
            )
        }
        failure {
            slackSend channel: '#deployments', message: "❌ Build #${env.BUILD_NUMBER} échoué - Voir logs Jenkins"
            emailext (
                subject: "❌ GPS Field Assist - Build #${env.BUILD_NUMBER} FAILED",
                body: "Le build ${env.BUILD_NUMBER} a échoué. Consultez Jenkins pour plus de détails.",
                to: "devops@tunav-it.com"
            )
        }
        always {
            cleanWs()
        }
    }
}

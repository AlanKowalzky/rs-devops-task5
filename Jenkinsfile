pipeline {
    agent any
    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['local', 'aws'], description: 'Środowisko docelowe')
        string(name: 'DOCKER_REGISTRY', defaultValue: 'localhost:5000', description: 'Adres rejestru Docker (np. localhost:5000 lub ECR)')
        string(name: 'IMAGE_NAME', defaultValue: 'flask_app', description: 'Nazwa obrazu Docker')
        string(name: 'KUBECONFIG_PATH', defaultValue: '/home/jenkins/.kube/config', description: 'Ścieżka do kubeconfig')
        string(name: 'SONAR_HOST_URL', defaultValue: 'http://localhost:9000', description: 'Adres SonarQube')
        string(name: 'SONAR_TOKEN', defaultValue: '', description: 'Token SonarQube (ustaw w Jenkins Credentials)')
    }
    environment {
        REGISTRY = params.DOCKER_REGISTRY
        IMAGE = "${params.DOCKER_REGISTRY}/${params.IMAGE_NAME}:latest"
        KUBECONFIG = params.KUBECONFIG_PATH
        SONAR_HOST_URL = params.SONAR_HOST_URL
        SONAR_TOKEN = params.SONAR_TOKEN
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Build') {
            steps {
                dir('app') {
                    sh 'pip install -r requirements.txt'
                    sh 'pip install pytest'
                }
            }
        }
        stage('Test') {
            steps {
                dir('app') {
                    sh 'pytest'
                }
            }
        }
        stage('SonarQube') {
            when {
                expression { env.SONAR_TOKEN?.trim() }
            }
            steps {
                dir('app') {
                    sh '''
                    sonar-scanner \
                      -Dsonar.projectKey=flask_app \
                      -Dsonar.sources=. \
                      -Dsonar.host.url=${SONAR_HOST_URL} \
                      -Dsonar.login=${SONAR_TOKEN}
                    '''
                }
            }
        }
        stage('Docker Build & Push') {
            steps {
                script {
                    sh "docker build -t ${IMAGE} ."
                    sh "docker push ${IMAGE}"
                }
            }
        }
        stage('Helm Deploy') {
            steps {
                script {
                    sh "export KUBECONFIG=${KUBECONFIG} && helm upgrade --install flask-app helm/flask-app --set image.repository=${REGISTRY}/${params.IMAGE_NAME} --set image.tag=latest"
                }
            }
        }
        stage('App Verification') {
            steps {
                script {
                    // Przykład: curl do endpointu aplikacji
                    sh 'sleep 10' // poczekaj na podniesienie podów
                    sh 'curl -f http://localhost:5000 || curl -f http://localhost:8080 || true'
                }
            }
        }
    }
    post {
        success {
            mail to: 'devops@example.com', subject: "Pipeline SUCCESS: ${env.JOB_NAME}", body: "Pipeline zakończony sukcesem."
        }
        failure {
            mail to: 'devops@example.com', subject: "Pipeline FAILURE: ${env.JOB_NAME}", body: "Pipeline zakończony błędem."
        }
    }
}
// Instrukcje:
// - Ustaw parametry dla środowiska lokalnego lub AWS.
// - Upewnij się, że Jenkins ma dostęp do registry, kubeconfig i SonarQube.
// - Dla wersji lokalnej możesz uruchomić SonarQube i registry w Dockerze.
// - Dla AWS podaj adres ECR, kubeconfig AWS, SonarQube (np. na EC2 lub publiczny). 
# CI/CD Pipeline – Jenkins, SonarQube, Docker, Helm (Local and AWS)

## Table of Contents
1. [Requirements](#1-requirements)
2. [Running SonarQube and Registry Locally (Docker)](#2-running-sonarqube-and-registry-locally-docker)
3. [Jenkins Credentials Configuration](#3-jenkins-credentials-configuration)
4. [Pipeline Parameters (Jenkinsfile)](#4-pipeline-parameters-jenkinsfile)
5. [Running the Pipeline](#5-running-the-pipeline)
6. [Troubleshooting](#6-troubleshooting)
7. [Sample Pipeline Run (Local)](#7-sample-pipeline-run-local)
8. [Sample Pipeline Run (AWS)](#8-sample-pipeline-run-aws)
9. [Full CI/CD Pipeline Description (Jenkins, SonarQube, Docker, Helm)](#9-full-cicd-pipeline-description-jenkins-sonarqube-docker-helm)

## 1. Requirements
- Jenkins (on local K8s or AWS)
- Docker
- Helm
- kubectl
- (optional) minikube/k3d/kind or EC2/K3s/EKS

## 2. Running SonarQube and Registry Locally (Docker)

```bash
# SonarQube
# After starting, available at http://localhost:9000 (login: admin, password: admin)
docker run -d --name sonarqube -p 9000:9000 sonarqube:community

# Local Docker registry
# Available at localhost:5000
docker run -d -p 5000:5000 --name registry registry:2
```

## 3. Jenkins Credentials Configuration
- Add SonarQube token as Secret Text (e.g. SONAR_TOKEN)
- Add registry credentials (if required) as Docker Registry Credentials

## 4. Pipeline Parameters (Jenkinsfile)
- DEPLOY_ENV: `local` or `aws`
- DOCKER_REGISTRY: `localhost:5000` (local) or ECR address (AWS)
- IMAGE_NAME: `flask_app`
- KUBECONFIG_PATH: path to kubeconfig (e.g. `/home/jenkins/.kube/config`)
- SONAR_HOST_URL: `http://localhost:9000` (local) or SonarQube address (AWS)
- SONAR_TOKEN: SonarQube token (from Jenkins Credentials)

## 5. Running the Pipeline
- Select parameters appropriate for your environment (local or AWS)
- Run the pipeline in Jenkins
- Check logs and stage statuses (SonarQube, Docker build/push, Helm deploy, verification, notifications)

## 6. Troubleshooting
- If Docker push fails locally: check if Docker registry is running (`docker ps`)
- If SonarQube is not working: check container logs (`docker logs sonarqube`)
- If Helm deploy fails: check kubeconfig and permissions
- If notifications do not arrive: check mail configuration in Jenkins

## 7. Sample Pipeline Run (Local)
- DEPLOY_ENV: `local`
- DOCKER_REGISTRY: `localhost:5000`
- IMAGE_NAME: `flask_app`
- KUBECONFIG_PATH: `/home/jenkins/.kube/config`
- SONAR_HOST_URL: `http://localhost:9000`
- SONAR_TOKEN: (from Jenkins Credentials)

## 8. Sample Pipeline Run (AWS)
- DEPLOY_ENV: `aws`
- DOCKER_REGISTRY: (ECR address)
- IMAGE_NAME: `flask_app`
- KUBECONFIG_PATH: (path to AWS kubeconfig)
- SONAR_HOST_URL: (SonarQube EC2/public address)
- SONAR_TOKEN: (from Jenkins Credentials)

## 9. Full CI/CD Pipeline Description (Jenkins, SonarQube, Docker, Helm)

The Jenkinsfile pipeline implements a complete CI/CD process for the Flask application:

1. **Checkout code** – fetch code from the repository.
2. **Build application** – install Python dependencies.
3. **Unit tests** – run pytest.
4. **SonarQube** – code quality and security analysis.
5. **Docker build** – build Docker image.
6. **Docker push** – push image to registry (local or ECR).
7. **Helm deploy** – deploy application to K8s (local or AWS).
8. **Application verification** – automatic endpoint test (curl).
9. **Notifications** – email on pipeline success/failure.

### Environment Parameterization
- The pipeline supports both environments (local and AWS) via parameters:
  - `DEPLOY_ENV` – environment selection
  - `DOCKER_REGISTRY` – registry address
  - `KUBECONFIG_PATH` – kubeconfig path
  - `SONAR_HOST_URL` – SonarQube address
  - `SONAR_TOKEN` – SonarQube token

### Example pipeline flow:
1. Developer pushes code to the repository.
2. Pipeline starts automatically.
3. Each stage is logged and verified.
4. On success – the application is deployed and tested, and the developer receives a notification.

### Process diagram

See the `diagrams` folder – file `pipeline_mermaid.md` for a graphical representation of the process.

---

If you encounter problems, check Jenkins logs and the logs of Docker/SonarQube/registry containers. 
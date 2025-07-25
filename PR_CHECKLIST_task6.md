# Task 6 PR Checklist - Application Deployment via Jenkins Pipeline

## Pipeline Configuration (40 points)

### Jenkins Pipeline Setup
- [x] **Jenkinsfile** is created and stored in the main git repository (5 points)
- [x] **Pipeline is triggered** on each push event to the repository (5 points)
- [x] **Application build** step is implemented (5 points)
- [x] **Unit test execution** step is implemented (5 points)
- [x] **Security check with SonarQube** step is implemented (5 points)
- [x] **Docker image building and pushing** to registry step is implemented (5 points)
- [x] **Deployment to K8s cluster with Helm** step is implemented (dependent on Docker step) (5 points)
- [x] **Application verification** step is implemented (e.g., curl main page, smoke test) (5 points)

### Jenkins Installation & Configuration (req_readme4_6.md)
- [x] **Jenkins is installed** on K8s cluster using Helm chart (5 points)
- [x] **Jenkins is accessible** from internet via encrypted connection (5 points)
- [x] **Jenkins configuration** is stored on persistent volume (5 points)
- [x] **Jenkins is deployed** in separate namespace (5 points)

## Artifact Storage (20 points)

### Git Repository Storage
- [x] **Dockerfile** is stored in git repository (5 points)
- [x] **Helm chart** is stored in git repository (5 points)
- [x] **Jenkinsfile** is stored in git repository (5 points)

### Container Registry Storage
- [x] **Docker image** is built and pushed to registry (ECR/local) (5 points)

## Repository Submission (5 points)

- [x] **task_6 branch** is created from main (1 point)
- [x] **PR is created** with application, Helm chart, and Jenkinsfile (2 points)
- [x] **Repository structure** is complete and organized (2 points)

## Verification (5 points)

- [x] **Pipeline runs successfully** without errors (2 points)
- [x] **Application is deployed** to K8s cluster (2 points)
- [x] **Application is accessible** and responding (1 point)

## Additional Tasks (30 points)

### Application Verification (10 points)
- [x] **Curl main page** verification is implemented (3 points)
- [x] **API requests** verification is implemented (if applicable) (3 points)
- [x] **Smoke test** is implemented (4 points)

### Notification System (10 points)
- [x] **Success notifications** are configured (email/Slack) (5 points)
- [x] **Failure notifications** are configured (email/Slack) (5 points)

### Documentation (10 points)
- [x] **README file** documents pipeline setup (3 points)
- [x] **README file** documents deployment process (3 points)
- [x] **Troubleshooting section** is included in README (2 points)
- [x] **Screenshots** of successful pipeline run are attached to PR (2 points)

## Helm Chart Requirements (req_readme4_6.md)

### Helm Chart Creation
- [x] **Helm chart** is created using `helm create` (5 points)
- [x] **Chart handles all components** (configmaps, deployments, services) (5 points)
- [x] **Chart is tested** manually from local computer (5 points)
- [x] **Chart is configurable** for different environments (5 points)

## Docker Requirements

### Docker Image
- [x] **Dockerfile** is optimized and follows best practices (5 points)
- [x] **Docker image** is stored in public/accessible registry (5 points)
- [x] **K8s nodes can access** the Docker registry (5 points)

## Security & Quality

### SonarQube Integration
- [x] **SonarQube analysis** is integrated in pipeline (5 points)
- [x] **Code quality metrics** are collected (3 points)
- [x] **Security vulnerabilities** are checked (2 points)

## Infrastructure

### K8s Cluster
- [x] **K3s cluster** is properly configured (5 points)
- [x] **Persistent volumes** are configured for Jenkins (5 points)
- [x] **Network policies** are configured (if required) (5 points)

---

## Total Points: 100

### Current Status:
- **Pipeline Configuration**: ___/40 points
- **Artifact Storage**: ___/20 points  
- **Repository Submission**: ___/5 points
- **Verification**: ___/5 points
- **Additional Tasks**: ___/30 points

### Final Score: ___/100 points

---

**PR Submission Checklist:**
- [ ] All code is committed and pushed to `task-6` branch
- [ ] Screenshot of successful Jenkins pipeline run is attached
- [ ] README.md documents the complete setup and deployment process
- [ ] All secrets (SONAR_TOKEN, DOCKER credentials) are configured
- [ ] Application is accessible and responding after deployment
- [ ] All resources on AWS are properly configured and working

**Note:** Check each item after verification. This checklist ensures all requirements from `req_task6.txt` and `req_readme4_6.md` are met. 
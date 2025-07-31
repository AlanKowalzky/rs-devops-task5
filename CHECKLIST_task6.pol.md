# Task 6 – CI/CD Pipeline PR Checklist

Please check all items before submitting your PR:

- [ ] All code is committed and pushed to the correct branch
- [ ] Jenkins pipeline (Jenkinsfile) implements all required stages: build, test, SonarQube analysis, Docker build & push, Helm deploy, verification, notifications
- [ ] Jenkins pipeline is parameterized for local and AWS environments
- [ ] Jenkins Configuration as Code (JCasC) is provided for job automation
- [ ] GitHub Actions workflow implements CI/CD pipeline with dynamic IP/port fetching
- [ ] SonarQube analysis is integrated and working (token configured)
- [ ] Docker image is built and pushed to the correct registry (local or AWS ECR)
- [ ] Helm chart for Flask app is present and deploys correctly to K8s (local or AWS)
- [ ] Persistent Volume Claims (PVC) and storage class are configured for Jenkins
- [ ] Kubeconfig permissions and access are set correctly (no permission denied errors)
- [ ] Security Group on AWS EC2 allows required ports (22, 8080, 30080, 9000, 443)
- [ ] Application endpoint is verified automatically after deployment (curl or similar)
- [ ] All secrets (SONAR_TOKEN, DOCKER credentials, KUBECONFIG) are set in Jenkins/GHA
- [ ] README.md (in English) describes setup, pipeline, and troubleshooting
- [ ] At least one unit test is present in app/tests/
- [ ] Screenshot of successful pipeline run is attached to the PR
- [ ] All resources on AWS are cleaned up after testing (no unnecessary costs) 
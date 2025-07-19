# CI/CD Pipeline – Jenkins, SonarQube, Docker, Helm (Lokalnie i AWS)

## Spis treści
1. [Wymagania](#1-wymagania)
2. [Uruchomienie SonarQube i registry lokalnie (Docker)](#2-uruchomienie-sonarqube-i-registry-lokalnie-docker)
3. [Konfiguracja credentiali w Jenkins](#3-konfiguracja-credentiali-w-jenkins)
4. [Parametry pipeline (Jenkinsfile)](#4-parametry-pipeline-jenkinsfile)
5. [Uruchamianie pipeline](#5-uruchamianie-pipeline)
6. [Troubleshooting](#6-troubleshooting)
7. [Przykładowe uruchomienie pipeline (lokalnie)](#7-przykładowe-uruchomienie-pipeline-lokalnie)
8. [Przykładowe uruchomienie pipeline (AWS)](#8-przykładowe-uruchomienie-pipeline-aws)
9. [Pełny opis pipeline CI/CD (Jenkins, SonarQube, Docker, Helm)](#9-pelny-opis-pipeline-cicd-jenkins-sonarqube-docker-helm)

## 1. Wymagania
- Jenkins (na lokalnym K8s lub AWS)
- Docker
- Helm
- kubectl
- (opcjonalnie) minikube/k3d/kind lub EC2/K3s/EKS

## 2. Uruchomienie SonarQube i registry lokalnie (Docker)

```bash
# SonarQube
# Po uruchomieniu dostępny na http://localhost:9000 (login: admin, hasło: admin)
docker run -d --name sonarqube -p 9000:9000 sonarqube:community

# Lokalny Docker registry
# Dostępny na localhost:5000
docker run -d -p 5000:5000 --name registry registry:2
```

## 3. Konfiguracja credentiali w Jenkins
- Dodaj token SonarQube jako Secret Text (np. SONAR_TOKEN)
- Dodaj dane do registry (jeśli wymagane) jako Docker Registry Credentials

## 4. Parametry pipeline (Jenkinsfile)
- DEPLOY_ENV: `local` lub `aws`
- DOCKER_REGISTRY: `localhost:5000` (lokalnie) lub adres ECR (AWS)
- IMAGE_NAME: `flask_app`
- KUBECONFIG_PATH: ścieżka do kubeconfig (np. `/home/jenkins/.kube/config`)
- SONAR_HOST_URL: `http://localhost:9000` (lokalnie) lub adres SonarQube (AWS)
- SONAR_TOKEN: token SonarQube (z Jenkins Credentials)

## 5. Uruchamianie pipeline
- Wybierz parametry odpowiednie dla środowiska (lokalnie lub AWS)
- Uruchom pipeline w Jenkins
- Sprawdź logi i status etapów (SonarQube, Docker build/push, Helm deploy, weryfikacja, powiadomienia)

## 6. Troubleshooting
- Jeśli Docker push nie działa lokalnie: sprawdź, czy Docker registry działa (`docker ps`)
- Jeśli SonarQube nie działa: sprawdź logi kontenera (`docker logs sonarqube`)
- Jeśli Helm deploy nie działa: sprawdź kubeconfig i uprawnienia
- Jeśli nie dochodzą powiadomienia: sprawdź konfigurację maila w Jenkins

## 7. Przykładowe uruchomienie pipeline (lokalnie)
- DEPLOY_ENV: `local`
- DOCKER_REGISTRY: `localhost:5000`
- IMAGE_NAME: `flask_app`
- KUBECONFIG_PATH: `/home/jenkins/.kube/config`
- SONAR_HOST_URL: `http://localhost:9000`
- SONAR_TOKEN: (z Jenkins Credentials)

## 8. Przykładowe uruchomienie pipeline (AWS)
- DEPLOY_ENV: `aws`
- DOCKER_REGISTRY: (adres ECR)
- IMAGE_NAME: `flask_app`
- KUBECONFIG_PATH: (ścieżka do kubeconfig AWS)
- SONAR_HOST_URL: (adres SonarQube EC2/publiczny)
- SONAR_TOKEN: (z Jenkins Credentials)

## 9. Pełny opis pipeline CI/CD (Jenkins, SonarQube, Docker, Helm)

Pipeline Jenkinsfile realizuje pełny proces CI/CD dla aplikacji Flask:

1. **Checkout kodu** – pobranie kodu z repozytorium.
2. **Build aplikacji** – instalacja zależności Pythona.
3. **Testy jednostkowe** – uruchomienie pytest.
4. **SonarQube** – analiza jakości i bezpieczeństwa kodu.
5. **Docker build** – budowa obrazu Dockera.
6. **Docker push** – wysłanie obrazu do registry (lokalny lub ECR).
7. **Helm deploy** – wdrożenie aplikacji na K8s (lokalnie lub AWS).
8. **Weryfikacja aplikacji** – automatyczny test endpointu (curl).
9. **Powiadomienia** – e-mail o sukcesie/porażce pipeline.

### Parametryzacja środowiska
- Pipeline obsługuje oba środowiska (lokalne i AWS) przez parametry:
  - `DEPLOY_ENV` – wybór środowiska
  - `DOCKER_REGISTRY` – adres registry
  - `KUBECONFIG_PATH` – ścieżka do kubeconfig
  - `SONAR_HOST_URL` – adres SonarQube
  - `SONAR_TOKEN` – token SonarQube

### Przykład działania pipeline:
1. Developer pushuje kod do repozytorium.
2. Pipeline uruchamia się automatycznie.
3. Każdy etap jest logowany i weryfikowany.
4. Po sukcesie – aplikacja jest wdrożona i przetestowana, a developer otrzymuje powiadomienie.

### Diagram procesu

Zobacz folder `diagrams` – plik `pipeline_mermaid.md` z graficzną reprezentacją procesu.

---

W razie problemów sprawdź logi Jenkins oraz logi kontenerów Docker/SonarQube/registry. 
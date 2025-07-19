# CHECKLISTA – Task 6: Application Deployment via Jenkins Pipeline

## Pipeline Configuration
- [ ] Jenkinsfile w repozytorium
- [ ] Pipeline uruchamiany na push do repo
- [ ] Etap: build aplikacji
- [ ] Etap: testy jednostkowe
- [ ] Etap: SonarQube (analiza bezpieczeństwa)
- [ ] Etap: Docker build
- [ ] Etap: Docker push do registry (ECR/lokalny)
- [ ] Etap: Helm deploy na K8s (po pushu obrazu)
- [ ] (Opcjonalnie) Etap: weryfikacja aplikacji (curl/test)

## Artifact Storage
- [ ] Dockerfile i Helm chart w repozytorium
- [ ] Obraz Docker w registry (ECR/lokalny)

## Repository Submission
- [ ] Branch `task_6` utworzony z `main`
- [ ] PR z aplikacją, Helm chartem i Jenkinsfile

## Verification
- [ ] Pipeline przechodzi i deployuje aplikację na K8s

## Additional Tasks
- [ ] Weryfikacja aplikacji (curl/smoke test)
- [ ] System powiadomień (e-mail/Slack)
- [ ] Dokumentacja pipeline i procesu deployu w README

## Załączniki do PR
- [ ] Screenshot z przejścia pipeline w Jenkins
- [ ] README z opisem pipeline i deployu

---
**Uwaga:** Odhacz każdy punkt po wykonaniu. Checklistę dołącz do PR jako dowód spełnienia wymagań zadania. 
# Bezkosztowe środowisko testowe – Jenkins + aplikacja na lokalnym K8s (AUTOMAT)

## 1. Wymagania
- [Docker](https://docs.docker.com/get-docker/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [bash]
- [Helm](https://helm.sh/docs/intro/install/) (jeśli nie masz, skrypt zainstaluje)
- (jedno z poniższych):
  - [minikube](https://minikube.sigs.k8s.io/docs/start/)
  - [k3d](https://k3d.io/)
  - [kind](https://kind.sigs.k8s.io/)

## 2. Uruchomienie całości (AUTOMAT)

```bash
cd terraform/task6-local
chmod +x setup_local_env.sh
./setup_local_env.sh
```

Skrypt wykona automatycznie:
- uruchomienie lokalnego klastra K8s (minikube/k3d/kind)
- instalację Helm (jeśli brak)
- instalację Jenkins przez Helm (z jenkins-values.yaml)
- pobranie hasła admina Jenkins
- instalację aplikacji flask-app przez Helm (z app-values.yaml)
- port-forward Jenkins (localhost:8080)
- port-forward aplikacji (localhost:5000)

Po zakończeniu:
- Jenkins dostępny na: http://localhost:8080
- Aplikacja dostępna na: http://localhost:5000

Hasło administratora Jenkins pojawi się w konsoli.

---
Pliki `jenkins-values.yaml` i `app-values.yaml` są wykorzystywane automatycznie przez skrypt.
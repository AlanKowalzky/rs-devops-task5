# Prosta aplikacja Flask – wdrożenie na Kubernetes z Helm

## 1. Budowa obrazu Docker

Najpierw musisz zbudować obraz Dockera z aplikacją. W terminalu, w katalogu głównym projektu, wpisz:

```
docker build -t twoj-dockerhub/flask-app:latest .
```
Zamień `twoj-dockerhub` na swoją nazwę użytkownika z DockerHub.

## 2. Wysłanie obrazu do DockerHub

Zaloguj się do DockerHub (jeśli jeszcze nie jesteś zalogowany):

```
docker login
```

Wyślij obraz do swojego repozytorium:

```
docker push twoj-dockerhub/flask-app:latest
```

## 3. Instalacja Helm (jeśli nie masz)

Instrukcja: https://helm.sh/docs/intro/install/

## 4. Wdrożenie aplikacji na Kubernetes

Przejdź do katalogu z chartem Helm:

```
cd helm/flask-app
```

Zainstaluj aplikację:

```
helm install flask-app .
```

## 5. Sprawdzenie działania aplikacji

Jeśli używasz Minikube, możesz łatwo otworzyć aplikację w przeglądarce:

```
minikube service flask-app
```

Jeśli używasz innego klastra, sprawdź, na jakim porcie NodePort działa aplikacja:

```
kubectl get service flask-app
```
Następnie otwórz w przeglądarce:  
`http://adres_twojego_węzła:PORT`

Powinieneś zobaczyć napis:  
`Hello from Flask app deployed with Helm!`

## 6. Usunięcie aplikacji

Aby usunąć wdrożenie:

```
helm uninstall flask-app
```

---

**Wyjaśnienia:**
- **Docker** pozwala spakować aplikację i jej zależności w jeden obraz, który można uruchomić wszędzie.
- **Kubernetes** to system do zarządzania aplikacjami w kontenerach (np. Docker).
- **Helm** to narzędzie do łatwego wdrażania aplikacji na Kubernetesie.
- **NodePort** to sposób na udostępnienie aplikacji na zewnątrz klastra.

---

**Podsumowanie:**  
Dzięki tym plikom i instrukcji możesz zbudować, opublikować i wdrożyć prostą aplikację webową na swoim klastrze Kubernetes, nawet jeśli robisz to pierwszy raz! 
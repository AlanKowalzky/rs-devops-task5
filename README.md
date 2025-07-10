# Simple Flask Application – Deployment on Kubernetes with Helm

## 1. Build Docker Image

First, you need to build a Docker image with the application. In the main project directory, run:

```
docker build -t your-dockerhub/flask_app:latest .
```
Replace `your-dockerhub` with your DockerHub username.

## 2. Push the Image to DockerHub

Log in to DockerHub (if you are not logged in yet):

```
docker login
```

Push the image to your repository:

```
docker push your-dockerhub/flask_app:latest
```

## 3. Install Helm (if you don't have it)

Instructions: https://helm.sh/docs/intro/install/

## 4. Deploy the Application on Kubernetes

Go to the Helm chart directory:

```
cd helm/flask-app
```

Install the application:

```
helm install flask-app .
```

## 5. Check if the Application Works

If you use Minikube, you can easily open the application in your browser:

```
minikube service flask-app
```

If you use another cluster, check which NodePort the application is running on:

```
kubectl get service flask-app
```
Then open in your browser:  
`http://your_node_address:PORT`

You should see the message:  
`Hello from Flask app deployed with Helm!`

## 6. Remove the Application

To remove the deployment:

```
helm uninstall flask-app
```

## Automatic Docker Image Build and Push (GitHub Actions)

To make the workflow work, add two secrets in your repository settings:
- DOCKERHUB_USERNAME – Your DockerHub username
- DOCKERHUB_TOKEN – Access token (generate it on DockerHub)

After each push to the main or task_5 branch, the image will be automatically built and pushed to DockerHub.

---

**Explanations:**
- **Docker** allows you to package the application and its dependencies into a single image that can run anywhere.
- **Kubernetes** is a system for managing applications in containers (e.g., Docker).
- **Helm** is a tool for easy application deployment on Kubernetes.
- **NodePort** is a way to expose the application outside the cluster.

---

**Summary:**  
With these files and instructions, you can build, publish, and deploy a simple web application on your Kubernetes cluster, even if it's your first time! 
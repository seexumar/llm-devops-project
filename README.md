# DevOps Project: Deploying an Open-Source Large Language Model (LLM)

## Objective

The objective of this project is to gain hands-on experience with containerized AI applications and Kubernetes orchestration. You will deploy a local Large Language Model (LLM) using Docker Compose and then migrate the same application to Kubernetes while following container orchestration best practices.

The Docker Compose configuration required to run the application is provided. Your task is to understand the architecture, deploy the application locally, and recreate the deployment using Kubernetes manifests.

---

# Learning Outcomes

By the end of this project, you should be able to:

- Understand a multi-container application architecture.
- Deploy applications using Docker Compose.
- Download and manage LLM models using Ollama.
- Create Kubernetes manifests from scratch.
- Deploy applications on a Minikube cluster.
- Apply Kubernetes production best practices.
- Troubleshoot containerized applications.

---

# Application Architecture

The application consists of the following services:

- **Ollama** – hosts the Large Language Models.
- **Open WebUI** – web interface (like Gemini UI or GPT UI) used to interact with the models.

You will first deploy these services locally using Docker Compose and later migrate the deployment to Kubernetes.

---

# Part 1 – Local Deployment with Docker Compose

The Docker Compose file is provided in the project repository.

### Tasks

1. Start the application using Docker Compose.
2. Verify that all containers are running.
3. Access the Open WebUI interface.
4. Download at least  two required LLM into Ollama.

```bash
    docker exec -it ollama ollama pull llama3.2:3b
    docker exec -it ollama ollama pull mistral:7b
    docker exec -it ollama ollama pull gemma3:4b
    docker exec -it ollama ollama pull deepseek-r1:8b
```
5. Test each model by generating a response from the WebUI.


---

# Part 2 – Kubernetes Deployment

Using the provided Docker Compose deployment as a reference, recreate the application using Kubernetes manifests.

You must create all required YAML files.

## Required Kubernetes Resources

Your solution must include at least:

- Namespace
- Deployment (Ollama)
- Deployment (Open WebUI)
- Service (Ollama)
- Service (Open WebUI)
- ConfigMap
- PersistentVolumeClaim for Ollama
- PersistentVolumeClaim for Open WebUI
- Ingress (or port-forward if Ingress is unavailable)

---

# Kubernetes Best Practices

Your deployment must implement the following best practices:

## Resource Requests

Configure CPU and memory requests for every container.

## Resource Limits

Configure CPU and memory limits for every container.

## Health Checks

Implement:

- Startup Probe
- Readiness Probe
- Liveness Probe

where appropriate.

## Persistent Storage

Both applications must preserve their data after pod restarts by using Persistent Volume Claims.

## Configuration Management

Use ConfigMaps for application configuration instead of hardcoding environment variables.

---

# Validation

Your deployment should satisfy the following conditions:

- Both pods are in the **Running** state.
- No pod is in **CrashLoopBackOff**.
- No pod is **Pending** due to configuration errors.
- Open WebUI can successfully communicate with Ollama.
- The downloaded models are available in the WebUI.
- Prompts can be submitted successfully and responses are generated.

---

# Deliverables

Submit the following in a github repository and send the link to this form https://forms.gle/dim6kBVbyZMBSdVq8:

- All Kubernetes YAML manifest files.
- A screenshot showing all running pods.
- A screenshot showing all running services.
- A screenshot of the Open WebUI homepage.
- A screenshot demonstrating a successful prompt and response from each of the three required models.
- A short report (2–3 pages) explaining:
  - The purpose of each Kubernetes resource.
  - How the services communicate.
  - Why Persistent Volume Claims are required.
  - The purpose of liveness, readiness, and startup probes.
  - The difference between Docker Compose and Kubernetes.

Important: Make sure your repo is public or add my username(ibrahimambengue) as member 

---

# Bonus (Optional)

You may earn bonus credit by implementing one or more of the following:

- Horizontal Pod Autoscaler (HPA)
- NetworkPolicy
- PodDisruptionBudget
- Helm chart for the application
- Kustomize overlays (development and production)
- Prometheus and Grafana monitoring
- GitHub Actions pipeline for automated deployment

---

# Evaluation Rubric

| Criterion | Weight |
|-----------|--------:|
| Successful Docker Compose deployment | 15% |
| Kubernetes manifests | 25% |
| Correct use of Services and networking | 15% |
| Persistent storage configuration | 10% |
| Resource requests and limits | 10% |
| Health probes | 10% |
| Documentation and report | 10% |
| Demonstration of the three LLM models | 5% |

Total: **100%**
# Rapport — Déploiement d'un LLM open-source (Ollama + Open WebUI)

## 1. Objectif du projet

Ce projet déploie une pile applicative composée d'Ollama (moteur d'inférence pour modèles de langage) et d'Open WebUI (interface web de type chat) — d'abord avec Docker Compose, puis migrée vers Kubernetes (Minikube) en suivant les bonnes pratiques d'orchestration de conteneurs.

---

## 2. Rôle de chaque ressource Kubernetes

| Ressource | Fichier | Rôle |
|---|---|---|
| **Namespace** | `k8s/00-namespace.yaml` | Isole toutes les ressources du projet (`projet-devops`) du reste du cluster — évite les collisions de noms avec d'autres projets partageant le même Minikube. |
| **ConfigMap** | `k8s/01-configmap.yaml` | Centralise la configuration non-sensible (ports, URL interne d'Ollama) injectée dans les conteneurs via `envFrom`, sans la coder en dur dans les manifests de déploiement. |
| **PersistentVolume / PersistentVolumeClaim** | `k8s/02-ollama-pv.yaml`…`k8s/05-openwebui-pvc.yaml` | Fournissent un stockage qui survit au cycle de vie d'un pod (voir section 4). |
| **Deployment (Ollama)** | `k8s/06-ollama-deployment.yaml` | Gère le pod exécutant le moteur Ollama : image, ressources CPU/RAM, probes de santé, montage du volume de modèles. |
| **Deployment (Open WebUI)** | `k8s/08-openwebui-deployment.yaml` | Gère le pod de l'interface web, connecté à Ollama via le réseau interne du cluster. |
| **Service (Ollama / Open WebUI)** | `k8s/07-ollama-service.yaml`, `k8s/09-openwebui-service.yaml` | Exposent chaque Deployment sous un nom DNS stable et une IP virtuelle interne (`ClusterIP`), indépendants du pod réellement en cours (qui peut être recréé avec une IP différente). |
| **Ingress** | `k8s/10-ingress.yaml` | Point d'entrée HTTP unique routant vers Open WebUI (`/`) et Ollama (`/ollama`) — alternative au port-forward pour un accès externe plus proche d'un usage production. |

Les fichiers sont numérotés selon leur ordre d'exécution logique (`00` à `14`) : namespace et configuration d'abord, stockage ensuite, puis workloads, réseau, et enfin les contrôles bonus (NetworkPolicy, PDB, HPA).

---

## 3. Communication entre les services

Dans Docker Compose, les conteneurs communiquent par leur `container_name` sur un réseau bridge partagé (`http://ollama:11434`). Kubernetes n'a pas de notion de "nom de conteneur" au niveau réseau : c'est le **Service** qui joue ce rôle.

Concrètement :
1. Le pod `open-webui` résout `ollama-service` via le DNS interne du cluster (CoreDNS), qui retourne l'IP virtuelle du Service.
2. Le Service redirige le trafic vers l'IP réelle du pod `ollama` actif (`kube-proxy` fait ce routage), même si ce pod est recréé ailleurs avec une IP différente.
3. Le port exposé par le Service (`80`) est différent du port réellement écouté par le conteneur (`11434`, via `targetPort`) — ce découplage permet de changer l'implémentation interne sans casser les clients.

Une **NetworkPolicy** (bonus) restreint en plus qui a le droit d'atteindre Ollama : seul le pod `open-webui` peut lui parler sur le port 11434, tout le reste est bloqué par défaut.

---

## 4. Pourquoi des PersistentVolumeClaims

Un pod Kubernetes est **éphémère** : à chaque redémarrage, crash ou mise à jour du Deployment, le pod est détruit et recréé — et avec lui, tout fichier écrit dans son filesystem local disparaît.

Or :
- Ollama télécharge des modèles de plusieurs gigaoctets (`llama3.2:3b`, `mistral:7b`, etc.) — les re-télécharger à chaque redémarrage serait extrêmement coûteux en temps et en bande passante.
- Open WebUI stocke sa base SQLite (utilisateurs, historique des conversations) dans `/app/backend/data`.

La **PersistentVolumeClaim** découple le stockage du cycle de vie du pod : elle réserve un espace de stockage (backé ici par un `PersistentVolume` de type `hostPath` sur le nœud Minikube) qui reste disponible même si le pod est supprimé et recréé. Le nouveau pod remonte le même volume et retrouve exactement les données laissées par l'ancien.

Dans ce projet, le binding entre PVC et PV est **statique** (`storageClassName: manual` + `volumeName` explicite) plutôt que dynamique, pour garantir que chaque PVC se lie toujours au même PV physique et éviter tout mélange de données entre les deux volumes (un piège rencontré en pratique : sans `volumeName` explicite, deux PV de taille identique peuvent se lier dans le mauvais ordre).

---

## 5. Rôle des probes (startup, readiness, liveness)

Les trois probes répondent à des questions différentes sur l'état d'un conteneur :

- **Startup probe** : "le processus a-t-il fini de démarrer ?" Tant qu'elle échoue, les deux autres probes sont suspendues — indispensable ici car Open WebUI télécharge un modèle d'embedding au premier démarrage (peut prendre plusieurs dizaines de secondes), et une liveness probe classique le tuerait en boucle avant la fin du chargement.
- **Readiness probe** : "le conteneur peut-il recevoir du trafic *maintenant* ?" Si elle échoue, le pod est retiré des endpoints du Service (plus de trafic envoyé) sans être redémarré — utile pour une surcharge temporaire.
- **Liveness probe** : "le processus est-il bloqué/planté ?" Si elle échoue de façon persistante, Kubernetes redémarre le conteneur — seul mécanisme d'auto-guérison face à un deadlock applicatif.

Ce projet a d'ailleurs révélé en pratique la différence entre un "conteneur qui répond lentement" (readiness) et un "sous-processus tué par OOM" (`llama-server` killé par manque de RAM) — un cas que seule l'observation des logs et du statut `OOMKilled` du conteneur a permis de diagnostiquer, les probes seules ne donnant que le symptôme (connexion refusée).

---

## 6. Docker Compose vs Kubernetes

| Aspect | Docker Compose | Kubernetes |
|---|---|---|
| **Portée** | Un seul hôte Docker | Un cluster de plusieurs nœuds (ici Minikube, un seul nœud, mais la même API scale à N nœuds) |
| **Découverte de service** | Nom du conteneur (`container_name`) sur un réseau bridge | DNS interne (CoreDNS) résolvant des `Service` indépendants des pods réels |
| **Auto-guérison** | `restart: unless-stopped` redémarre le conteneur, sans vérifier qu'il répond réellement | Probes (liveness/readiness/startup) + contrôleur de Deployment qui recrée activement tout pod manquant pour respecter le nombre de replicas désiré |
| **Stockage persistant** | Volumes nommés Docker, gérés directement par le moteur Docker de l'hôte | PersistentVolume/PersistentVolumeClaim, une couche d'abstraction qui découple la demande de stockage (PVC) de son implémentation réelle (PV — hostPath, disque cloud, NFS...) |
| **Scalabilité** | Manuelle (`docker compose up --scale`), pas d'ajustement automatique | HorizontalPodAutoscaler ajuste automatiquement le nombre de replicas selon une métrique (CPU ici) |
| **Configuration** | Variables d'environnement dans le fichier compose ou `.env` | ConfigMap/Secret séparés du Deployment, injectables et modifiables indépendamment |
| **Isolation réseau** | Réseaux bridge séparés, mais pas de règles fines par conteneur | NetworkPolicy : contrôle explicite de qui peut parler à qui, au niveau du label de pod |

En résumé : Compose reste idéal pour un développement local rapide sur une seule machine ; Kubernetes ajoute une couche d'orchestration (répartition sur plusieurs nœuds, auto-guérison réelle, scaling automatique, contrôle réseau fin) nécessaire dès qu'on vise un environnement de production résilient.

---

## 7. Fonctionnalités bonus implémentées

Au-delà des exigences de base, les bonus suivants ont été implémentés et validés sur le cluster : NetworkPolicy, PodDisruptionBudget, HorizontalPodAutoscaler, pipeline GitHub Actions de validation, overlays Kustomize (development/production), chart Helm complet, et stack de monitoring Prometheus + Grafana. Le détail de chacun (fichiers, choix techniques, limites honnêtes) est documenté dans `BONUS.md`.
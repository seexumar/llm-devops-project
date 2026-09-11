# Bonus: Fonctionnalités implémentées

Sept fonctionnalités bonus ont été implémentées et testées sur le cluster Minikube, réparties entre les namespaces `projet-devops` et `monitoring`.

## 1. NetworkPolicy

**Fichier :** `k8s/11-networkpolicy.yaml`

Deux politiques réseau ont été mises en place. `ollama-netpol` autorise uniquement le pod `open-webui` à accéder à Ollama sur le port `11434`. `open-webui-netpol` contrôle quant à elle l'accès entrant à Open WebUI sur le port `8080`.

La communication entre Open WebUI et Ollama a été vérifiée avec `curl`, confirmant que la politique n'empêche pas le fonctionnement de l'application.

L'egress reste volontairement ouvert afin de permettre le téléchargement des modèles Ollama et du modèle d'embedding d'Open WebUI.

## 2. PodDisruptionBudget

**Fichiers :** `k8s/12-ollama-pdb.yaml`, `k8s/13-openwebui-pdb.yaml`

Un `PodDisruptionBudget` avec `maxUnavailable: 0` est configuré pour Ollama et Open WebUI afin d'empêcher leur éviction volontaire sans possibilité de remplacement.

Cette configuration est toutefois restrictive avec un seul replica : un `kubectl drain` peut rester bloqué tant qu'un nouveau Pod ne peut pas être disponible. En production, plusieurs replicas seraient préférables.

## 3. HorizontalPodAutoscaler

**Fichier :** `k8s/14-openwebui-hpa.yaml`

Un HPA permet à Open WebUI de varier entre 1 et 3 replicas lorsque l'utilisation CPU dépasse le seuil configuré de 70 %. Son fonctionnement repose sur `metrics-server`.

Ollama n'est pas scalé horizontalement dans cette configuration, notamment en raison de son PVC `ReadWriteOnce`, qui limite le montage simultané du volume à un seul Pod.

## 4. GitHub Actions

**Fichier :** `.github/workflows/validate.yml`

Un pipeline CI valide automatiquement les configurations du projet à chaque push ou pull request.

Il vérifie les manifests Kubernetes avec `kubectl`, le `Dockerfile` avec `hadolint` et la configuration Docker Compose avec `docker compose config`.

Le pipeline réalise uniquement des validations statiques. Aucun déploiement réel n'est effectué.

## 5. Kustomize

**Dossier :** `kustomize/`

Une structure `base/overlays` permet de gérer séparément les environnements `development` et `production`.

Les overlays adaptent notamment les ressources mémoire d'Ollama, le nombre maximal de replicas du HPA et les labels d'environnement.

Les deux configurations ont été générées avec `kubectl kustomize` sans erreur.

Les valeurs de production restent toutefois adaptées à un environnement disposant de davantage de ressources que la VM Minikube utilisée pour les tests.

## 6. Helm

**Dossier :** `helm/llm-devops/`

Un chart Helm paramétrable a été créé afin de regrouper et de rendre reproductible le déploiement de l'ensemble de la stack : Namespace, ConfigMap, PV/PVC, Deployments, Services, Ingress, NetworkPolicy, PDB et HPA.

Le chart a été validé avec `helm lint` et `helm template`, puis comparé aux ressources actuellement déployées sur le cluster.

## 7. Prometheus + Grafana

**Fichier :** `monitoring/values.yaml`

Une stack de monitoring basée sur `kube-prometheus-stack` a été déployée dans le namespace `monitoring`.

La configuration a été volontairement allégée afin de respecter les ressources limitées de la VM : rétention Prometheus réduite, Alertmanager désactivé et ressources CPU/RAM limitées.

Grafana est accessible via un `port-forward` du Service.

Le monitoring couvre principalement les métriques du cluster et des Pods. Ollama et Open WebUI n'exposant pas directement de métriques Prometheus natives dans cette configuration, les métriques applicatives détaillées telles que la latence des requêtes ou les tokens par seconde ne sont pas collectées.

## Contraintes de l'environnement

L'ensemble des fonctionnalités a été testé sur une VM Minikube disposant de **7,6 Go de RAM**, également utilisée par d'autres projets. Les limites de ressources définies dans les manifests sont donc principalement liées aux capacités de la machine de test et non à des contraintes propres à Kubernetes.

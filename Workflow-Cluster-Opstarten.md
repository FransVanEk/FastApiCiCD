# workflow: van clone naar productie

Dit stappenplan begeleidt je door het proces om het project vanaf een vers gekloonde repository te deployen naar een productieomgeving op DigitalOcean. Dit omvat het configureren van de benodigde tools, het opzetten van infrastructuur, en het publiceren van je applicatie en monitoringoplossingen.

---

## 1. repository clonen
Clone de Git-repository naar je lokale machine:

```bash
git clone <repository-url>
cd <repository-directory>
```

---

## 2. vereisten installeren
Installeer de volgende tools op je lokale machine:

- **Terraform**: Download en installeer via [terraform.io](https://developer.hashicorp.com/terraform/downloads).
- **kubectl**: Installeer volgens de instructies op [kubernetes.io](https://kubernetes.io/docs/tasks/tools/install-kubectl/).
- **Lens (optioneel)**: Download Lens van [k8slens.dev](https://k8slens.dev/) om je cluster te beheren via een GUI.
- **DOCTL** (optioneel): Installeer de DigitalOcean CLI via [doctl CLI](https://github.com/digitalocean/doctl).

---

## 3. kubectl configureren
Na het opzetten van een Kubernetes-cluster op DigitalOcean, download je de kubeconfig:

1. Login bij DigitalOcean.
2. Ga naar je Kubernetes-cluster.
3. Klik op **"Download Config"** en sla het bestand op als `~/.kube/config`.

Controleer of het cluster bereikbaar is:

```bash
kubectl get nodes
```

---

## 4. terraform initialiseren en infrastructuur implementeren

### Initialiseren
Initialiseer Terraform in de root van de repository:

```bash
terraform init
```

### Plan maken
Controleer welke wijzigingen Terraform zal toepassen:

```bash
terraform plan -var="do_token=<your_digitalocean_token>"
```

### Toepassen
Voer Terraform uit om de infrastructuur te implementeren:

```bash
terraform apply -var="do_token=<your_digitalocean_token>"
```

Hiermee worden onder andere je Kubernetes-cluster, namespaces, monitoring (Prometheus en Grafana), en secrets ingesteld.

---

## 5. image deployen naar cluster
Het project maakt gebruik van een Docker-image dat al is gepubliceerd in de DigitalOcean Container Registry met de tag `latest`. Volg deze stappen:

1. Controleer de bestaande deployment:
   ```bash
   kubectl get deployments -n <namespace>
   ```

2. Update de deployment om het `latest`-image te gebruiken:
   ```bash
   kubectl rollout restart deployment <deployment-name> -n <namespace>
   ```

---

## 6. applicatie controleren
Controleer of de applicatie succesvol draait:

1. **Pods controleren**:
   ```bash
   kubectl get pods -n <namespace>
   ```

2. **Toegang tot de applicatie**:
   Als de applicatie is blootgesteld via een LoadBalancer, kun je de externe IP controleren:
   ```bash
   kubectl get service <service-name> -n <namespace>
   ```
   Open de IP in je browser op poort 8000.

---

## 7. monitoring inrichten
### Grafana openen
1. Forward de poort van de Grafana-service naar je lokale machine:
   ```bash
   kubectl port-forward service/prometheus-grafana 3000:80 -n monitoring
   ```
2. Open Grafana in je browser:
   ```
   http://localhost:3000
   ```
3. Log in met de standaardgebruikersnaam `admin` en het ingestelde wachtwoord.

### Dashboard controleren
Het dashboard wordt automatisch geladen via de sidecar-configuratie. Controleer in Grafana:

1. Ga naar **Dashboards > Manage**.
2. Zoek naar het dashboard genaamd "Cluster & API Monitoring".

---

## 8. cluster beheren met lens (optioneel)
Lens biedt een visuele GUI voor het beheren van je Kubernetes-cluster:

1. Voeg je kubeconfig toe aan Lens.
2. Bekijk de status van je pods, services, en andere resources.

---

## 9. problemen oplossen
### Logs bekijken
Als de applicatie niet werkt, bekijk de logs:

```bash
kubectl logs <pod-name> -n <namespace>
```

### Pods debuggen
Controleer de status van de pods:

```bash
kubectl describe pod <pod-name> -n <namespace>
```

---

Met dit stappenplan kun je je project eenvoudig van clone naar productie brengen op DigitalOcean.
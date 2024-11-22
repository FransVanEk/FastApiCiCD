# fast-api - project

Dit project is een FastAPI-gebaseerde webapplicatie ontworpen om schaalbare en onderhoudbare API's te leveren binnen een Docker-gebaseerde omgeving. Omgevingsvariabelen worden beheerd met behulp van een `.env`-bestand voor lokale ontwikkeling, terwijl deze variabelen voor productieomgevingen via runtime-parameters aan de container worden doorgegeven.

## projectstructuur

De applicatie is georganiseerd volgens best practices voor Python- en Docker-gebaseerde projecten:

-   **`main.py`**: De hoofdapplicatie die de FastAPI-app initialiseert en de API-routes definieert.
-   **`requirements.txt`**: Een lijst met afhankelijkheden die vereist zijn voor de applicatie, zoals FastAPI en Uvicorn, die via pip geïnstalleerd kunnen worden.
-   **`.env`**: Een configuratiebestand voor het definiëren van omgevingsvariabelen. Dit bestand bevat bijvoorbeeld de `DATABASE_URL` en andere lokale configuraties die niet in de Docker-image zelf worden opgenomen.
-   **`Dockerfile`**: De configuratie voor het bouwen van een Docker-image. De Dockerfile maakt gebruik van een slanke Python 3.11-basisimage, installeert de vereiste Python-pakketten en configureert de container om Uvicorn te gebruiken als ASGI-server voor de FastAPI-applicatie.
-   **`.dockerignore`**: Dit bestand bevat een lijst van bestanden en mappen (zoals `.env`) die niet in de Docker-image moeten worden opgenomen. Dit houdt de image klein en voorkomt dat gevoelige informatie in de container terechtkomt.

## werken met het project

### ontwikkeling

Voor lokale ontwikkeling wordt een `.env`-bestand in de root van het project gebruikt om omgevingsvariabelen in te stellen, zoals:

```dotenv
DATABASE_URL=postgresql://myuser:mypassword@localhost:5432/mydatabase
SETTINGS_TABLE_NAME=settings
SETTINGS_KEY_APPVERSION=appVersion
```

FastAPI en Uvicorn kunnen vervolgens worden gestart om de applicatie lokaal te draaien:

```bash
uvicorn src.main:app --reload
```

Dit maakt lokale testing en ontwikkeling eenvoudig, terwijl omgevingsspecifieke configuraties in `.env` beheerd worden.

### productie

Voor productie wordt de applicatie uitgevoerd in een Docker-container, waarbij omgevingsvariabelen niet in de Docker-image zelf worden opgenomen. Dit is mogelijk door `.env` uit te sluiten in de `.dockerignore` en variabelen pas bij runtime door te geven.

#### omgevingsvariabelen in productie

Omgevingsvariabelen kunnen worden meegegeven tijdens de runtime van de Docker-container, zonder dat de `.env` in de image aanwezig is. Dit gebeurt bijvoorbeeld via:

```bash
docker run -e DATABASE_URL="postgresql://myuser:mypassword@localhost:5432/mydatabase" -p 8000:8000 fastapi-app
```

Of door gebruik te maken van een externe `.env`-bestand:

```bash
docker run --env-file .env -p 8000:8000 fastapi-app
```

Dit zorgt ervoor dat de gevoelige gegevens en configuraties buiten de container zelf blijven, wat veilig en flexibel is voor verschillende omgevingen.

### toegang tot de applicatie

In zowel ontwikkel- als productieomgevingen is de API beschikbaar via poort 8000. Wanneer de applicatie lokaal draait, kan deze worden geopend op `http://localhost:8000`. De interactieve API-documentatie is beschikbaar op `http://localhost:8000/docs`.

### veiligheid en best practices

-   **Gevoelige informatie**: `.env`-bestanden zijn toegevoegd aan `.dockerignore` om te voorkomen dat gevoelige gegevens zoals wachtwoorden en API-sleutels in Docker-images terechtkomen.
-   **Configuratiebeheer**: Voor lokale ontwikkeling worden `.env`-bestanden gebruikt, terwijl in productie de benodigde configuratievariabelen expliciet aan de container worden meegegeven bij het opstarten.
-   **Afzondering van omgevingen**: Door omgevingsspecifieke configuratie buiten de image te houden, wordt het gemakkelijker om dezelfde image in meerdere omgevingen (bijv. staging, productie) te draaien met verschillende configuraties.

## terraform

Hier zijn de belangrijkste Terraform-commando's om je infrastructuur te beheren:

### 1. terraform initialiseren
Initialiseer Terraform in de huidige map:

```bash
terraform init
```
- **Wat het doet**: Downloadt de benodigde providers en bereidt de werkdirectory voor Terraform-gebruik.

### 2. infrastructuur valideren
Controleer of de configuratie geldig is:

```bash
terraform validate
```
- **Wat het doet**: Verifieert de syntaxis en configuratie van je `.tf`-bestanden.

### 3. plan maken
Genereer een plan om wijzigingen in je infrastructuur te bekijken:

```bash
terraform plan -var="do_token=<your_digitalocean_token>"
```
- **Wat het doet**: Toont welke resources worden aangemaakt, gewijzigd of verwijderd.

### 4. infrastructuur toepassen
Voer de geplande wijzigingen uit en implementeer de infrastructuur:

```bash
terraform apply -var="do_token=<your_digitalocean_token>"
```
- **Wat het doet**: Creëert en configureert de opgegeven resources.

### 5. infrastructuur opschonen
Verwijder de infrastructuur die is aangemaakt door Terraform:

```bash
terraform destroy -var="do_token=<your_digitalocean_token>"
```
- **Wat het doet**: Verwijdert alle resources die door de configuratie zijn aangemaakt.

### 6. specifieke variabelen doorgeven
Bij het gebruik van variabelen kun je een bestand specificeren:

```bash
terraform apply -var-file="variables.tfvars"
```

Of individuele variabelen doorgeven in de CLI:

```bash
terraform apply -var="namespace=my-namespace" -var="monitoring_namespace=monitoring"
```

### voorbeeldworkflow

```bash
# 1. Initialiseer Terraform
terraform init

# 2. Valideer configuraties
terraform validate

# 3. Bekijk het plan
terraform plan -var="do_token=<your_digitalocean_token>"

# 4. Voer wijzigingen uit
terraform apply -var="do_token=<your_digitalocean_token>"

# 5. Verwijder resources
terraform destroy -var="do_token=<your_digitalocean_token>"
```

Met deze stappen kun je je infrastructuur effectief beheren met Terraform.

### monitoring configureren met terraform

#### Helm release voor kube-prometheus-stack
Het project gebruikt de `kube-prometheus-stack` om monitoring te ondersteunen. Voeg de volgende configuratie toe om Prometheus en Grafana te deployen:

```hcl
resource "helm_release" "prometheus" {
  chart      = "kube-prometheus-stack"
  name       = "prometheus"
  namespace  = kubernetes_namespace.monitoring_namespace.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  version    = "56.3.0"

  values = [file("${path.module}/values.yaml")]

  set {
    name  = "podSecurityPolicy.enabled"
    value = true
  }

  set {
    name  = "server.persistentVolume.enabled"
    value = false
  }

  set {
    name  = "grafana.sidecar.dashboards.enabled"
    value = true
  }

  set {
    name  = "grafana.sidecar.dashboards.label"
    value = "grafana_dashboard"
  }
}
```

#### Kubernetes ConfigMap voor dashboard

Maak een Kubernetes ConfigMap om een Grafana-dashboard beschikbaar te maken:

```hcl
resource "kubernetes_config_map" "grafana_dashboard" {
  metadata {
    name      = "fastapi-cluster-dashboard"
    namespace = kubernetes_namespace.monitoring_namespace.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "fastapi-cluster-dashboard.json" = file("${path.module}/grafana/dashboards/fastapi-cluster-dashboard.json")
  }
}
```

Zorg ervoor dat het JSON-dashboardbestand beschikbaar is in `grafana/dashboards/fastapi-cluster-dashboard.json`.

#### Toegang tot Grafana
Na het toepassen van Terraform kun je Grafana openen:

```bash
kubectl port-forward service/prometheus-grafana 3000:80 -n monitoring
```

Open vervolgens Grafana in je browser op `http://localhost:3000`. Log in met de standaardgebruikersnaam `admin` en het wachtwoord dat je hebt ingesteld in `values.yaml`.

## Toevoeging

in de folder terraform kun je ook een variable bestand toevoegen waarin je jouw settings set 

```yaml
do_token      = "<jouw token>"
cluster_name  = "my-devops-cluster2"
region        = "ams3"
node_count    = 2
namespace     = "ns-website-db"
db_name       = "my_database"
db_user       = "db_user"
db_password   = "mypassword"
docker_server = "registry.digitalocean.com"
docker_username = "<jouw naam>"
docker_email = "<jouw email adres>"
monitoring_namespace = "monitoring"
```
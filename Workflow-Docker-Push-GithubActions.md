# workflow: docker image push en github actions pipeline

Dit stappenplan begeleidt je door het proces van het handmatig pushen van een nieuwe Docker-image naar de DigitalOcean Container Registry en het automatiseren van dit proces via een GitHub Actions pipeline.

---

## 1. handmatig een docker image pushen naar digitalocean container registry

### Voorwaarden
- Zorg dat Docker is geïnstalleerd en dat je bent ingelogd bij de DigitalOcean CLI (optioneel: `doctl`).
- Zorg dat je DigitalOcean API-token beschikbaar is als omgevingsvariabele (`DIGITALOCEAN_ACCESS_TOKEN`).

### Instructies
1. Log in bij de DigitalOcean Container Registry:
   ```bash
   echo $DIGITALOCEAN_ACCESS_TOKEN | docker login registry.digitalocean.com -u "<your_username>" --password-stdin
   ```

2. Bouw de Docker-image:
   ```bash
   docker build -t registry.digitalocean.com/<your-registry>/fast-api:latest .
   ```

3. Push de Docker-image:
   ```bash
   docker push registry.digitalocean.com/<your-registry>/fast-api:latest
   ```

4. Controleer of de image correct is gepusht:
   ```bash
   doctl registry repository list-tags <your-registry>
   ```

---

## 2. github actions: ci/cd pipeline configureren

Hieronder volgt een voorbeeld van een GitHub Actions-pipeline om het proces van het bouwen en pushen van Docker-images en het deployen naar DigitalOcean Kubernetes te automatiseren.

### Pipeline-bestand
Maak een bestand `.github/workflows/docker-push.yml` met de volgende inhoud:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      # Check out the code
      - name: Checkout code
        uses: actions/checkout@v3

      # Set up Python
      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
            python -m pip install --upgrade pip
            pip install -r requirements.txt
            pip install aiosqlite  # for testing

      # Run tests
      - name: Run tests
        env:
          DATABASE_URL: "sqlite:///:memory:"
        run: |
          pytest

      # Log in to DigitalOcean Container Registry
      - name: Log in to DigitalOcean
        env:
          DIGITALOCEAN_ACCESS_TOKEN: ${{ secrets.DIGITALOCEAN_ACCESS_TOKEN }}
        run: |
          echo "${DIGITALOCEAN_ACCESS_TOKEN}" | docker login registry.digitalocean.com -u "${{ github.actor }}" --password-stdin

      # Build Docker Image with Git commit hash as tag
      - name: Build Docker image
        env:
          COMMIT_HASH: ${{ github.sha }}
        run: |
          docker build -t registry.digitalocean.com/<your-registry>/fast-api:${COMMIT_HASH} -t registry.digitalocean.com/<your-registry>/fast-api:latest .

      # Push Docker Image
      - name: Push Docker image to DigitalOcean
        env:
          COMMIT_HASH: ${{ github.sha }}
        run: |
          docker push --all-tags registry.digitalocean.com/<your-registry>/fast-api  

      # Deploy to DigitalOcean Kubernetes
      - name: Set up kubectl
        uses: azure/setup-kubectl@v1
        with:
          version: 'latest'
        
      - name: Configure kubeconfig
        env:
          KUBE_CONFIG_DATA: ${{ secrets.KUBECONFIG }}
        run: |
          mkdir -p $HOME/.kube
          echo "${KUBE_CONFIG_DATA}" > $HOME/.kube/config

      - name: Update Deployment with New Image
        env:
          COMMIT_HASH: ${{ github.sha }}
        run: |
          kubectl set image deployment/website website=registry.digitalocean.com/<your-registry>/fast-api:${COMMIT_HASH} -n <namespace>
```

---

## 3. vereisten voor github actions

1. **Secrets instellen**:
   - Ga naar je GitHub-repository > **Settings** > **Secrets and variables** > **Actions** > **New repository secret**.
   - Voeg de volgende secrets toe:
     - `DIGITALOCEAN_ACCESS_TOKEN`: Je DigitalOcean API-token.
     - `KUBECONFIG`: De kubeconfig-inhoud van je Kubernetes-cluster.

2. **Branch-protectieregels** (optioneel):
   Stel branch-protectieregels in voor `main` om alleen wijzigingen via de pipeline toe te staan.


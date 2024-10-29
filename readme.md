# Fast-api - project

Dit project is een fastapi-gebaseerde webapplicatie ontworpen om schaalbare en onderhoudbare api's te leveren binnen een docker-gebaseerde omgeving. Omgevingsvariabelen worden beheerd met behulp van een `.env`-bestand voor lokale ontwikkeling, terwijl deze variabelen voor productieomgevingen via runtime-parameters aan de container worden doorgegeven.

## Projectstructuur

De applicatie is georganiseerd volgens best practices voor python- en docker-gebaseerde projecten:

-   `Main.py`: de hoofdapplicatie die de fastapi-app initialiseert en de api-routes definieert.
-   `Requirements.txt`: een lijst met afhankelijkheden die vereist zijn voor de applicatie, zoals fastapi en uvicorn, die via pip geïnstalleerd kunnen worden.
-   `.env`: een configuratiebestand voor het definiëren van omgevingsvariabelen. Dit bestand bevat bijvoorbeeld de `database_url` en andere lokale configuraties die niet in de docker-image zelf worden opgenomen.
-   `Dockerfile`: de configuratie voor het bouwen van een docker-image. De dockerfile maakt gebruik van een slanke python 3.9-basisimage, installeert de vereiste python-pakketten, en configureert de container om uvicorn te gebruiken als asgi-server voor de fastapi-applicatie.
-   `.dockerignore`: dit bestand bevat een lijst van bestanden en mappen (zoals `.env`) die niet in de docker-image moeten worden opgenomen. Dit houdt de image klein en voorkomt dat gevoelige informatie in de container terechtkomt.

## Werken met het project

### Ontwikkeling

Voor lokale ontwikkeling wordt een `.env`-bestand in de root van het project gebruikt om omgevingsvariabelen in te stellen, zoals:

```Dotenv
Database_url=postgresql://myuser:mypassword@localhost:5432/mydatabase
Another_setting=some_value
```

Fastapi en uvicorn kunnen vervolgens worden gestart om de applicatie lokaal te draaien. Dit maakt lokale testing en ontwikkeling eenvoudig, terwijl omgevingsspecifieke configuraties in `.env` beheerd worden.

### Productie

Voor productie wordt de applicatie uitgevoerd in een docker-container, waarbij omgevingsvariabelen niet in de docker-image zelf worden opgenomen. Dit is mogelijk door `.env` uit te sluiten in de `.dockerignore` en variabelen pas bij runtime door te geven.

#### Omgevingsvariabelen in productie

Omgevingsvariabelen kunnen worden meegegeven tijdens de runtime van de docker-container, zonder dat de `.env` in de image aanwezig is. Dit gebeurt bijvoorbeeld via:

```Bash
Docker run -e database_url="postgresql://myuser:mypassword@localhost:5432/mydatabase" -p 8000:8000 projectnaam
```

Of door gebruik te maken van een externe `.env`-bestand:

```Bash
Docker run --env-file .env -p 8000:8000 projectnaam
```

Dit zorgt ervoor dat de gevoelige gegevens en configuraties buiten de container zelf blijven, wat veilig en flexibel is voor verschillende omgevingen.

### Toegang tot de applicatie

In zowel ontwikkel- als productieomgevingen is de api beschikbaar via poort 8000. Wanneer de applicatie lokaal draait, kan deze worden geopend op `http://localhost:8000`.

### Veiligheid en best practices

-   **Gevoelige informatie**: `.env`-bestanden zijn toegevoegd aan `.dockerignore` om te voorkomen dat gevoelige gegevens zoals wachtwoorden en api-sleutels in docker-images terechtkomen.
-   **Configuratiebeheer**: voor lokale ontwikkeling worden `.env`-bestanden gebruikt, terwijl in productie de benodigde configuratievariabelen expliciet aan de container worden meegegeven bij het opstarten.
-   **Afzondering van omgevingen**: door omgevingsspecifieke configuratie buiten de image te houden, wordt het gemakkelijker om dezelfde image in meerdere omgevingen (bijv. Staging, productie) te draaien met verschillende configuraties.

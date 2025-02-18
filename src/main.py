from fastapi import FastAPI
from sqlalchemy import MetaData, create_engine, Table, Column, String
from sqlalchemy.sql import select
from databases import Database
from prometheus_client import Counter, Summary, generate_latest, CONTENT_TYPE_LATEST
from starlette.responses import Response
from dotenv import load_dotenv
from functools import wraps
import os

# Load environment variables from .env file
load_dotenv()

app = FastAPI()
applicationKey = "appVersion"

# Database URL from .env
DATABASE_URL = os.getenv("DATABASE_URL")

# Set up SQLAlchemy and Database connection
metadata = MetaData()
database = Database(DATABASE_URL, min_size=1, max_size=10)  # Use connection pooling
engine = create_engine(DATABASE_URL)

# Define the settings table
settings = Table(
    "settings",
    metadata,
    Column("key", String, primary_key=True),
    Column("value", String)
)

# Ensure the settings table exists
def initialize_database():
    metadata.create_all(engine)  # This should only be run once, in a sync context

# Prometheus metrics
REQUEST_COUNT = Counter("http_requests_total", "Total HTTP requests", ["method", "endpoint", "status"])
REQUEST_LATENCY = Summary("http_request_latency_seconds", "Request latency in seconds")

# Initialize database and insert default data
async def initialize_database_async():
    async with database.transaction():
        # Clear existing data in settings
        await database.execute(f"DELETE FROM settings WHERE key = '{applicationKey}'")
        # Insert initial data
        query = settings.insert().values(key=applicationKey, value="3.6.5")
        await database.execute(query)

# Prometheus metrics endpoint
@app.get("/metrics")
async def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

# Decorator for tracking Prometheus metrics
def track_metrics(endpoint: str):
    def decorator(func):
        @wraps(func)  # Preserve the original function's signature
        async def wrapper(*args, **kwargs):
            REQUEST_COUNT.labels(method="GET", endpoint=endpoint, status="200").inc()
            with REQUEST_LATENCY.time():
                return await func(*args, **kwargs)
        return wrapper
    return decorator

# Endpoint to retrieve DbVersion from settings
@app.get("/appVersion")
@track_metrics("/appVersion")
async def root():
    # Fetch DbVersion from settings
    query = select(settings.c.value).where(settings.c.key == applicationKey)
    result = await database.fetch_one(query)
    app_version = result["value"] if result else "Not found"
    return {applicationKey: app_version}

@app.get("/greet/{name}")
@track_metrics("/greet/{name}")
async def greet(name: str):
    return {"message": f"Greetings, {name}!"}

# Initialize database on startup!
@app.on_event("startup")
async def on_startup():
    initialize_database()  # Run this in sync mode
    await database.connect()
    await initialize_database_async()  # Run async setup

@app.on_event("shutdown")
async def on_shutdown():
    await database.disconnect()

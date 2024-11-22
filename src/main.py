import os
from fastapi import FastAPI
from sqlalchemy import create_engine, MetaData, Table, Column, String
from sqlalchemy.sql import select
from databases import Database
from dotenv import load_dotenv
import logging
from contextlib import asynccontextmanager

# Load environment variables from .env file
load_dotenv()

class Config:
    DATABASE_URL = os.getenv("DATABASE_URL")
    SETTINGS_TABLE_NAME = os.getenv("SETTINGS_TABLE_NAME", "settings")
    SETTINGS_KEY_APPVERSION = os.getenv("SETTINGS_KEY_APPVERSION", "appVersion")

    if not DATABASE_URL:
        raise ValueError("DATABASE_URL is niet ingesteld. Controleer je .env-bestand.")

# Configure logging
logging.basicConfig(level=logging.INFO)

# Set up FastAPI
app = FastAPI()

# Set up SQLAlchemy and Database connection
metadata = MetaData()
database = Database(Config.DATABASE_URL)
engine = create_engine(Config.DATABASE_URL)

# Define the settings table
settings = Table(
    Config.SETTINGS_TABLE_NAME,
    metadata,
    Column("key", String, primary_key=True),
    Column("value", String)
)

# Database initialization function
async def initialize_database():
    async with database.transaction():
        await database.execute(
            f"DELETE FROM {Config.SETTINGS_TABLE_NAME} WHERE key = :key",
            {"key": Config.SETTINGS_KEY_APPVERSION}
        )
        query = settings.insert().values(
            key=Config.SETTINGS_KEY_APPVERSION, value="3.5.3"
        )
        await database.execute(query)

# Lifespan context manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    logging.info("Connecting to the database...")
    await database.connect()
    await initialize_database()
    yield
    logging.info("Disconnecting from the database...")
    await database.disconnect()

# Assign the lifespan function to the app
app.router.lifespan_context = lifespan

# Endpoint to retrieve DbVersion from settings
@app.get("/appVersion")
async def get_app_version():
    query = select(settings.c.value).where(settings.c.key == Config.SETTINGS_KEY_APPVERSION)
    result = await database.fetch_one(query)
    app_version = result["value"] if result else "Not found"
    return {Config.SETTINGS_KEY_APPVERSION: app_version}

@app.get("/greet/{name}")
async def greet(name: str):
    return {"message": f"Hallo, {name}!"}

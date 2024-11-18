import os
from fastapi import FastAPI
from sqlalchemy import create_engine, MetaData, Table, Column, String
from sqlalchemy.sql import select
from databases import Database
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

app = FastAPI()
applicationKey = "appVersion"

# Database URL from .env
DATABASE_URL = os.getenv("DATABASE_URL")

# Set up SQLAlchemy and Database connection
metadata = MetaData()
database = Database(DATABASE_URL)
engine = create_engine(DATABASE_URL)

# Define the settings table
settings = Table(
    "settings",
    metadata,
    Column("key", String, primary_key=True),
    Column("value", String)
)

# Create the settings table if it doesn't exist
async def initialize_database():
    await database.connect()
    # Create tables
    metadata.create_all(engine)
    async with database.transaction():
        # Clear existing data in settings
        await database.execute("DELETE FROM settings WHERE key = '" + applicationKey + "'")
        # Insert initial data
        query = settings.insert().values(key=applicationKey, value="3.0")
        await database.execute(query)

# Endpoint to retrieve DbVersion from settings
@app.get("/appVersion")
async def root():
    # Ensure database connection is open
    await database.connect()
    try:
        # Fetch DbVersion from settings
        query = select(settings.c.value).where(settings.c.key == applicationKey)
        result = await database.fetch_one(query)
        app_version = result["value"] if result else "Not found"
        return {applicationKey :  app_version}
    finally:
        await database.disconnect()

@app.get("/greet/{name}")
async def greet(name: str):
    return {"message": f"Hallo, {name}!!!!!"}


# Initialize database on startup
@app.on_event("startup")
async def on_startup():
    await initialize_database()

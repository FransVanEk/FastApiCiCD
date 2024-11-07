

# tests/test_main.py
import sys

from fastapi.testclient import TestClient

sys.path.append("src")
from main import app

client = TestClient(app)

def test_greet():
    response = client.get("/greet/Frans")
    assert response.status_code == 200
    assert response.json() == {"message": "Hallo, Frans!"}

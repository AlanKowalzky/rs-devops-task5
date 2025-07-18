import pytest
from main import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_root(client):
    response = client.get("/")
    assert response.status_code == 200
    assert b"Hello from Flask app deployed with Helm!" in response.data 
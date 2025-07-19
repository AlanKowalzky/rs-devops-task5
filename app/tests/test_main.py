import pytest
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_root_endpoint():
    client = app.test_client()
    response = client.get('/')
    assert response.status_code == 200
    assert b"Hello from Flask app deployed with Helm!" in response.data 

def test_dummy():
    assert 1 == 1 
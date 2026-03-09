import json
import pytest
from app import app

# Fixture do Pytest para criar um cliente de teste da nossa API Flask
@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_health_check(client):
    """Testa se a rota /health está respondendo corretamente para o Load Balancer"""
    response = client.get('/health')
    
    # Verifica se o status code é 200 (OK)
    assert response.status_code == 200
    
    # Verifica se o JSON retornado contém a mensagem correta
    data = json.loads(response.data)
    assert data['status'] == 'healthy'

def test_random_number(client):
    """Testa se a rota principal (/) está retornando um número válido"""
    response = client.get('/')
    
    # Verifica se a página carregou com sucesso
    assert response.status_code == 200
    
    # Verifica o conteúdo do JSON
    data = json.loads(response.data)
    assert 'number' in data
    assert isinstance(data['number'], int)
    assert data['number'] >= 1
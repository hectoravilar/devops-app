# dreamsquad - api backend
# API REST simples desenvolvida em Python usando Flask
# Hospedada no AWS ECS Fargate e exposta através de um Application Load Balancer

import os
from flask import Flask, jsonify
from flask_cors import CORS
from random import randint

# Inicializa a aplicação Flask
app = Flask(__name__)

# Lê a URL do frontend injetada pelo Terraform via variável de ambiente
# Se não encontrar, libera CORS para todas as origens (padrão '*' útil para testes locais)
frontend_url = os.environ.get('FRONTEND_URL', '*')

# Habilita o CORS (Cross-Origin Resource Sharing) restringindo apenas para a origem do S3
# Isso permite que o frontend hospedado no S3 faça requisições para esta API
CORS(app, origins=[frontend_url])

# endpoints da api

@app.route('/')
def random_number():
    """
    Endpoint principal que retorna um número aleatório entre 1 e 1000.
    
    Returns:
        JSON: {'number': int} - Número aleatório gerado
    """
    return jsonify({'number': randint(1, 1000)})

@app.route('/health')
def health_check():
    """
    Endpoint de health check usado pelo Application Load Balancer.
    Retorna status 200 quando a aplicação está saudável.
    
    Returns:
        JSON: {'status': 'healthy'} com HTTP status code 200
    """
    return jsonify({"status": "healthy"}), 200

# inicialização da aplicação

if __name__ == '__main__':
    # Inicia o servidor Flask
    # host='0.0.0.0' permite conexões de qualquer interface de rede (necessário para containers)
    # port=8080 é a porta configurada no ECS Task Definition
    app.run(host='0.0.0.0', port=8080)

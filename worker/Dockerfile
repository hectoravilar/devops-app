FROM python:3.11-slim
WORKDIR /worker/app

# Install the application dependencies
COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "run.py"]
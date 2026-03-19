import os
from dotenv import load_dotenv


class Config:
    # AWS
    AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
    SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL")
    # Database
    DB_HOST = os.getenv("DB_HOST", "localhost")
    DB_USER = os.getenv("DB_USER")
    DB_PASSWORD = os.getenv("DB_PASSWORD")

    @classmethod
    def validate_config(cls):
        missing_vars = []

        if not cls.SQS_QUEUE_URL:
            missing_vars.append("SQS_QUEUE_URL")

        if not cls.DB_PASSWORD:
            missing_vars.append("DB_PASSWORD")

        if missing_vars:
            raise ValueError(
                f"Faltam variaveis de ambiente criticas: {missing_vars}")


Config.validate_config()

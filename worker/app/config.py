import os
from dotenv import load_dotenv

load_dotenv()


class Config:
    # AWS
    AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
    SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL")
    # Database
    DYNAMODB_TABLE_NAME = os.getenv("DYNAMODB_TABLE_NAME", "docflow-documents")

    @classmethod
    def validate_config(cls):
        missing_vars = []

        if not cls.SQS_QUEUE_URL:
            missing_vars.append("SQS_QUEUE_URL")

        if not cls.DYNAMODB_TABLE_NAME:
            missing_vars.append("DYNAMODB_TABLE_NAME")

        if missing_vars:
            raise ValueError(
                f"Faltam variaveis de ambiente criticas: {missing_vars}")


Config.validate_config()

import boto3
from datetime import datetime
import logging

from app.config import Config

logger = logging.getLogger(__name__)

dynamodb = boto3.resource('dynamodb', region_name=Config.AWS_REGION)
table = dynamodb.Table(Config.DYNAMODB_TABLE_NAME)


def save_document(document_id, status: str, s3_path: str):
    """
    Persists the document processing state into DynamoDB.
    """
    try:
        logger.info(f"Saving document {document_id} with status {status}")
        table.put_item(
            Item={
                'document_id': document_id,
                'status': status,
                's3_path': s3_path,
                'updated_at': datetime.utcnow().isoformat()
            }
        )
        logger.info(f"Document {document_id} saved successfully")

    except Exception as e:
        logger.error(f"Error saving document {document_id} to DynamoDB: {e}")
        raise e

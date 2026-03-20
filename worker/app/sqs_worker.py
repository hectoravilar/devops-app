import boto3
import json
import logging

from app.config import Config
from app.database import save_document
from app.pdf_processor import extract_cnpj_from_pdf

logger = logging.getLogger(__name__)

sqs_client = boto3.client('sqs', region_name=Config.AWS_REGION)


def process_messages():
    try:
        response = sqs_client.receive_message(
            QueueUrl=Config.SQS_QUEUE_URL,
            MaxNumberOfMessages=10,
            WaitTimeSeconds=20
        )

        if 'Messages' in response:
            for message in response['Messages']:
                receipt_handle = message['ReceiptHandle']

                try:
                    body = json.loads(message['Body'])
                    document_id = body.get('document_id')
                    s3_path = body.get('s3_path', body.get('document_url'))

                    if document_id and s3_path:
                        s3_parts = s3_path.replace("s3://", "").split("/")
                        bucket_name = s3_parts[0]
                        object_key = "/".join(s3_parts[1:])

                        cnpjs = extract_cnpj_from_pdf(bucket_name, object_key)
                        logger.info(
                            f"Extracted CNPJs for {document_id}: {cnpjs}")

                        save_document(document_id, "PROCESSED", s3_path)
                        logger.info(
                            f"Processed document {document_id} successfully.")

                        sqs_client.delete_message(
                            QueueUrl=Config.SQS_QUEUE_URL,
                            ReceiptHandle=receipt_handle
                        )
                    else:
                        logger.warning(
                            f"Invalid message format: {message['Body']}")
                        sqs_client.delete_message(
                            QueueUrl=Config.SQS_QUEUE_URL,
                            ReceiptHandle=receipt_handle
                        )

                except Exception as e:
                    logger.error(f"Error processing individual message: {e}")

        else:
            logger.info("No messages in queue. Waiting...")

    except Exception as e:
        logger.error(f"Error connecting to SQS: {e}")

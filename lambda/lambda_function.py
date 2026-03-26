import json
import boto3
import os
import uuid

bucket_name = os.environ.get('BUCKET_NAME')
s3_client = boto3.client('s3')


def lambda_handler(event, context):
    file_name = f"uploads/{uuid.uuid4()}.pdf"
    resposta_s3 = s3_client.generate_presigned_post(
        Bucket=bucket_name,
        Key=file_name,
        Fields={
            "Content-Type": "application/pdf"
        },
        Conditions=[
            {"Content-Type": "application/pdf"},
            ["content-length-range", 1, 10485760]
        ],
        ExpiresIn=300
    )
    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(resposta_s3)
    }

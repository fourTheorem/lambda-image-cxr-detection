import base64
from concurrent.futures import ThreadPoolExecutor
import json
import logging
from logging import getLogger
import os

import boto3

MODELLING_FUNCTION_NAME = os.environ['MODELLING_FUNCTION_NAME']

logging.basicConfig()
logger = getLogger(__name__)

lambda_client = boto3.client('lambda')


def handle_kinesis_event(event, context):
    logging.info(event)
    jobs = [
        json.loads(base64.b64decode(record['kinesis']['data']).decode())
        for record in event['Records']
    ]
    with ThreadPoolExecutor(max_workers=20) as ex:
        for job, result in zip(jobs, ex.map(invoke_job, jobs)):
            logger.info({'job': job, 'result': result})


def invoke_job(job):
    payload = {
        'Jobs': [job],
        'RunId': job['RunId'],
    }

    return lambda_client.invoke(
        FunctionName=MODELLING_FUNCTION_NAME,
        InvocationType='Event',
        Payload=json.dumps(payload)
    )

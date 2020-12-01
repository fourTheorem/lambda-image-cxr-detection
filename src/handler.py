import base64
from decimal import Decimal
import json

from aws_lambda_powertools import Logger
import boto3

from aws_test_densenet import run_test

logger = Logger()

table = boto3.resource('dynamodb').Table('ModellingResults')


def process_jobs(jobs):
    result = run_test(jobs)
    logger.info({'result': result})
    with table.batch_writer() as batch:
        for idx, job in enumerate(jobs):
            run_id = job['RunId']
            img_name = job['Key'].split('/')[-1]
            pred = result['preds_list'][idx][0]
            score = Decimal(result['scores_list'][idx][0])
            batch.put_item(Item={
                'pk': 'INFERENCE',
                'sk': f'{run_id}_{img_name}',
                'pred': pred,
                'score': score,
            })
    return result


@logger.inject_lambda_context(log_event=True)
def handle_event(event, context):
    if 'Records' in event:
        jobs = [
            json.loads(base64.b64decode(record['kinesis']['data']).decode())
            for record in event['Records']
        ]
        process_jobs(jobs)
    else:
        # Direct invocation
        process_jobs(event['Jobs'])

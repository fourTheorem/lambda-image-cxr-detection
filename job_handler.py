from concurrent.futures import ThreadPoolExecutor, as_completed
from io import BytesIO

import json
import logging
from logging import getLogger
import os
import pandas as pd
import boto3


logging.basicConfig()
logger = getLogger(__name__)

s3_client = boto3.client('s3')
kinesis_client = boto3.client('kinesis')

STREAM_NAME = os.environ['JOB_STREAM_NAME']
KINESIS_BATCH_SIZE = 500


def handle_event(event, context):
    logging.info(event)
    job_count = event['JobCount']
    run_id = event['RunId']
    job_records = _get_job_records(run_id, job_count)

    futs = []
    with ThreadPoolExecutor(max_workers=10) as ex:
        for batch_start in range(0, job_count, KINESIS_BATCH_SIZE):
            futs.append(ex.submit(create_jobs, job_records[batch_start:batch_start + KINESIS_BATCH_SIZE]))

    for f in as_completed(futs):
        f.result()


def create_jobs(jobs):
    records = [{
        'Data': json.dumps(job),
        'PartitionKey': str(job['Key'])  # No ordering / shard stickiness required
    } for job in jobs]

    kinesis_client.put_records(
        StreamName=STREAM_NAME,
        Records=records
    )


def _get_job_records(run_id, job_count):
    index_csv_obj = BytesIO()
    s3_client.download_fileobj(Bucket='ft-modelling-lbeta', Key='cxr-nih/index.csv', Fileobj=index_csv_obj)
    index_csv_obj.seek(0)
    index_df = pd.read_csv(index_csv_obj, nrows=job_count)
    assert len(index_df) == job_count
    jobs_df = index_df.assign(RunId=run_id)
    return jobs_df.to_dict('records')

import boto3

def lambda_handler(event, context):
    """
    Create a DataSync task efs to s3.
    """
    datasync_client = boto3.client('datasync')
    response = datasync_client.create_task(
        SourceLocationArn=source_location_arn,
        DestinationLocationArn=destination_location_arn,
        Name=task_name,
        Options={
            'VerifyMode': 'ONLY_FILES_TRANSFERRED',
            'OverwriteMode': 'ALWAYS'
        }
    )

    """
    Create a DataSync task s3 to efs.
    """
    datasync_client = boto3.client('datasync')
    response = datasync_client.create_task(
        SourceLocationArn=source_location_arn,
        DestinationLocationArn=destination_location_arn,
        Name=task_name,
        Options={
            'VerifyMode': 'ONLY_FILES_TRANSFERRED',
            'OverwriteMode': 'ALWAYS'
        }
    )

    """
    Submit a job to an AWS Batch queue.
    """
    batch_client = boto3.client('batch')
    response = batch_client.submit_job(
        jobName=job_name,
        jobQueue=job_queue,
        jobDefinition=job_definition,
        parameters=parameters
    )
    return response['jobId']

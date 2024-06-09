import boto3

def lambda_handler(event, context):
    # Extract bucket name and object key from the S3 event
    bucket_name = event['detail']['bucket']['name']
    object_key = event['detail']['object']['key']
    print("bucketName: " + bucket_name)
    print("ObjectName: " + object_key)

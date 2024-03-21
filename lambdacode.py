import boto3

def lambda_handler(event, context):
    # Extract cluster ID from the input payload
    cluster_id = event.get('cluster_id')
    if cluster_id is None:
        return {
            'statusCode': 400,
            'body': 'Cluster ID not provided in the input payload.'
        }
    
    # Define job configuration
    job_config = {
        "Name": "MyEMRJob",
        "ActionOnFailure": "CONTINUE",
        "HadoopJarStep": {
            "Jar": "command-runner.jar",
            "Args": [
                "spark-submit",
                "--deploy-mode",
                "cluster",
                "--py-files",
                "s3://myemrproject1/scripts/mypysparkscript_1.py"
            ]
        }
    }
    
    # Create an EMR client
    emr_client = boto3.client('emr')
    
    # Add the job step to the EMR cluster
    try:
        response = emr_client.add_job_flow_steps(
            JobFlowId=cluster_id,
            Steps=[job_config]
        )
        return {
            'statusCode': 200,
            'body': response
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': str(e)
        }

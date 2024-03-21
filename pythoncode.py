import boto3

def lambda_handler(event, context):
    # Replace with your Step Function ARN
    state_machine_arn = "arn:aws:states:us-east-1:655625281801:stateMachine:emr_step_function"

    # Start Step Function execution
    start_step_function_execution(state_machine_arn)

def start_step_function_execution(state_machine_arn):
    # Create a Step Functions client
    client = boto3.client('stepfunctions')

    # Start the execution
    response = client.start_execution(
        stateMachineArn=state_machine_arn
    )

    # Print the response
    print("Step Function execution started successfully.")
    print("Execution ARN:", response['executionArn'])

if __name__ == "__main__":
    lambda_handler({}, None)


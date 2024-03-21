provider "aws" {
  region = "us-east-1" # Change this to your desired region
}

# Use existing S3 Bucket
data "aws_s3_bucket" "existing_bucket" {
  bucket = "stack-overflow-analysis-bucket"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "pythoncode.py"
  output_path = "Outputs/lambda.zip"
}

data "aws_iam_role" "lambda_exec" {
  name = "LambdaS3Role"  # Assuming LambdaS3Role is the name of your IAM role
}

# Lambda Function
resource "aws_lambda_function" "start_step_function_lambda" {
  function_name = "start_step_function_lambda"
  handler       = "pythoncode.lambda_handler"
  runtime       = "python3.8"
  role          = data.aws_iam_role.lambda_exec.arn  # Using IAM role fetched from the data source
  filename      = "Outputs/lambda.zip"               # Change to your Lambda function code package
}

data "archive_file" "lambda1" {
  type        = "zip"
  source_file = "lambdacode.py"
  output_path = "Output/lambda1.zip"
}
data "aws_iam_role" "lambda_exec1" {
  name = "LambdaS3Role"  # Assuming LambdaS3Role is the name of your IAM role
}
# Lambda Function
resource "aws_lambda_function" "submitjob" {
  function_name = "submitjob"
  handler       = "lambdacode.lambda_handler"
  runtime       = "python3.8"
  role          = data.aws_iam_role.lambda_exec1.arn # Using IAM role fetched from the data source
  filename      = "Output/lambda1.zip"               # Change to your Lambda function code package
}



# Step Function
resource "aws_sfn_state_machine" "emr_step_function" {
  name     = "emr_step_function"
  role_arn = "arn:aws:iam::655625281801:role/stepemrrole" 

  definition = <<EOF
{
  "Comment": "EMR Job Execution",
  "StartAt": "CreateEMRCluster",
  "States": {
    "CreateEMRCluster": {
      "Type": "Task",
      "Resource": "arn:aws:states:::elasticmapreduce:createCluster.sync",
      "Parameters": {
        "Name": "MyEMRCluster",
        "ReleaseLabel": "emr-6.2.0",
        "Instances": {
          "KeepJobFlowAliveWhenNoSteps": true,
          "InstanceCount": 2,
          "MasterInstanceType": "m5.xlarge",
          "SlaveInstanceType": "m5.xlarge"
        },
        "ServiceRole": "arn:aws:iam::655625281801:role/service-role/AmazonEMR-ServiceRole-20240130T191352",
        "JobFlowRole": "arn:aws:iam::655625281801:instance-profile/AmazonEMR-InstanceProfile-20240130T160741",
        "Applications": [
          {"Name": "Spark"}
        ],
        "Configurations": [
          {
            "Classification": "spark",
            "Properties": {
              "maximizeResourceAllocation": "true"
            }
          },
          {
            "Classification": "core-site",
            "Properties": {
              "fs.s3.impl": "org.apache.hadoop.fs.s3a.S3AFileSystem",
              "fs.s3a.awsAccessKeyId": "YOUR_ACCESS_KEY_ID",
              "fs.s3a.awsSecretAccessKey": "YOUR_SECRET_ACCESS_KEY",
              "fs.s3a.endpoint": "s3.amazonaws.com",
              "fs.s3a.connection.ssl.enabled": "true",
              "fs.s3a.logging.enabled": "true", 
              "fs.s3a.bucket.myemrproject1.logs": "s3://myemrproject1/logs/" 
            }
          },
          {
            "Classification": "hadoop-env",
            "Properties": {},
            "Configurations": [
              {
                "Classification": "export",
                "Properties": {
                  "HADOOP_ROOT_LOGGER": "INFO,console"
                }
              }
            ]
          }
        ]
      },
      "ResultPath": "$.ClusterCreationOutput", 
      "Next": "WaitForClusterReady"
    },
    "WaitForClusterReady": {
      "Type": "Wait",
      "Seconds": 60,
      "Next": "InvokeLambdaSubmitJob"
    },
    "InvokeLambdaSubmitJob": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "arn:aws:lambda:us-east-1:655625281801:function:teststepfunction",
        "Payload": {
          "cluster_id.$": "$.ClusterCreationOutput.ClusterId" 
        }
      },
      "Next": "FinalState"
    },
    "FinalState": {
      "Type": "Pass",
      "End": true
    }
  }
}
EOF
}
# CloudWatch Event Rule
resource "aws_cloudwatch_event_rule" "scheduled_event_rule" {
  name        = "scheduled_event_rule"
  description = "Trigger Step Function at 4:52 PM IST today"
  schedule_expression = "cron(22 11 * * ? *)"  # Trigger at 4:52 PM IST today
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.scheduled_event_rule.name
  target_id = "start_step_function_lambda"
  arn       = "arn:aws:lambda:us-east-1:655625281801:function:start_step_function_lambda"
}

resource "aws_lambda_permission" "event_invoke_lambda" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_step_function_lambda.function_name
  principal     = "events.amazonaws.com"
}

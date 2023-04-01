import os

def check_serverless():

    if "AWS_LAMBDA_FUNCTION_NAME" in os.environ:
        return 'aws-lambda'
    else:
        return None

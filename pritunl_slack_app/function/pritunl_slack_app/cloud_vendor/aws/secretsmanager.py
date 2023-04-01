import os
import urllib3
import json

def get_secret(secret_arn):
    http = urllib3.PoolManager()
    headers = { "X-Aws-Parameters-Secrets-Token": os.environ['AWS_SESSION_TOKEN'] }
    response = http.request("GET", ('http://localhost:2773/secretsmanager/get?secretId=' + secret_arn), headers=headers)
    return json.loads(response.data)['SecretString']

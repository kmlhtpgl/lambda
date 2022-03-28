import json
from urllib import response
import boto3
import pprint
import random

aws_client = boto3.client('ssm')

def lambda_handler(event, context):

    body = {"message": "You did not provide a valid Parameter Name"}
    
    p_name = event['queryStringParameters']['ParameterName']
    #p_value = ""
    #p_value = str(random.randint(1000,10000))
    
    
    
    try:
        if event['httpMethod']=='GET' and aws_client.get_parameter( Name = p_name, WithDecryption=True ):
            p_value = str(random.randint(1000,10000))
            aws_client.put_parameter(Name = p_name, Description="A test parameter1", Value= p_value, Type="String", 
    Overwrite=True)
            msg = {'ParameterName': str(p_name), 'ParameterValue':p_value}
    except Exception as e:
        p_value = str(random.randint(1000,10000))
        aws_client.put_parameter(Name = p_name, Description="A test parameter2", Value= p_value, Type="String", 
    Overwrite=True)
        msg = {'ParameterName': str(p_name), 'ParameterValue':p_value}
        pass
    
    response = {'statusCode': 200, 'body': json.dumps(msg) }
    return response


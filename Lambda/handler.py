import boto3
import json
import os
import logging
import base64

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')
ecs_client = boto3.client('ecs')

CLUSTER = "demo-ecs-cluster"
SERVICE_NAME = "ki-service"

# Umgebungsvariablen
CONTAINER_NAME = os.environ.get('CONTAINER_NAME', 'ki-service')
SUBNETS = os.environ.get('SUBNETS', 'subnet-00f40920583244da3,subnet-09fbf13b264b08404').split(',')
SECURITY_GROUPS = os.environ.get('SECURITY_GROUPS', 'sg-0e2d95ac916c7d836').split(',')
LAUNCH_TYPE = os.environ.get('LAUNCH_TYPE', 'FARGATE') 

def lambda_handler(event, context):
    logger.info("Ereignis erhalten: " + json.dumps(event))
    
    # Bucket und Dateiname aus dem S3-Event extrahieren
    try:
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = event['Records'][0]['s3']['object']['key']
        logger.info(f"Bucket: {bucket}, Key: {key}")
    except Exception as e:
        logger.error("Fehler beim Parsen des Events: " + str(e))
        raise e

    # Datei aus S3 auslesen
    try:
        response = s3_client.get_object(Bucket=bucket, Key=key)
        binary_data = response['Body'].read()
        file_content = base64.b64encode(binary_data).decode('utf-8')
        logger.info("Dateiinhalt erfolgreich ausgelesen")
    except Exception as e:
        logger.error("Fehler beim Lesen der Datei aus S3: " + str(e))
        raise e

    # Task-Definition aus dem existierenden Service abrufen
    try:
        service_response = ecs_client.describe_services(
            cluster=CLUSTER,
            services=[SERVICE_NAME]
        )
        services = service_response.get('services', [])
        if not services:
            raise Exception(f"Service {SERVICE_NAME} nicht gefunden in Cluster {CLUSTER}")
        task_definition = services[0]['taskDefinition']
        logger.info(f"Verwendete Task-Definition: {task_definition}")
    except Exception as e:
        logger.error("Fehler beim Abrufen der Service-Details: " + str(e))
        raise e

    # Container-Overrides definieren, um den Dateiinhalt als Umgebungsvariable zu übergeben
    container_overrides = [
    {
        'name': CONTAINER_NAME,
        'environment': [
            {'name': 'S3_BUCKET', 'value': bucket},
            {'name': 'S3_KEY', 'value': key}
        ]
    }
]

    # ECS Task starten
    try:
        ecs_response = ecs_client.run_task(
            cluster=CLUSTER,
            launchType=LAUNCH_TYPE,
            taskDefinition=task_definition,
            networkConfiguration={
                'awsvpcConfiguration': {
                    'subnets': SUBNETS,
                    'securityGroups': SECURITY_GROUPS,
                    'assignPublicIp': 'ENABLED'
                }
            },
            overrides={
                'containerOverrides': container_overrides
            }
        )
        logger.info("ECS Task gestartet: " + json.dumps(ecs_response, default=str))

    except Exception as e:
        logger.error("Fehler beim Starten des ECS Tasks: " + str(e))
        raise e

    return {
        'statusCode': 200,
        'body': json.dumps('ECS Task erfolgreich gestartet')
    }

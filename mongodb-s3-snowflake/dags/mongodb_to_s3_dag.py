from datetime import datetime, timedelta
import os
import json
import pymongo
import boto3
from airflow import DAG
from airflow.operators.python import PythonOperator
from dotenv import load_dotenv
from urllib.parse import quote_plus

# Load environment variables from .env file
load_dotenv()

# Create MongoDB URI with properly encoded username and password
username = "akhil"
password = "Akhil@1997"
host = "datasarva.m5jbp.mongodb.net"
encoded_username = quote_plus(username)
encoded_password = quote_plus(password)
MONGODB_URI = f"mongodb+srv://{encoded_username}:{encoded_password}@{host}/?retryWrites=true&w=majority&appName=datasarva"

# Get other environment variables
MONGODB_DB = os.environ.get('MONGODB_DATABASE')
MONGODB_COLLECTION = os.environ.get('MONGODB_COLLECTION')
S3_BUCKET = os.environ.get('S3_BUCKET')
S3_PREFIX = os.environ.get('S3_PREFIX')
BATCH_SIZE = int(os.environ.get('BATCH_SIZE', 1000))

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'mongodb_to_s3_extract',
    default_args=default_args,
    description='Extract data from MongoDB and load to S3',
    schedule_interval=os.environ.get('EXTRACT_FREQUENCY', '@daily'),
    start_date=datetime(2025, 2, 1),
    catchup=False,
)

def extract_load_task(**context):
    """Extract data from MongoDB and load to S3."""
    task_instance = context['task_instance']
    
    # Log the start of processing
    task_instance.xcom_push(key='start_time', value=str(datetime.now()))
    
    try:
        # Get execution date
        execution_date = context['execution_date'].strftime('%Y-%m-%d')
        
        # Connect to MongoDB
        print(f"Attempting to connect to MongoDB with URI: {MONGODB_URI}")  # Add debug logging
        client = pymongo.MongoClient(MONGODB_URI)
        
        # Test the connection
        client.admin.command('ping')
        print("Successfully connected to MongoDB")
        
        db = client[MONGODB_DB]
        collection = db[MONGODB_COLLECTION]
        
        # Get data count and log it
        total_documents = collection.count_documents({})
        print(f"Found {total_documents} documents in collection")
        
        if total_documents == 0:
            print("Warning: No documents found in the collection")
            return "No documents found to process"
        
        # S3 client
        s3_client = boto3.client('s3')
        
        # Process in batches
        for skip in range(0, total_documents, BATCH_SIZE):
            batch_num = skip // BATCH_SIZE
            documents = list(collection.find().skip(skip).limit(BATCH_SIZE))
            
            # Convert MongoDB documents to JSON
            json_data = []
            for doc in documents:
                # Convert ObjectId to string
                doc['_id'] = str(doc['_id'])
                json_data.append(doc)
            
            # Save to S3
            s3_key = f"{S3_PREFIX}{MONGODB_COLLECTION}/{execution_date}/batch_{batch_num}.json"
            s3_client.put_object(
                Bucket=S3_BUCKET,
                Key=s3_key,
                Body=json.dumps(json_data, default=str),
                ContentType='application/json'
            )
            
            print(f"Uploaded batch {batch_num} to S3: s3://{S3_BUCKET}/{s3_key}")
        
        # Close MongoDB connection
        client.close()
        
        # Log processing metrics
        task_instance.xcom_push(key='total_documents', value=total_documents)
        task_instance.xcom_push(key='total_batches', value=(total_documents // BATCH_SIZE) + 1)
        
        return f"Processed {total_documents} documents from MongoDB to S3"
    except pymongo.errors.PyMongoError as e:
        print(f"MongoDB error: {e}")
        raise
    except boto3.exceptions.S3UploadFailedError as e:
        print(f"S3 upload error: {e}")
        raise
    except Exception as e:
        print(f"Unexpected error: {e}")
        raise

extract_load = PythonOperator(
    task_id='extract_load_mongodb_to_s3',
    python_callable=extract_load_task,
    provide_context=True,
    dag=dag,
)
# Task dependencies (only one task for now)
extract_load

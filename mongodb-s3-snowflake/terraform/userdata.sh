#!/bin/bash

# Log the start of the script execution
echo "Starting Apache Airflow setup on EC2 instance" > /var/log/airflow-setup.log

# Update packages and install git
echo "Updating packages and installing git..." >> /var/log/airflow-setup.log
sudo apt-get update -y
sudo apt-get install git -y

# Clone the repository
echo "Cloning repository..." >> /var/log/airflow-setup.log
cd /home/ubuntu
git clone https://github.com/AkhilGurrapu/Data-Engineering-Toolkit.git
cd Data-Engineering-Toolkit/mongodb-s3-snowflake

# Create .env file with proper permissions
echo "Creating .env file..." >> /var/log/airflow-setup.log

# Create temporary .env file with placeholder
cat > .env << 'EOL'
# MongoDB connection string (with properly encoded credentials)
export MONGODB_CONNECTION_URI="mongodb+srv://akhil:Akhil%401997@datasarva.m5jbp.mongodb.net/?retryWrites=true&w=majority&appName=datasarva"

# MongoDB database and collection
export MONGODB_DATABASE="sample_mflix"
# No need for MONGODB_COLLECTION anymore as we're processing all collections

# AWS Configuration
export AWS_REGION="us-west-2"
export S3_BUCKET="datasarva-mongodb-data-lake"
export S3_PREFIX="raw/sample_mflix/"

# Process configuration
export BATCH_SIZE=1000
export EXTRACT_FREQUENCY="@daily"
EOL

# Now encode the MongoDB URI properly using a more robust Python script
python3 -c '
import os
from urllib.parse import quote_plus, urlparse, urlunparse

def encode_mongodb_uri(uri):
    # Parse the URI
    parts = uri.split("mongodb+srv://", 1)
    if len(parts) != 2:
        return uri
    
    # Split credentials and host
    creds_host = parts[1].split("@", 1)
    if len(creds_host) != 2:
        return uri
    
    # Split username and password
    user_pass = creds_host[0].split(":", 1)
    if len(user_pass) != 2:
        return uri
    
    # Encode username and password
    encoded_user = quote_plus(user_pass[0])
    encoded_pass = quote_plus(user_pass[1])
    
    # Reconstruct the URI
    return f"mongodb+srv://{encoded_user}:{encoded_pass}@{creds_host[1]}"

# Read the current .env file
with open(".env", "r") as f:
    content = f.read()

# Find the MongoDB URI line
for line in content.split("\n"):
    if "MONGODB_CONNECTION_URI" in line:
        uri_line = line
        break

# Extract the URI
uri = uri_line.split("=")[1].strip().strip(\'"\')

# Encode the URI
encoded_uri = encode_mongodb_uri(uri)

# Replace the old URI with the encoded one
new_content = content.replace(uri, encoded_uri)

# Write back to .env
with open(".env", "w") as f:
    f.write(new_content)
'

# Step 1: Update packages
echo "Updating packages..." >> /var/log/airflow-setup.log
sudo apt-get update -y

# Step 2: Install required tools
echo "Installing Python3 package manager..." >> /var/log/airflow-setup.log
sudo apt install python3-pip -y

# Install Python packages with specific versions
echo "Installing Python packages with specific versions..." >> /var/log/airflow-setup.log
sudo pip install --upgrade pip
sudo pip install "apache-airflow==2.7.1"
sudo pip install "pymongo==4.5.0"
sudo pip install "boto3==1.28.44"
sudo pip install "python-dotenv==1.0.0"
sudo pip install "pyOpenSSL==23.2.0"
sudo pip install "cryptography==41.0.3"

# Add after Python packages installation and before Airflow setup
echo "Testing MongoDB connection..." >> /var/log/airflow-setup.log
python3 -c '
import os
import pymongo
from dotenv import load_dotenv

load_dotenv()

uri = os.environ.get("MONGODB_CONNECTION_URI")
try:
    client = pymongo.MongoClient(uri)
    client.admin.command("ping")
    db = client[os.environ.get("MONGODB_DATABASE")]
    collection = db[os.environ.get("MONGODB_COLLECTION")]
    count = collection.count_documents({})
    print(f"Successfully connected to MongoDB. Found {count} documents.")
    client.close()
except Exception as e:
    print(f"Error connecting to MongoDB: {e}")
    raise
' >> /var/log/airflow-setup.log 2>&1

# Set AIRFLOW_HOME and create necessary directories
export AIRFLOW_HOME=/home/ubuntu/airflow
mkdir -p ${AIRFLOW_HOME}/dags
mkdir -p ${AIRFLOW_HOME}/logs
mkdir -p ${AIRFLOW_HOME}/plugins

# Initialize Airflow with the correct permissions
echo "Initializing Airflow..." >> /var/log/airflow-setup.log
sudo -u ubuntu AIRFLOW_HOME=${AIRFLOW_HOME} airflow db init

# Configure Airflow settings
echo "Configuring Airflow..." >> /var/log/airflow-setup.log
sudo sed -i 's/load_examples = True/load_examples = False/' ${AIRFLOW_HOME}/airflow.cfg
sudo sed -i 's/web_server_host = 127.0.0.1/web_server_host = 0.0.0.0/' ${AIRFLOW_HOME}/airflow.cfg
sudo sed -i 's|^dags_folder =.*|dags_folder = /home/ubuntu/airflow/dags|g' ${AIRFLOW_HOME}/airflow.cfg

# Copy DAG and .env files
echo "Copying DAG and environment files..." >> /var/log/airflow-setup.log
cp dags/mongodb_to_s3_dag.py ${AIRFLOW_HOME}/dags/
cp .env ${AIRFLOW_HOME}/

# Update DAG start date
sed -i 's/datetime(2025, 2, 1)/datetime(2025, 2, 26)/' ${AIRFLOW_HOME}/dags/mongodb_to_s3_dag.py

# Create Airflow user
echo "Creating Airflow admin user..." >> /var/log/airflow-setup.log
sudo -u ubuntu AIRFLOW_HOME=${AIRFLOW_HOME} airflow users create \
    --username admin \
    --firstname Admin \
    --lastname User \
    --role Admin \
    --email admin@example.com \
    --password airflow

# Add this after creating .env file and before starting Airflow services
echo "Setting up AWS configuration..." >> /var/log/airflow-setup.log

# Add AWS region to environment
cat >> /home/ubuntu/airflow/.env << EOL

# AWS Configuration
export AWS_DEFAULT_REGION=us-west-2
EOL

# Create systemd service files with AWS configuration
echo "Creating service files..." >> /var/log/airflow-setup.log
cat > /etc/systemd/system/airflow-webserver.service << EOL
[Unit]
Description=Airflow webserver
After=network.target

[Service]
User=ubuntu
Group=ubuntu
Type=simple
Environment="AIRFLOW_HOME=/home/ubuntu/airflow"
Environment="AWS_DEFAULT_REGION=us-west-2"
EnvironmentFile=/home/ubuntu/airflow/.env
ExecStart=/usr/local/bin/airflow webserver
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOL

cat > /etc/systemd/system/airflow-scheduler.service << EOL
[Unit]
Description=Airflow scheduler
After=network.target

[Service]
User=ubuntu
Group=ubuntu
Type=simple
Environment="AIRFLOW_HOME=/home/ubuntu/airflow"
Environment="AWS_DEFAULT_REGION=us-west-2"
EnvironmentFile=/home/ubuntu/airflow/.env
ExecStart=/usr/local/bin/airflow scheduler
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOL

# Set correct ownership and permissions
echo "Setting permissions..." >> /var/log/airflow-setup.log
sudo chown -R ubuntu:ubuntu ${AIRFLOW_HOME}
sudo chmod -R 775 ${AIRFLOW_HOME}
sudo chmod 644 ${AIRFLOW_HOME}/dags/*.py
sudo chmod 644 ${AIRFLOW_HOME}/.env

# Reload systemd and start services
echo "Starting Airflow services..." >> /var/log/airflow-setup.log
sudo systemctl daemon-reload
sudo systemctl enable airflow-webserver
sudo systemctl enable airflow-scheduler
sudo systemctl start airflow-webserver
sudo systemctl start airflow-scheduler

# Verify services are running
echo "Verifying services..." >> /var/log/airflow-setup.log
sudo systemctl status airflow-webserver >> /var/log/airflow-setup.log
sudo systemctl status airflow-scheduler >> /var/log/airflow-setup.log

echo "Apache Airflow setup completed. Access the webserver at http://YOUR_EC2_IP:8080" >> /var/log/airflow-setup.log
echo "Username: admin" >> /var/log/airflow-setup.log
echo "Password: airflow" >> /var/log/airflow-setup.log

# Don't forget to update the security group to allow traffic on port 8080
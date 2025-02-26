#!/bin/bash

# Log the start of the script execution
echo "Starting Apache Airflow setup on EC2 instance" > /var/log/airflow-setup.log

# Step 1: Update packages
echo "Updating packages..." >> /var/log/airflow-setup.log
sudo apt-get update -y

# Step 2: Install required tools
echo "Installing Python3 package manager..." >> /var/log/airflow-setup.log
sudo apt install python3-pip -y

# Install Apache Airflow
echo "Installing Apache Airflow..." >> /var/log/airflow-setup.log
sudo pip install apache-airflow

# Install Amazon provider for Apache Airflow
echo "Installing Amazon provider for Apache Airflow..." >> /var/log/airflow-setup.log
sudo pip install apache-airflow-providers-amazon

# Step 3: Create DAGs directory
echo "Creating DAGs directory..." >> /var/log/airflow-setup.log
mkdir -p /home/ubuntu/airflow/dags

# Step 4: Configure Airflow
echo "Initializing Airflow database..." >> /var/log/airflow-setup.log
export AIRFLOW_HOME=/home/ubuntu/airflow
airflow db init

# Create a user for Airflow webserver
echo "Creating Airflow admin user..." >> /var/log/airflow-setup.log
airflow users create \
    --username admin \
    --firstname Admin \
    --lastname User \
    --role Admin \
    --email admin@example.com \
    --password airflow

# Update the dags_folder parameter in airflow.cfg
echo "Updating Airflow configuration..." >> /var/log/airflow-setup.log
sed -i 's|^dags_folder =.*|dags_folder = /home/ubuntu/airflow/dags|g' /home/ubuntu/airflow/airflow.cfg

# Step 5: Setup Airflow to start automatically on system boot
echo "Setting up Airflow service..." >> /var/log/airflow-setup.log

# Create systemd service file for Airflow webserver
cat > /etc/systemd/system/airflow-webserver.service << 'EOL'
[Unit]
Description=Airflow webserver
After=network.target

[Service]
User=ubuntu
Group=ubuntu
Type=simple
ExecStart=/usr/local/bin/airflow webserver
Restart=on-failure
RestartSec=5s
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOL

# Create systemd service file for Airflow scheduler
cat > /etc/systemd/system/airflow-scheduler.service << 'EOL'
[Unit]
Description=Airflow scheduler
After=network.target

[Service]
User=ubuntu
Group=ubuntu
Type=simple
ExecStart=/usr/local/bin/airflow scheduler
Restart=on-failure
RestartSec=5s
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOL

# Change permissions for the airflow directory to ubuntu user
echo "Setting correct permissions..." >> /var/log/airflow-setup.log
chown -R ubuntu:ubuntu /home/ubuntu/airflow

# Enable and start the services
echo "Enabling and starting Airflow services..." >> /var/log/airflow-setup.log
systemctl daemon-reload
systemctl enable airflow-webserver
systemctl enable airflow-scheduler
systemctl start airflow-webserver
systemctl start airflow-scheduler

# For standalone mode (alternative to separate webserver and scheduler)
# echo "Starting Airflow in standalone mode..." >> /var/log/airflow-setup.log
# sudo -u ubuntu bash -c 'export AIRFLOW_HOME=/home/ubuntu/airflow && airflow standalone' &

echo "Apache Airflow setup completed. Access the webserver at http://YOUR_EC2_IP:8080" >> /var/log/airflow-setup.log
echo "Username: admin" >> /var/log/airflow-setup.log
echo "Password: airflow" >> /var/log/airflow-setup.log

# Don't forget to update the security group to allow traffic on port 8080
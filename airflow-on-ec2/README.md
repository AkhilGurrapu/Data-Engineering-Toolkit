# Airflow Terraform AWS

This project provides a simple example of how to deploy an Apache Airflow environment on AWS using Terraform.

## Prerequisites

Before you begin, ensure you have the following installed:

- [Terraform](https://www.terraform.io/downloads.html)
- [AWS CLI](https://aws.amazon.com/cli/)

## Setup Instructions

Follow these steps to set up the Airflow environment:

1. **Clone the Repository**
   ```bash
   git clone https://github.com/AkhilGurrapu/Data-Engineering-Toolkit.git
   ```

2. **Navigate to the Airflow Terraform AWS Directory**
   ```bash
   cd airflow-terraform-aws
   ```

3. **Configure AWS Credentials**
   Ensure your AWS credentials are configured. You can do this by running:
   ```bash
   aws configure
   ```
   You will need to provide your AWS Access Key, Secret Key, region, and output format.

4. **Initialize Terraform**
   Run the following command to initialize Terraform:
   ```bash
   terraform init
   ```

5. **Review the Terraform Plan**
   Before applying the changes, review what Terraform will create:
   ```bash
   terraform plan
   ```

6. **Apply the Terraform Configuration**
   To create the resources defined in the Terraform configuration, run:
   ```bash
   terraform apply
   ```
   Confirm the action when prompted.

7. **Access the Airflow Webserver**
   After the resources are created, you can access the Airflow webserver using the public IP address of the EC2 instance. The default URL will be:
   ```
   http://<YOUR_EC2_IP>:8080
   ```
   Replace `<YOUR_EC2_IP>` with the actual IP address of your EC2 instance.

   To access public IP address of your EC2 instance is:
   ```
   terraform output instance_public_ip
   ```
   The default username is `admin` and the password is `airflow`.

8. **Update Security Group**
   Ensure that your AWS security group allows inbound traffic on port 8080 to access the Airflow webserver.

## Cleanup

To remove all resources created by Terraform, run:
```bash
terraform destroy
```
Confirm the action when prompted.

## Additional Information

For more detailed information on how to use Airflow, refer to the [Airflow Documentation](https://airflow.apache.org/docs/apache-airflow/stable/).

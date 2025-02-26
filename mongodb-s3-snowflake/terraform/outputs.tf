output "instance_public_ip" {
  description = "Public IP of the Airflow EC2 instance"
  value       = aws_instance.airflow_instance.public_ip
}

output "instance_public_dns" {
  description = "Public DNS of the Airflow EC2 instance"
  value       = aws_instance.airflow_instance.public_dns
}

output "private_key_path" {
  description = "Path to the private key file"
  value       = local_file.private_key.filename
} 

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.mongodb_data_lake.bucket
}
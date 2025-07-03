# General cluster configuration
aws_region           = "us-west-1"
cluster_name         = "ner-eks2"
s3_bucket_name       = "ner-backend-test-1"
cluster_version      = "1.31"
vpc_id               = "vpc-0da33d20daf0991c9"                    # Replace with your VPC ID
private_subnets      = ["subnet-03a728dd68184cbf0", "subnet-0454326c7fb260a21"] # Replace with your private subnet IDs
private_subnets_cidr = ["10.0.128.0/20", "10.0.144.0/20"]             # CIDRs for the private subnets

node_group_desired_size = 2
node_group_max_size     = 4
node_group_min_size     = 2
node_group_instance_types   = ["c5.2xlarge"]

# RDS Configuration
rds_instance_class        = "db.t3.micro"
rds_master_username       = "myadmin"
rds_master_password       = "mypassword"
rds_storage_size_gb       = 20
rds_backup_retention_days = 7
rds_backup_window         = "07:00-09:00"
rds_encryption_enabled    = false
rds_kms_key_id            = ""

# Existing Resource Configuration (Optional)
# existing_rds_endpoint = ""
# existing_rds_username = "myadmin"
# existing_rds_password = "mypassword"

# General cluster configuration
aws_region           = "us-east-1"
cluster_name         = "thirdai-eks"
cluster_version      = "1.31"
vpc_id               = "vpc-xxx"                    # Replace with your VPC ID
private_subnets      = ["subnet-xxx", "subnet-xxx"] # Replace with your private subnet IDs
private_subnets_cidr = ["xxxx", "xxxx"]             # CIDRs for the private subnets

node_group_desired_size = 1
node_group_max_size     = 4
node_group_min_size     = 1
node_group_instance_types   = ["t3.medium"]

# RDS Configuration
rds_instance_class        = "db.t3.micro"
rds_master_username       = "myadmin"
rds_master_password       = "mypassword"
rds_storage_size_gb       = 20
rds_backup_retention_days = 7
rds_backup_window         = "07:00-09:00"
rds_encryption_enabled    = false
rds_kms_key_id            = ""

# EFS Configuration
efs_backup_enabled               = true
efs_encryption_enabled           = true
efs_lifecycle_policy_transition  = "AFTER_30_DAYS"
efs_performance_mode             = "generalPurpose"
efs_throughput_mode              = "bursting"
efs_provisioned_throughput_mibps = 10

# Existing Resource Configuration (Optional)
existing_efs_id       = ""
existing_rds_endpoint = ""
existing_rds_username = "myadmin"
existing_rds_password = "mypassword"

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "thirdai-eks"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31"
}

variable "vpc_id" {
  description = "VPC ID in which to deploy the cluster"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "private_subnets_cidr" {
  description = "List of CIDR blocks for the private subnets"
  type        = list(string)
  default     = []
}

variable "node_group_desired_size" {
  description = "Desired size for the EKS managed node group"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum size for the EKS managed node group"
  type        = number
  default     = 4
}

variable "node_group_min_size" {
  description = "Minimum size for the EKS managed node group"
  type        = number
  default     = 1
}

variable "node_group_instance_types" {
  description = "Instance types for the EKS managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_master_username" {
  description = "RDS master username"
  type        = string
  default     = "myadmin"
}

variable "rds_master_password" {
  description = "RDS master password"
  type        = string
  default     = "mypassword"
}

variable "rds_storage_size_gb" {
  description = "Allocated storage for RDS (in GB)"
  type        = number
  default     = 20
}

variable "rds_backup_retention_days" {
  description = "RDS backup retention period (days)"
  type        = number
  default     = 7
}

variable "rds_backup_window" {
  description = "RDS backup window"
  type        = string
  default     = "07:00-09:00"
}

variable "rds_encryption_enabled" {
  description = "Enable storage encryption for RDS"
  type        = bool
  default     = false
}

variable "rds_kms_key_id" {
  description = "KMS Key ID for RDS encryption (if applicable)"
  type        = string
  default     = ""
}

variable "existing_rds_endpoint" {
  description = "If you want to reuse an existing RDS instance, provide its endpoint (with port) here"
  type        = string
  default     = ""
}

variable "existing_rds_username" {
  description = "If using an existing RDS instance, provide the username"
  type        = string
  default     = "myadmin"
}

variable "existing_rds_password" {
  description = "If using an existing RDS instance, provide the password"
  type        = string
  default     = "mypassword"
}

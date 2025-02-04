variable "aws_region" {
  type        = string
  default     = "us-west-1"
  description = "AWS region where the EKS cluster will be created"
}

variable "cluster_name" {
  type        = string
  default     = "thirdai-eks"
  description = "Name of the EKS cluster"
}

variable "cluster_version" {
  type        = string
  default     = "1.31"
  description = "Kubernetes version to run on EKS"
}

# Instead of creating a new VPC, we require an existing VPC.
variable "vpc_id" {
  type        = string
  description = "ID of an existing VPC"
}

variable "private_subnets" {
  type        = list(string)
  description = "List of private subnet IDs for the EKS cluster"
}

variable "node_group_desired_capacity" {
  type        = number
  default     = 2
  description = "Desired capacity for the EKS managed node group"
}

variable "node_group_max_capacity" {
  type        = number
  default     = 4
  description = "Maximum capacity for the EKS managed node group"
}

variable "node_group_min_capacity" {
  type        = number
  default     = 1
  description = "Minimum capacity for the EKS managed node group"
}

variable "node_group_instance_types" {
  type        = list(string)
  default     = ["t3.medium"]
  description = "Instance types for the EKS managed node group"
}

# Variable to control whether to create the security group for EFS.
variable "create_thirdai_sg" {
  type        = bool
  default     = true
  description = "Whether to create the security group for EFS mount targets"
}

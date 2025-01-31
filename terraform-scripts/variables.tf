variable "aws_region" {
  type    = string
  default = "us-west-1"
  description = "AWS region where EKS cluster will be created"
}

variable "cluster_name" {
  type    = string
  default = "pratik-eks"
  description = "Name of the EKS cluster"
}

variable "cluster_version" {
  type    = string
  default = "1.31"
  description = "Kubernetes version to run on EKS"
}

variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
  description = "CIDR block for the VPC"
}
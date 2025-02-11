output "eks_cluster_id" {
  description = "The ID of the EKS cluster."
  value       = module.eks.cluster_id
}

output "eks_cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "The endpoint of the EKS cluster."
  value       = module.eks.cluster_endpoint
}

output "efs_file_system_id" {
  description = "The EFS File System ID."
  value       = local.efs_id
}

output "rds_endpoint" {
  description = "The RDS endpoint."
  value       = local.rds_endpoint
}

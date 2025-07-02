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

output "rds_endpoint" {
  description = "The RDS endpoint."
  value       = local.rds_endpoint
}

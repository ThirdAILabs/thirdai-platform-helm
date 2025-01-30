module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  
  enable_cluster_creator_admin_permissions = true


  enable_irsa = true

  # Example cluster addons
  cluster_addons = {
    coredns   = {}
    kube-proxy = {}
    vpc-cni   = {
      version                     = "latest"
      resolve_conflicts           = "OVERWRITE"
      service_account_role_name   = "${var.cluster_name}-vpc-cni-irsa-role"
      service_account_role_policy_arns = [
        "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
      ]
    }
    aws-ebs-csi-driver = {
      service_account_role_name   = "${var.cluster_name}-ebs-csi-irsa-role"
      service_account_role_policy_arns = [
        "arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicy"
      ]
      version = "latest"
    }
    aws-efs-csi-driver = {
      service_account_role_name   = "${var.cluster_name}-efs-csi-irsa-role"
      service_account_role_policy_arns = [
        "arn:aws:iam::aws:policy/AmazonEFSCSIDriverPolicy"
      ]
      version = "latest"
    }
  }

  # Example managed node group
  eks_managed_node_groups = {
    main = {
      name             = "${var.cluster_name}-node-group"
      desired_capacity = 2
      max_capacity     = 4
      min_capacity     = 1

      instance_types = ["t3.medium"]

      additional_tags = {
        "Name" = "${var.cluster_name}-node-group"
      }
    }
  }

  tags = {
    "Project" = var.cluster_name
  }
}

# Grab cluster data so we can configure the Kubernetes provider
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

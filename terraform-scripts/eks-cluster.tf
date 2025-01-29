module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true  # You can keep private access enabled
  cluster_endpoint_public_access_cidrs     = ["0.0.0.0/0"]  # Adjust CIDR for security

  # Enable IRSA for linking AWS IAM policies to K8s service accounts
  enable_irsa = true

  # Define only the add-ons you want to explicitly manage versions/policies for
  cluster_addons = {
    coredns = {
      # optional override for coredns version if desired
    }

    kube-proxy = {
      # optional override for kube-proxy version if desired
    }

    vpc-cni = {
      version                     = "latest"
      resolve_conflicts           = "OVERWRITE"
      service_account_role_name   = "${var.cluster_name}-vpc-cni-irsa-role"
      service_account_role_policy_arns = [
        "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
      ]
    }

    # Corrected EBS CSI Add-On
    aws-ebs-csi-driver = {
      service_account_role_name   = "${var.cluster_name}-ebs-csi-irsa-role"
      service_account_role_policy_arns = [
        "arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicy"
      ]
      version = "latest"  # Or specify a specific version if needed
    }

    # Corrected EFS CSI Add-On
    aws-efs-csi-driver = {
      service_account_role_name   = "${var.cluster_name}-efs-csi-irsa-role"
      service_account_role_policy_arns = [
        "arn:aws:iam::aws:policy/AmazonEFSCSIDriverPolicy"
      ]
      version = "latest"  # Or specify a specific version if needed
    }
  }

  # Node group and other configurations remain unchanged
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

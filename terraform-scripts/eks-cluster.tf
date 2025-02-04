module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnets

  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  enable_cluster_creator_admin_permissions = true

  enable_irsa = true

  cluster_addons = {
    vpc-cni = {
      version           = "latest"
      resolve_conflicts = "OVERWRITE"
    }
    aws-ebs-csi-driver = {
      version = "latest"
    }
    aws-efs-csi-driver = {
      cluster_identity_oidc_issuer     = module.eks.cluster_oidc_issuer_url
      cluster_identity_oidc_issuer_arn = module.eks.oidc_provider_arn
      cluster_name                     = module.eks.cluster_name
      version                          = "latest"
      settings = {
        controller = {
          fsGroupPolicy = "ReadWriteMany"
        }
      }
    }
  }

  eks_managed_node_groups = {
    main = {
      name             = "${var.cluster_name}-node-group"
      desired_capacity = var.node_group_desired_capacity
      max_capacity     = var.node_group_max_capacity
      min_capacity     = var.node_group_min_capacity
      instance_types   = var.node_group_instance_types

      additional_tags = {
        "Name" = "${var.cluster_name}-node-group"
      }

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy          = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
        AmazonEFSCSIDriverPolicy          = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy",
        AmazonElasticFileSystemFullAccess = "arn:aws:iam::aws:policy/AmazonElasticFileSystemFullAccess"
      }
    }
  }

  tags = {
    "Project" = var.cluster_name
  }
}

data "aws_iam_policy_document" "aws_efs_csi_controller_role_trust_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:efs-csi-*"]
    }
  }
}

resource "aws_iam_role" "aws_efs_csi_controller_role" {
  name               = "aws-efs-csi-controller-role-${random_string.unique_suffix.result}"
  assume_role_policy = data.aws_iam_policy_document.aws_efs_csi_controller_role_trust_policy.json
}

resource "aws_iam_role_policy_attachment" "efs_csi_role_policy_attachment" {
  role       = aws_iam_role.aws_efs_csi_controller_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "efs_csi_node_role_policy_attachment" {
  role       = aws_iam_role.aws_efs_csi_controller_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

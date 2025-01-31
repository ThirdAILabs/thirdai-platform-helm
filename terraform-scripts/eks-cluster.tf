module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

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


      version = "latest"
      settings = {
        controller = {
          fsGroupPolicy = "ReadWriteMany"
        }
      }
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

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
        AmazonEFSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
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
  name               = "aws-efs-csi-controller-role"
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


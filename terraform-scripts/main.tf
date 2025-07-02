terraform {
  required_version = ">= 1.3.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.83"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "local" {}

resource "random_string" "unique_suffix" {
  length  = 6
  upper   = false
  special = false
}

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
  enable_irsa                              = true

  cluster_addons = {
    vpc-cni = {
      version           = "latest"
      resolve_conflicts = "OVERWRITE"
    }
    aws-ebs-csi-driver = {
      version = "latest"
    }
  }

  eks_managed_node_groups = {
    main = {
      name           = "${var.cluster_name}-node-group"
      desired_size   = var.node_group_desired_size
      max_size       = var.node_group_max_size
      min_size       = var.node_group_min_size
      instance_types = var.node_group_instance_types

      additional_tags = {
        Name = "${var.cluster_name}-node-group"
      }

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy          = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
        S3AccessPolicy                    = aws_iam_policy.eks_s3_access_policy.arn
      }
    }
  }

  tags = {
    "Project" = var.cluster_name
  }
}

# Allow the EKS worker nodes (which use module.eks.node_security_group_id)
# to communicate with each other on all TCP ports.
resource "aws_security_group_rule" "eks_nodes_allow_all_tcp" {
  description              = "Allow all TCP traffic between worker nodes"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = module.eks.node_security_group_id
  security_group_id        = module.eks.node_security_group_id
}

resource "aws_security_group" "thirdai_platform_sg" {
  name        = "thirdai-platform-sg-${random_string.unique_suffix.result}"
  description = "Security group for RDS access for ThirdAI Platform"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "thirdai-platform-sg-${random_string.unique_suffix.result}"
  }
}

resource "aws_iam_role" "cluster_autoscaler_role" {
  name = "${var.cluster_name}-autoscaler-role-${random_string.unique_suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cluster_autoscaler_policy" {
  name = "${var.cluster_name}-autoscaler-policy-${random_string.unique_suffix.result}"
  role = aws_iam_role.cluster_autoscaler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_db_subnet_group" "rds_subnet" {
  name       = "rds-subnet-group-${random_string.unique_suffix.result}"
  subnet_ids = var.private_subnets

  tags = {
    Name = "RDS Subnet Group ${random_string.unique_suffix.result}"
  }
}

resource "aws_db_instance" "thirdai_platform_db" {
  count                  = var.existing_rds_endpoint != "" ? 0 : 1
  allocated_storage      = var.rds_storage_size_gb
  engine                 = "postgres"
  engine_version         = "14.17"
  instance_class         = var.rds_instance_class
  db_name                = "nerbackend"
  identifier             = "${var.cluster_name}-rds-${random_string.unique_suffix.result}"
  username               = var.rds_master_username
  password               = var.rds_master_password
  vpc_security_group_ids = [aws_security_group.thirdai_platform_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet.name

  publicly_accessible = false
  storage_encrypted   = var.rds_encryption_enabled
  kms_key_id          = var.rds_encryption_enabled && var.rds_kms_key_id != "" ? var.rds_kms_key_id : null

  backup_retention_period = var.rds_backup_retention_days
  backup_window           = var.rds_backup_window

  tags = {
    Name = "${var.cluster_name}-rds"
  }

  skip_final_snapshot       = false
  final_snapshot_identifier = "final-snapshot-${var.cluster_name}-${random_string.unique_suffix.result}"
}

locals {
  rds_endpoint = var.existing_rds_endpoint != "" ? var.existing_rds_endpoint : aws_db_instance.thirdai_platform_db[0].endpoint
  rds_hostname = var.existing_rds_endpoint != "" ? split(":", var.existing_rds_endpoint)[0] : aws_db_instance.thirdai_platform_db[0].address
  rds_port     = var.existing_rds_endpoint != "" ? split(":", var.existing_rds_endpoint)[1] : aws_db_instance.thirdai_platform_db[0].port
  rds_username = var.existing_rds_endpoint != "" ? var.existing_rds_username : var.rds_master_username
  rds_password = var.existing_rds_endpoint != "" ? var.existing_rds_password : var.rds_master_password
}

resource "aws_s3_bucket" "thirdai_platform_bucket" {
  bucket = var.s3_bucket_name

  tags = {
    Name = var.s3_bucket_name
  }
}

resource "aws_iam_policy" "eks_s3_access_policy" {
  name        = "${var.cluster_name}-s3-access-policy"
  description = "Policy to allow EKS cluster to access S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:CreateBucket",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      }
    ]
  })
}

# Attach the s3 bucket access policy to the EKS cluster role
# resource "aws_iam_role_policy_attachment" "eks_worker_s3_access" {
# role       = module.eks.node_groups["main"].iam_role_name
#  policy_arn = aws_iam_policy.eks_s3_access_policy.arn
#}

resource "local_file" "deployment_config" {
  filename = "${path.module}/deployment_config.txt"
  content  = <<EOF
rds_endpoint="${local.rds_endpoint}"
rds_username="${local.rds_username}"
rds_password="${local.rds_password}"
s3_bucket_name="${var.s3_bucket_name}"
aws_region="${var.aws_region}"
database_uri="postgresql://${local.rds_username}:${local.rds_password}@${local.rds_endpoint}/nerbackend"
cluster_autoscaler_role_name="${var.cluster_name}-autoscaler-role-${random_string.unique_suffix.result}"
EOF
}

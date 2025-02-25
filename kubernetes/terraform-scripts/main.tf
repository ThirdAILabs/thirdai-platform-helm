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
        Name = "${var.cluster_name}-node-group"
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
  description = "Security group for RDS and EFS access for ThirdAI Platform"
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
  engine_version         = "14.12"
  instance_class         = var.rds_instance_class
  db_name                = "modelbazaar"
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
  rds_username = var.existing_rds_endpoint != "" ? var.existing_rds_username : var.rds_master_username
  rds_password = var.existing_rds_endpoint != "" ? var.existing_rds_password : var.rds_master_password
}

resource "aws_efs_file_system" "thirdai_platform_efs" {
  count     = var.existing_efs_id != "" ? 0 : 1
  encrypted = var.efs_encryption_enabled

  lifecycle_policy {
    transition_to_ia = var.efs_lifecycle_policy_transition
  }

  performance_mode                = var.efs_performance_mode
  throughput_mode                 = var.efs_throughput_mode
  provisioned_throughput_in_mibps = var.efs_throughput_mode == "provisioned" ? var.efs_provisioned_throughput_mibps : null

  tags = {
    Name = "${var.cluster_name}-efs-${random_string.unique_suffix.result}"
  }

  lifecycle {
    ignore_changes = [
      throughput_mode,
      provisioned_throughput_in_mibps
    ]
  }
}

locals {
  efs_id = var.existing_efs_id != "" ? var.existing_efs_id : aws_efs_file_system.thirdai_platform_efs[0].id
}

resource "aws_efs_mount_target" "thirdai_platform_efs_mt" {
  for_each        = toset(var.private_subnets)
  file_system_id  = local.efs_id
  subnet_id       = each.value
  security_groups = [aws_security_group.thirdai_platform_sg.id]
}

resource "aws_efs_backup_policy" "thirdai_platform_efs_backup" {
  file_system_id = local.efs_id

  backup_policy {
    status = var.efs_backup_enabled ? "ENABLED" : "DISABLED"
  }
}

# TODO(pratik): Use different DB for each of the uri
resource "local_file" "deployment_config" {
  filename = "${path.module}/deployment_config.txt"
  content  = <<EOF
efs_file_system_id="${local.efs_id}"
rds_endpoint="${local.rds_endpoint}"
rds_username="${local.rds_username}"
rds_password="${local.rds_password}"
modelbazaar_db_uri="postgresql://${local.rds_username}:${local.rds_password}@${local.rds_endpoint}/modelbazaar"
keycloak_db_uri="postgresql://${local.rds_endpoint}/modelbazaar"
grafana_db_uri="postgres://${local.rds_username}:${local.rds_password}@${local.rds_endpoint}/modelbazaar?sslmode=require"
EOF
}

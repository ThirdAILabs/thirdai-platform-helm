module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr_block

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    "Project" = var.cluster_name
  }
}

data "aws_availability_zones" "available" {}


resource "aws_security_group" "efs_sg" {
  name        = "efs-sg"
  description = "Security group for EFS mount targets"
  vpc_id      = module.vpc.vpc_id # or your VPC's ID

  tags = {
    Name = "my-efs-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "efs_sg_ingress" {
  security_group_id = aws_security_group.efs_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 0
  ip_protocol = "-1"
  to_port     = 0
}

resource "aws_vpc_security_group_egress_rule" "efs_sg_egress" {
  security_group_id = aws_security_group.efs_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 0
  ip_protocol = "-1"
  to_port     = 0
}

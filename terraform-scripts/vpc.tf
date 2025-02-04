# Conditionally create security group if needed.
resource "aws_security_group" "thirdai_sg" {
  count       = var.create_thirdai_sg ? 1 : 0
  name        = "thirdai-sg-${random_string.unique_suffix.result}"
  description = "Security group for EFS mount targets"
  vpc_id      = var.vpc_id

  tags = {
    Name = "thirdai-sg-${random_string.unique_suffix.result}"
  }
}

resource "aws_vpc_security_group_ingress_rule" "thirdai_sg_ingress" {
  count             = var.create_thirdai_sg ? 1 : 0
  security_group_id = aws_security_group.thirdai_sg[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 0
  ip_protocol       = "-1"
  to_port           = 0
}

resource "aws_vpc_security_group_egress_rule" "thirdai_sg_egress" {
  count             = var.create_thirdai_sg ? 1 : 0
  security_group_id = aws_security_group.thirdai_sg[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 0
  ip_protocol       = "-1"
  to_port           = 0
}

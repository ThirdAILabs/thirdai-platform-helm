aws_region      = "us-west-1"
cluster_name    = "thirdai-eks"
cluster_version = "1.31"

# Supply the ID of an existing VPC (do not create a new one)
vpc_id = "vpc-03e41bd5ac2b8c2e1" # Replace with your VPC ID

# Supply the private subnet IDs in that VPC for the EKS cluster
private_subnets = ["subnet-0d879f0b27b0813e8", "subnet-0a42fc54d043e2156"]

# Node group capacity settings and instance types
node_group_desired_capacity = 1
node_group_max_capacity     = 4
node_group_min_capacity     = 1
node_group_instance_types   = ["t3.medium"]

# Set this to false if you do not want Terraform to create the EFS security group.
create_thirdai_sg = true

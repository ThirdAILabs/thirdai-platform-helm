aws_region      = "us-west-1"
cluster_name    = "thirdai-eks"
cluster_version = "1.31"

# Supply the ID of an existing VPC (do not create a new one)
vpc_id = "vpc-02ab2d4817ddec7b2" # Replace with your VPC ID

# Supply the private subnet IDs in that VPC for the EKS cluster
private_subnets = ["subnet-02ef7f24f8fcbfb4a", "subnet-0b473ae29aa7ab2b6"]

# Node group capacity settings and instance types
node_group_desired_capacity = 2
node_group_max_capacity     = 4
node_group_min_capacity     = 1
node_group_instance_types   = ["c5.large"]

# Set this to false if you do not want Terraform to create the EFS security group.
create_thirdai_sg = true

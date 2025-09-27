region               = "ap-south-1"
cluster_name         = "astroshop-eks-cluster"
cluster_version      = "1.32"
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
public_access_cidrs  = ["0.0.0.0/0"] # This should be Changed to client IP range!

node_groups = {
  general = {
    instance_types = ["m7i-flex.large"]
    capacity_type  = "ON_DEMAND"
    scaling_config = {
      desired_size = 2
      max_size     = 3
      min_size     = 1
    }
  }
  # spot = {
  #   instance_types = ["m7i-flex.large"]
  #   capacity_type  = "SPOT"
  #   scaling_config = {
  #     desired_size = 1
  #     max_size     = 3
  #     min_size     = 0
  #   }
  # }
}

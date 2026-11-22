############################################################
# VPC = your own private network inside AWS
#
# This is a MODULE: a pre-written bundle of resources from the Terraform
# Registry. These ~15 lines create what would be ~150 lines of raw resources:
#   - the VPC itself
#   - 2 public subnets (have a route to the internet gateway)
#   - 2 private subnets (reach the internet only OUTWARD, via NAT)
#   - an Internet Gateway (the VPC's door to the internet)
#   - a NAT Gateway + Elastic IP (lets private servers download things) 
#   - route tables, and the links between subnets and route tables
############################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"   # where the module code comes from (downloaded by `terraform init`)
  version = "~> 5.0"                          # pin the module version, like the provider

  name = "${local.name_prefix}-vpc"
  cidr = var.vpc_cidr           # the VPC's overall IP range
  azs  = local.azs              # which availability zones to spread subnets across

  # One subnet per AZ in each list. The CIDRs are computed in main.tf.
  public_subnets  = local.public_subnet_cidrs    # Jenkins server lives here, and the load balancer
  private_subnets = local.private_subnet_cidrs   # EKS worker nodes live here (not directly reachable from the internet)

  # Private subnets have no direct internet access, but nodes must pull Docker images
  # from Docker Hub. The NAT gateway lets them make outbound connections only.
  enable_nat_gateway = false
  single_nat_gateway = var.single_nat_gateway   # true = one shared NAT (cheaper), false = one per AZ

  enable_dns_hostnames = true   # instances get DNS names. EKS needs this.
  enable_dns_support   = true

  # Kubernetes looks for these tags to decide where to place load balancers.
  #   role/elb          -> internet-facing load balancers go in these subnets
  #   role/internal-elb -> internal-only load balancers go in these subnets
  # Without them, your `type: LoadBalancer` service can't create its public ELB.
  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}
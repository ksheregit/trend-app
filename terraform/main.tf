############################################################
# PROVIDER: which cloud, which region
############################################################

provider "aws" {
  region = var.region # "var.xxx" reads an input variable (defined in variables.tf, filled from terraform.tfvars)

  # default_tags stamps these tags on EVERY resource that supports tags.
  # Result: you never repeat the tags, and in the AWS console you can filter by
  # Project / Environment / Owner, and see exactly what to clean up later.
  default_tags {
    tags = local.common_tags
  }
}

############################################################
# DATA SOURCE: read something that ALREADY exists (creates nothing)
############################################################

# Terraform Asks AWS: "which availability zones are available in my region?"
# In ap-south-1 this returns ap-south-1a, ap-south-1b, ap-south-1c.
# We look them up instead of hardcoding, so the code works in any region.
data "aws_availability_zones" "available" {
  state = "available"
}

############################################################
# LOCALS: named calculations, computed once and reused
# (variables are inputs from outside; locals are values derived inside)
############################################################

locals {
  # "trend-prod". Every resource name starts with this, so everything is easy to identify.
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform" # reminds people NOT to edit these by hand in the console
  }

  # slice(list, start, end) takes the first N zones.
  # With az_count = 2 this gives ["ap-south-1a", "ap-south-1b"].
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # cidrsubnet(parent, extra_bits, number) carves a smaller network out of a bigger one.
  #   cidrsubnet("10.0.0.0/16", 8, 0)   -> 10.0.0.0/24
  #   cidrsubnet("10.0.0.0/16", 8, 1)   -> 10.0.1.0/24
  #   cidrsubnet("10.0.0.0/16", 8, 100) -> 10.0.100.0/24
  # The "for" expression loops once per AZ (0, 1, ...) and builds a list.
  # Private subnets get 10.0.0.0/24, 10.0.1.0/24 ...
  # Public subnets get 10.0.100.0/24, 10.0.101.0/24 ... (+100 keeps them visibly separate)
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  public_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 100)]
}
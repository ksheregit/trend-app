############################################################
# VERSION PINNING: makes the setup repeatable on any machine
############################################################

# terraform {
#   # Refuse to run on a Terraform CLI older than this.
#   # Protects you from "works on my laptop, fails on yours".
#   required_version = ">= 1.5.0"

#   # Providers are plugins that know how to talk to a cloud.
#   # `terraform init` downloads them into the hidden .terraform/ folder.
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"   # who publishes it (registry.terraform.io/hashicorp/aws)
#       version = "~> 5.0"          # "~>" = any 5.x version, but never 6.0.
#                                   # Newer minor versions are fine; a major version can break your code.
#     }
#   }
# }

terraform {
  # Refuse to run on a Terraform CLI older than this.
  # Protects you from "works on my laptop, fails on yours".
  required_version = ">= 1.5.7"   # EKS module v21 needs at least this

  # Providers are plugins that know how to talk to a cloud.
  # `terraform init` downloads them into the hidden .terraform/ folder.
  required_providers {
    aws = {
      source  = "hashicorp/aws"     # who publishes it (registry.terraform.io/hashicorp/aws)
      version = "~> 6.0"            # "~>" = any 5.x version, but never 6.0.
                                    # Newer minor versions are fine; a major version can break your code.
    }
  }
}

# Terraform itself doesn't know how to create AWS resources directly. The AWS provider is the plugin that communicates with AWS APIs.

# For example:
# - Terraform says: Create an EC2 instance.
# - AWS provider translates that into AWS API operations.
# - AWS creates the EC2 instance.
# The source identifies where the provider comes from, and version constrains which versions Terraform can install.
############################################################
# VARIABLES = the inputs of your Terraform "function"
#
# How a variable gets its value (highest priority wins):
#   1. -var on the command line
#   2. terraform.tfvars   <- where YOU set values
#   3. default = ... in this file
# A variable with NO default is REQUIRED: Terraform stops and asks if you forget it.
############################################################

# ---------- General ----------
variable "region" {
  description = "AWS region for all resources" # shown in prompts and docs
  type        = string                         # Terraform rejects the wrong type (e.g. a number)
  # no default -> must be set in terraform.tfvars
}

variable "project_name" {
  description = "Project name, used in resource names and tags"
  type        = string
  default     = "trend"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"

  # validation = a guard rail. If the condition is false, plan stops with your error message.
  # contains(list, value) is true if the value is in the list.
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  description = "Owner tag value (your name or team)"
  type        = string
}

# ---------- Network ----------
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16" # 65,536 private IP addresses

  # can(expr) is true if the expression runs without an error.
  # cidrhost() errors on a malformed CIDR, so this catches typos like "10.0.0/16".
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "az_count" {
  description = "Number of availability zones to use (EKS needs at least 2)"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

# A NAT Gateway allows resources in a private subnet to access the internet (for example, to download software updates)
# without allowing the internet to initiate connections directly to those resources.

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway (cheaper). Set false for one per AZ (high availability)"
  type        = bool # true / false
  default     = true # one NAT costs about a third of three, and fine for this assessment (if this is false then With two Availability Zones, the module would create two NAT Gateways, one per AZ.)
}

# My VPC is configured with two Availability Zones and two private subnets. This variable decides how many NAT Gateways the VPC module creates.
# - true → Create one NAT Gateway shared by the private subnets.
# - false → Create one NAT Gateway per Availability Zone (two in my current setup).
# In my terraform.tfvars, I haven't specified this variable, so Terraform uses its default: true.

# ---------- Access control ----------
variable "admin_cidr_blocks" {
  description = "CIDRs allowed to reach SSH, Prometheus and Grafana (for example [\"203.0.113.10/32\"])"
  type        = list(string) # a list of text values: ["a", "b"]

  # Two safety rules in one: the list can't be empty, and can't contain "the whole internet".
  # This stops you from accidentally opening SSH to everyone.
  validation {
    condition     = length(var.admin_cidr_blocks) > 0 && !contains(var.admin_cidr_blocks, "0.0.0.0/0")
    error_message = "admin_cidr_blocks must not be empty and must not include 0.0.0.0/0."
  }
}

variable "jenkins_ui_cidr_blocks" {
  description = "CIDRs allowed to reach the Jenkins UI on 8080. GitHub webhooks need public access, so tighten this to GitHub hook IP ranges if you can"
  type        = list(string)
  default     = ["0.0.0.0/0"] # open, because GitHub's servers must be able to call your webhook
}

# ---------- Jenkins server ----------
variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH"
  type        = string
  # just the NAME as shown in AWS, not a file path and without ".pem"
}

variable "jenkins_ami_id" {
  description = "AMI ID of your Jenkins and monitoring image (must exist in var.region)"
  type        = string

  # regex() matches a pattern. This checks the value looks like ami-0123abcd...
  validation {
    condition     = can(regex("^ami-[0-9a-f]{8,17}$", var.jenkins_ami_id))
    error_message = "jenkins_ami_id must look like ami-0123456789abcdef0."
  }
}

variable "jenkins_instance_type" {
  description = "EC2 instance type for the Jenkins and monitoring server"
  type        = string
  default     = "t3.medium" # 2 vCPU, 4 GiB RAM. Jenkins + Prometheus + Grafana need this much.
}

variable "jenkins_root_volume_size" {
  description = "Root volume size in GiB for the Jenkins server"
  type        = number
  default     = 30
}

variable "jenkins_ssh_port" {
  description = "SSH port"
  type        = number
  default     = 22
}

# ---------- EKS ----------
variable "eks_cluster_name" {
  description = "Name of the EKS cluster (the Jenkinsfile must use the same name)"
  type        = string
  default     = "trend-cluster"
}

variable "eks_cluster_version" {
  description = "Kubernetes version. null uses the current EKS default"
  type        = string
  default     = null # null = "not set", so the EKS module picks its own default
}

variable "eks_node_instance_types" {
  description = "Instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "eks_node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "eks_node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2

  validation {
    condition     = var.eks_node_desired_size >= 1
    error_message = "eks_node_desired_size must be at least 1."
  }
}
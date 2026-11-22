File	            Responsibility
=====================================================================
versions.tf	        Terraform and provider requirements
main.tf	            AWS provider, data sources and local calculations
variables.tf	    Declares all input variables
terraform.tfvars	Supplies actual input values
vpc.tf	            Creates VPC and networking
iam.tf	            Creates IAM roles and permissions
ec2.tf	            Creates Jenkins EC2 and security group
eks.tf	            Creates EKS cluster and worker nodes
outputs.tf	        Displays useful information after provisioning


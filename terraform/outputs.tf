############################################################
# OUTPUTS = values Terraform prints after `apply`
#
# Why they matter:
#  1. You get the Jenkins IP, URLs and commands without hunting in the AWS console.
#  2. Other Terraform code or scripts can read them: `terraform output -raw jenkins_url`
#  3. Many outputs read attributes AWS decides at creation time (like the public IP),
#     which you couldn't know in advance.
# See them any time with:  terraform output
############################################################

# ---------- Network ----------
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id   # modules expose their own outputs as module.<name>.<output>
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "nat_public_ips" {
  description = "NAT gateway public IPs (outbound traffic from private subnets)"
  value       = module.vpc.nat_public_ips   # handy if an external service needs to allow-list your cluster
}

# ---------- Jenkins server ----------
output "jenkins_instance_id" {
  description = "Jenkins EC2 instance ID"
  value       = aws_instance.jenkins.id
}

output "jenkins_public_ip" {
  description = "Jenkins server public IP"
  value       = aws_eip.jenkins.public_ip   # "known after apply": AWS assigns it
}

output "jenkins_security_group_id" {
  description = "Jenkins security group ID"
  value       = aws_security_group.jenkins.id
}

output "jenkins_role_arn" {
  description = "IAM role ARN attached to the Jenkins server"
  value       = aws_iam_role.jenkins.arn
}

output "jenkins_url" {
  description = "Jenkins UI"
  value       = "http://${aws_eip.jenkins.public_ip}:8080"   # ${...} builds a string from values
}

output "jenkins_webhook_url" {
  description = "Use this as the GitHub webhook payload URL"
  value       = "http://${aws_eip.jenkins.public_ip}:8080/github-webhook/"   # paste into GitHub -> Settings -> Webhooks
}

output "grafana_url" {
  description = "Grafana UI"
  value       = "http://${aws_eip.jenkins.public_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus UI"
  value       = "http://${aws_eip.jenkins.public_ip}:9090"
}

output "ssh_command" {
  description = "SSH into the Jenkins server (replace the key path)"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${aws_eip.jenkins.public_ip}"
  # ec2-user is the default login on Amazon Linux AMIs. If your AMI is Ubuntu it would be "ubuntu".
}


############################################################
# SECURITY GROUP = a virtual firewall attached to the server
############################################################

# The empty "box". Rules are added to it separately below.
resource "aws_security_group" "jenkins" {
  name        = "${local.name_prefix}-jenkins-sg" # "trend-prod-jenkins-sg": local.name_prefix is built in main.tf
  description = "Jenkins and monitoring server"
  vpc_id      = module.vpc.vpc_id # REFERENCE: use the VPC from vpc.tf, so Terraform builds the VPC first

  tags = { Name = "${local.name_prefix}-jenkins-sg" } # "Name" is the label you see in the AWS console
}

############################################################
# INGRESS RULES = who may connect IN (inbound traffic)
############################################################

# One rule per port. Each answers: "from which IPs, to which port?"
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  # for_each makes one copy of this rule per item in the list.
  # With admin_cidr_blocks = ["106.219.182.49/32"] you get 1 rule.
  # Add a second IP to the list later and you get 2 rules, with no code change.
  # toset() converts the list to a "set", which for_each requires.
  for_each = toset(var.admin_cidr_blocks)

  security_group_id = aws_security_group.jenkins.id # attach this rule to the group above
  description       = "SSH from admin"              # shows up in the console, so make it readable
  cidr_ipv4         = each.value                    # each.value = the current IP in the loop
  from_port         = var.jenkins_ssh_port          # port range start...
  to_port           = var.jenkins_ssh_port          # ...and end. Same number = a single port
  ip_protocol       = "tcp"
}

# Same pattern for Prometheus (9090). Only YOUR IP can open the metrics UI.
resource "aws_vpc_security_group_ingress_rule" "prometheus" {
  for_each          = toset(var.admin_cidr_blocks)
  security_group_id = aws_security_group.jenkins.id
  description       = "Prometheus from admin"
  cidr_ipv4         = each.value
  from_port         = 9090
  to_port           = 9090
  ip_protocol       = "tcp"
}

# Same pattern for Grafana (3000). Only YOUR IP.
resource "aws_vpc_security_group_ingress_rule" "grafana" {
  for_each          = toset(var.admin_cidr_blocks)
  security_group_id = aws_security_group.jenkins.id
  description       = "Grafana from admin"
  cidr_ipv4         = each.value
  from_port         = 3000
  to_port           = 3000
  ip_protocol       = "tcp"
}

# Jenkins UI (8080) uses a DIFFERENT variable, because GitHub's servers must reach it
# to deliver webhooks. GitHub isn't on your IP, so the default is open to the world (0.0.0.0/0).
# This is the one deliberately wide rule. Jenkins' own login still protects it.
resource "aws_vpc_security_group_ingress_rule" "jenkins_ui" {
  for_each          = toset(var.jenkins_ui_cidr_blocks)
  security_group_id = aws_security_group.jenkins.id
  description       = "Jenkins UI and GitHub webhook"
  cidr_ipv4         = each.value
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

############################################################
# EGRESS RULE = where the server may connect OUT to
############################################################

# Jenkins must pull code from GitHub, push images to Docker Hub, and call the EKS API.
# So all outbound traffic is allowed. ip_protocol "-1" means "every protocol".
# Security groups are STATEFUL: replies to allowed inbound connections are always let back out.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.jenkins.id
  description       = "Allow all outbound"
  cidr_ipv4         = "0.0.0.0/0" # 0.0.0.0/0 = "the whole internet"
  ip_protocol       = "-1"
}

############################################################
# THE SERVER ITSELF
############################################################

resource "aws_instance" "jenkins" {
  ami           = var.jenkins_ami_id        # the machine image. Your Jenkins + Prometheus + Grafana snapshot
  instance_type = var.jenkins_instance_type # CPU/RAM size ("t3.medium" = 2 vCPU, 4 GiB)

  # PUBLIC subnet (index [0] = the first one) so the server gets an internet-reachable IP.
  # The worker nodes live in PRIVATE subnets; this server doesn't.
  subnet_id = module.vpc.public_subnets[0]

  vpc_security_group_ids = [aws_security_group.jenkins.id] # attach the firewall. It's a list, hence the [ ]
  key_name               = var.key_name                    # AWS key pair NAME (not a file path) for SSH
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name
  # ^ gives the server an AWS identity (defined in iam.tf), so Jenkins can call
  #   "aws eks ..." with no access keys stored on the machine

  # IMDS = the internal service where a server asks "who am I? what are my credentials?"
  # IMDSv2 requires a session token, which blocks a class of attacks where a
  # vulnerable web app is tricked into leaking the server's credentials.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # "required" = IMDSv2 only
  }

  root_block_device {
    volume_size = var.jenkins_root_volume_size # disk size in GiB (30)
    volume_type = "gp3"                        # current-generation SSD, cheaper than gp2
    encrypted   = true                         # disk encrypted at rest
  }

  tags = { Name = "${local.name_prefix}-jenkins" }
}
# ELASTIC IP = a fixed public address for the Jenkins server
resource "aws_eip" "jenkins" {
  instance = aws_instance.jenkins.id
  domain   = "vpc"

  tags = { Name = "${local.name_prefix}-jenkins-eip" }
}

############################################################
# IAM = "who is allowed to do what in AWS"
#
# The goal: let the Jenkins server run `aws eks update-kubeconfig` WITHOUT
# storing any access keys on the machine. The server gets an identity instead.
#
# The chain is:  Role (an identity)  ->  Policies (its permissions)
#                Instance profile (the "plug" that attaches the role to an EC2)
############################################################

# The ROLE: an identity that something can temporarily "wear".
resource "aws_iam_role" "jenkins" {
  name = "${local.name_prefix}-jenkins-role"

  # The TRUST policy answers: "WHO is allowed to wear this role?"
  # Here: the EC2 service ("ec2.amazonaws.com"). Without this, no server could use the role.
  # jsonencode() converts the HCL object into the JSON text AWS expects.
  assume_role_policy = jsonencode({
    Version = "2012-10-17" # the IAM policy language version, always this value
    Statement = [{
      Action    = "sts:AssumeRole" # "assume (wear) this role"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# A PERMISSION policy answers: "WHAT may the role do?"
# Inline policy = written directly onto this one role.
resource "aws_iam_role_policy" "eks_describe" {
  name = "${local.name_prefix}-eks-describe"
  role = aws_iam_role.jenkins.id # attach to the role above

  # Only 2 read-only EKS actions. `aws eks update-kubeconfig` needs DescribeCluster to
  # fetch the cluster's address and certificate. Least privilege: no create or delete rights.
  # (What Jenkins may do INSIDE Kubernetes is controlled separately, by the access entry in eks.tf.)
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

# Optional extra: a managed policy (written and maintained by AWS) that enables
# Session Manager, so you can open a shell from the AWS console without SSH or open ports.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2 can't use a role directly. It needs an INSTANCE PROFILE, a wrapper around the role.
# ec2.tf references this profile.
resource "aws_iam_instance_profile" "jenkins" {
  name = "${local.name_prefix}-jenkins-profile"
  role = aws_iam_role.jenkins.name
}
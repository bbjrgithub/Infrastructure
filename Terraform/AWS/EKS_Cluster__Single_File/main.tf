#---------------------------------------------------------------
#
# Simple EKS cluster setup with all resources declared in a
# single file with a minimal variable file
#
#---------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "random_string" "eks_cluster_name_suffix" {
  length  = 16
  special = false
}

locals {
  eks_cluster_name = "${var.eks_cluster_name}-${random_string.eks_cluster_name_suffix.result}"
}

# Filter out Local Zones, which are currently not supported
# With Managed NodeGroups
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

resource "aws_vpc" "cluster_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    "Name" = "Cluster VPC"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.cluster_vpc.id

  tags = {
    "Name" = "igw"
  }
}

# Public subnets
resource "aws_subnet" "public_az1" {
  vpc_id                  = aws_vpc.cluster_vpc.id
  cidr_block              = "10.0.1.0/28"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = {
    "Name"                                            = "public_az1"
    "kubernetes.io/role/elb"                          = "1"
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "owned"
  }

}

resource "aws_subnet" "public_az2" {
  vpc_id                  = aws_vpc.cluster_vpc.id
  cidr_block              = "10.0.2.0/28"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = {
    "Name"                                            = "public_az2"
    "kubernetes.io/role/elb"                          = "1"
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "owned"
  }

}

# Private subnets
resource "aws_subnet" "private_az1" {
  vpc_id            = aws_vpc.cluster_vpc.id
  cidr_block        = "10.0.4.0/22"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    "Name"                                            = "private_az1"
    "kubernetes.io/role/internal-elb"                 = "1"
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "owned"
  }

}

resource "aws_subnet" "private_az2" {
  vpc_id            = aws_vpc.cluster_vpc.id
  cidr_block        = "10.0.8.0/22"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    "Name"                                           = "private_az2"
    "kubernetes.io/role/internal-elb"                = "1"
    "kubernetes.io/cluster${local.eks_cluster_name}" = "owned"
  }
}

# NAT Gateway and Elastic IP for Private subnets
resource "aws_eip" "nat" {
  tags = {
    "Name" = "nat"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_az1.id

  tags = {
    "Name" = "nat"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Public and private route tables for subnets and route table associations
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.cluster_vpc.id

  tags = {
    "Name" = "public"
  }
}

resource "aws_route" "public_route" {
  gateway_id             = aws_internet_gateway.igw.id
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.cluster_vpc.id

  tags = {
    "Name" = "private"
  }
}

resource "aws_route" "private_route" {
  gateway_id             = aws_nat_gateway.nat.id
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
}


resource "aws_route_table_association" "public_az1" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_az1.id
}

resource "aws_route_table_association" "public_az2" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_az2.id
}

resource "aws_route_table_association" "private_az1" {
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private_az1.id
}

resource "aws_route_table_association" "private_az2" {
  route_table_id = aws_route_table.private.id
  subnet_id      = aws_subnet.private_az1.id
}

# EKS Cluster Role and cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "eks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name

}

resource "aws_eks_cluster" "eks_cluster" {
  name     = local.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  vpc_config {
    subnet_ids = [
      aws_subnet.private_az1.id,
      aws_subnet.private_az2.id,
      aws_subnet.public_az1.id,
      aws_subnet.public_az2.id
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.AmazonEKSClusterPolicy]
}

# Node Role
resource "aws_iam_role" "nodes" {
  name = "eks_nodegroup_nodes"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]

    Version = "2012-10-17"
  })
}

# IAM Policy with minimal permissions for System Manager Session Manager access to
# Nodes
# https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-create-iam-instance-profile.html

resource "aws_iam_policy" "ssm_session_manager" {
  name = "ssm_session_manager"
  policy = jsonencode({
    Version = "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        "Resource" : "*"
      }
    ]
  })
}

# Policies for Node Role
resource "aws_iam_role_policy_attachment" "nodes-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes-ssm_session_manager" {
  policy_arn = aws_iam_policy.ssm_session_manager.arn
  role       = aws_iam_role.nodes.name

}

resource "aws_iam_instance_profile" "nodes_instance_profile" {
  depends_on = [aws_iam_role.nodes]
  name       = "worker_nodes_instance_profile"
  role       = aws_iam_role.nodes.name
}

resource "aws_eks_node_group" "private_worker_nodes" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "private_worker_nodes"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids = [
    aws_subnet.private_az1.id,
    aws_subnet.private_az2.id
  ]
  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 0
  }

  capacity_type  = "ON_DEMAND"
  instance_types = ["${var.eks_node_type}"]

  update_config {
    max_unavailable = 1
  }

  labels = {
    "role" = "Dev"
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.nodes-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.nodes-AmazonEC2ContainerRegistryReadOnly
  ]
}

# IAM OIDC Provider
data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer

}

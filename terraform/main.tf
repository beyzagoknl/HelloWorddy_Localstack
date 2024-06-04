locals {
  availability_zones = ["us-west-2a", "us-west-2b"]
}

provider "aws" {
  access_key = var.use_localstack ? "LKIAQAAAAAAAHFCVUJVW" : var.aws_access_key
  secret_key = var.use_localstack ? "SiQEWV/O5tlMm9EugZ7PYVtLdsHDZnf/S59DSaud" : var.aws_secret_key
  region     = var.aws_region

  skip_credentials_validation = var.use_localstack ? true : false
  skip_metadata_api_check     = var.use_localstack ? true : false
  skip_requesting_account_id  = var.use_localstack ? true : false

  endpoints {
    eks = var.use_localstack ? var.localstack_endpoint : null
    ec2 = var.use_localstack ? var.localstack_endpoint : null
    ecr = var.use_localstack ? var.localstack_endpoint : null
    iam = var.use_localstack ? var.localstack_endpoint : null
  }
}

resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "eks_subnet" {
  count             = 2
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = element(local.availability_zones, count.index)
}

resource "aws_ecr_repository" "hello_world_repo" {
  name = "hello-world-repo-unique"
}

resource "aws_iam_role" "eks_role" {
  name = "eks-role-unique"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_policy_attachment" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "new_cluster" {
  name     = "new-cluster"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = aws_subnet.eks_subnet[*].id
  }
}

resource "aws_iam_role" "node_group_role" {
  name = "node-group-role-unique"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "node_group_policy_attachment" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_eks_node_group" "worker_nodes" {
  cluster_name    = aws_eks_cluster.new_cluster.name
  node_group_name = "new-node-group"
  node_role_arn   = aws_iam_role.node_group_role.arn
  subnet_ids      = aws_subnet.eks_subnet[*].id

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }
}

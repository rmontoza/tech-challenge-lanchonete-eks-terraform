provider "aws" {
  region = "us-east-1" # Defina a região
}

provider "kubernetes" {
  host                   = aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.eks_auth.token
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.eks_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.eks_auth.token
  }
}

data "aws_eks_cluster" "eks_cluster" {
  name = aws_eks_cluster.eks_cluster.name
}

data "aws_eks_cluster_auth" "eks_auth" {
  name = aws_eks_cluster.eks_cluster.name
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = "lanhonete-eks-cluster"
  role_arn = aws_iam_role.eks_role.arn

  version = "1.29"  # Especificar a versão do Kubernetes que você deseja usar

  vpc_config {
    subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  }
}

resource "aws_iam_role" "eks_role" {
  name = "lanchonete_eks_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_role_attachment" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_vpc_attachment" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

resource "aws_vpc" "main_vpc" {
  cidr_block = "172.31.0.0/16"
}

resource "aws_subnet" "public_a" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "172.31.0.0/20"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true # Garantir que IPs públicos sejam atribuídos
}

resource "aws_subnet" "public_b" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "172.31.80.0/20"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true # Garantir que IPs públicos sejam atribuídos
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_a_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_b_assoc" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "lanchonete-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
}

resource "aws_iam_role" "eks_node_role" {
  name = "lanchonete_eks_node_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_policy_attachment" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy_attachment" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "registry_policy_attachment" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Profile configuration
provider "aws" {
  shared_config_files      = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = var.profile
}

# Create VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Eks-vpc"
    Env = "Development"
  }
}
# Create Internet Gateway
resource "aws_internet_gateway" "prod_gw" {
  vpc_id = aws_vpc.prod-vpc.id
  tags = {
    Name = "Eks-gateway"
    Env = "Development"
  }

}
# Create Custom Route Table
resource "aws_route_table" "ProdRouteTable" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod_gw.id
  }
  tags = {
    Name = "Eks-RouteTable"
    Env = "Development"
  }
}
# Create a Subnet
resource "aws_subnet" "public1" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "ap-northeast-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Eks-Public-1"
    Env = "Development"
  }
}

resource "aws_subnet" "public2" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-1c"
  map_public_ip_on_launch = true
  tags = {
    Name = "Eks-Public-2"
    Env = "Development"
  }
}

# Create Associate Subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.ProdRouteTable.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.ProdRouteTable.id
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks-role" {
  name               = "eks-cluster"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags = {
    Name = "Eks-cicd-role"
    Env = "Development"
  }
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks-role.name
}

resource "aws_eks_cluster" "eks" {
  name     = "my-eks"
  role_arn = aws_iam_role.eks-role.arn

  vpc_config {
    subnet_ids = [aws_subnet.public1.id, aws_subnet.public2.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSVPCResourceController,
  ]
}
resource "aws_iam_role" "node-group" {
  name = "eks-node-group"

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

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node-group.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node-group.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node-group.name
}

resource "aws_eks_node_group" "node-group" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "my-node-group"
  node_role_arn   = aws_iam_role.node-group.arn
  subnet_ids      = [aws_subnet.public1.id, aws_subnet.public2.id]

  scaling_config {
    desired_size = 3
    max_size     = 5
    min_size     = 1
  }
  instance_types = ["t3.medium"]

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
  tags = {
    Name = "Eks-cicd-jenkins"
    Env = "Development"
  }
}

#Output

output "endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

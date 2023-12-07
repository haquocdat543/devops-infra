terraform {
  backend "s3" {
    bucket         = "<your-bucket-name>"
    key            = "Jenkins/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = "true"
    role_arn       = "<your-role-arn>"
    dynamodb_table = "<your-dynamodb-table-name>"
  }
}

# Profile configuration
provider "aws" {
  shared_config_files      = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = var.profile
}

# Create VPC
resource "aws_vpc" "jenkins-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Cicd-vpc"
    Env = "Development"
  }
}
# Create Internet Gateway
resource "aws_internet_gateway" "jenkins_gw" {
  vpc_id = aws_vpc.jenkins-vpc.id

  tags = {
    Name = "Cicd-gateway"
    Env = "Development"
  }
}
# Create Custom Route Table
resource "aws_route_table" "ProdRouteTable" {
  vpc_id = aws_vpc.jenkins-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jenkins_gw.id
  }
  tags = {
    Name = "Cicd-RouteTable"
    Env = "Development"
  }
}
# Create a Subnet
resource "aws_subnet" "JenkinsSubnet" {
  vpc_id            = aws_vpc.jenkins-vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "Cicd-JenkinsSubnet"
    Env = "Development"
  }
}
# Create Associate Subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.JenkinsSubnet.id
  route_table_id = aws_route_table.ProdRouteTable.id
}
# Create Security Group to allow port 22, 80, 443
resource "aws_security_group" "JenkinsSecurityGroup" {
  name        = "JenkinsSecurityGroup"
  description = "Allow SSH ,HTTPS , Jenkins, Sonarqube, React"
  vpc_id      = aws_vpc.jenkins-vpc.id

  ingress = [
    for port in [22, 80, 443, 8080, 9000] : {
      description      = "TLS from VPC"
      from_port        = port
      to_port          = port
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Jenkin-SG"
    Env = "Development"
  }
}
# Create a network interface with an ip in the subnet that was created step 4
resource "aws_network_interface" "Jenkins-Server" {
  subnet_id       = aws_subnet.JenkinsSubnet.id
  private_ips     = ["10.0.0.51"]
  security_groups = [aws_security_group.JenkinsSecurityGroup.id]
  tags = {
    Name = "Jenkin-Server"
    Env = "Development"
  }
}

resource "aws_network_interface" "Jenkins-Agent" {
  subnet_id       = aws_subnet.JenkinsSubnet.id
  private_ips     = ["10.0.0.52"]
  security_groups = [aws_security_group.JenkinsSecurityGroup.id]
  tags = {
    Name = "Jenkin-Agent"
    Env = "Development"
  }
}

resource "aws_network_interface" "Sonarqube-Server" {
  subnet_id       = aws_subnet.JenkinsSubnet.id
  private_ips     = ["10.0.0.53"]
  security_groups = [aws_security_group.JenkinsSecurityGroup.id]
  tags = {
    Name = "Sonarqube-Server"
    Env = "Development"
  }
}

# Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "Jenkins-Server" {
  domain                    = "vpc"
}

resource "aws_eip" "Jenkins-Agent" {
  domain                    = "vpc"
}

resource "aws_eip" "Sonarqube-Server" {
  domain                    = "vpc"
}

# Associate EIP to EC2 instances ENI

resource "aws_eip_association" "eip_assoc_to_Jenkins-Server" {
  instance_id   = aws_instance.Jenkins-Server.id
  allocation_id = aws_eip.Jenkins-Server.id
}

resource "aws_eip_association" "eip_assoc_to_Jenkins-Agent" {
  instance_id   = aws_instance.Jenkins-Agent.id
  allocation_id = aws_eip.Jenkins-Agent.id
}

resource "aws_eip_association" "eip_assoc_to_Sonarqube-Server" {
  instance_id   = aws_instance.Sonarqube-Server.id
  allocation_id = aws_eip.Sonarqube-Server.id
}

resource "aws_instance" "Jenkins-Server" {
  ami               = var.ami_id
  instance_type     = "t2.micro"
  availability_zone = "ap-northeast-1a"
  key_name          = var.key_pair
  user_data         = file("./scripts/jenkins-master.sh")
  root_block_device {
    volume_size = 15
    volume_type = "gp3"
    encrypted   = true
    tags	= {
	    "Name" = "Jenkins-Server"
	    "Env" = "Dev"
	}
  }
}

resource "aws_instance" "Jenkins-Agent" {
  ami               = var.ami_id
  instance_type     = "t3.medium"
  availability_zone = "ap-northeast-1a"
  key_name          = var.key_pair
  user_data         = file("./scripts/jenkins-agent.sh")
  root_block_device {
    volume_size = 15
    volume_type = "gp3"
    encrypted   = true
    tags	= {
	    "Name" = "Jenkins-Agent"
	    "Env" = "Dev"
	}
  }
}

resource "aws_instance" "Sonarqube-Server" {
  ami               = var.ami_id
  instance_type     = "t3.medium"
  availability_zone = "ap-northeast-1a"
  key_name          = var.key_pair
  user_data         = file("./scripts/sonarqube.sh")
  root_block_device {
    volume_size = 15
    volume_type = "gp3"
    encrypted   = true
    tags	= {
	    "Name" = "Sonarqube-Server"
	    "Env" = "Dev"
	}
  }
}
#Output
output "Jenkins-Server" {
  value = "ssh -i ~/${var.key_pair}.pem ubuntu@${aws_eip.Jenkins-Server.public_ip}"
}
output "Jenkins-Agent" {
  value = "ssh -i ~/${var.key_pair}.pem ubuntu@${aws_eip.Jenkins-Agent.public_ip}"
}
output "Sonarqube-Server" {
  value = "ssh -i ~/${var.key_pair}.pem ubuntu@${aws_eip.Sonarqube-Server.public_ip}"
}

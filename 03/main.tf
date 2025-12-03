terraform {
    required_providers {
      aws={
        source = "hashicorp/aws"
        version = "~> 5.0"
      }
    }
}

provider "aws" {
    region = "ap-south-1"  
}

resource "aws_vpc" "Test_VPC" {
  cidr_block = "10.0.0.0/20"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name = "Learninng_VPC"
  }
}

resource "aws_internet_gateway" "Testing_IGW" {
  vpc_id = aws_vpc.Test_VPC.id
  tags = {
    Name = "Learning_IGW"
  }
}


resource "aws_subnet" "public_SN" {
    for_each = {
        a={
            az = "ap-south-1a"
            cidr = "10.0.0.0/24"
        }
        b={
            az = "ap-south-1b"
            cidr = "10.0.1.0/24"
        }
    }
    vpc_id = aws_vpc.Test_VPC.id
    cidr_block = each.value.cidr
    availability_zone = each.value.az
    map_public_ip_on_launch = true
    tags = {
        Name = "Learning_Subnet_${each.key}"
        }
}

resource "aws_subnet" "private_SN" {
    for_each = {
        a={
            az="ap-south-1a"
            cidr="10.0.3.0/24"
        }
        b={
            az="ap-south-1b"
            cidr="10.0.4.0/24"            
        }
    }
    vpc_id = aws_vpc.Test_VPC.id
    cidr_block = each.value.cidr
    availability_zone = each.value.az
    tags = {
        Name = "Learning_Subnet_${each.key}" 
    }
}    


resource "aws_route_table" "Public_RT" {
  vpc_id = aws_vpc.Test_VPC.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Testing_IGW.id
  }
  tags = {
    Name = "Learning_Public_RT"
  }
}

resource "aws_route_table_association" "public_assoc" {
    for_each = aws_subnet.public_SN
    subnet_id = each.value.id
    route_table_id = aws_route_table.Public_RT.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
    allocation_id = aws_eip.nat_eip.id
    subnet_id = aws_subnet.public_SN["a"].id
    tags = {
        Name = "Learning_NAT_GW"
    }
    depends_on = [ aws_internet_gateway.Testing_IGW ]
}

resource "aws_route_table" "Learning_Private_RT" {
    vpc_id = aws_vpc.Test_VPC.id
    route  {
        cidr_block = "10.0.0.0/24"
        nat_gateway_id = aws_nat_gateway.nat.id
    }
    tags = {
        Name = "Learning_Private_RT"
    }
}

resource "aws_route_table_association" "private_assoc" {
    for_each = aws_subnet.private_SN
    subnet_id = each.value.id
    route_table_id = aws_route_table.Learning_Private_RT.id
}

resource "aws_security_group" "public_SG" {
    vpc_id = aws_vpc.Test_VPC.id
    name = "Learning_Public_SG"
    description = "Allow SSH and HTTP inbound traffic"

    ingress {
        description = "SSH from anywhere"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress  {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "Learning_Public_SG"
    }  
}

resource "aws_security_group" "private_SG" {
    vpc_id = aws_vpc.Test_VPC.id
    name = "Learning_Private_SG"
    description = "Allow HTTP from Public_SG"

    ingress  {
        description = "SSh from public_SG"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        security_groups= [aws_security_group.public_SG.id]
}
    egress  {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "Learning_Private_SG"
    }
}

resource "aws_instance" "public" {
    for_each = aws_subnet.public_SN
    ami="ami-02b8269d5e85954ef"
    instance_type = "t2.nano"
    subnet_id = each.value.id
    vpc_security_group_ids = [aws_security_group.public_SG.id]
    key_name = var.key_name

    associate_public_ip_address = true

    tags = {
      Name="public-ec2-${each.key}"
    }
}
resource "aws_instance" "private" {
  for_each = aws_subnet.private_SN

  ami                    = "ami-02b8269d5e85954ef"
  instance_type          = "t2.nano"
  subnet_id              = each.value.id
  vpc_security_group_ids = [aws_security_group.private_SG.id]
  key_name               = var.key_name

  tags = {
    Name = "private-ec2-${each.key}"
  }
}
variable "key_name" {
  description = "Test_key"
  type        = string
}

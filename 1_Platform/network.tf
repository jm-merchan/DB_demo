# Deploy VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.aws_vpc_cidr

  tags = {
    Name = "Boundary DB MGMT Demo"
  }
  # Enabling DNS name so they can be used in some configurations
  enable_dns_hostnames = true
}

# Deploy Internet Gateway
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "Boundary DB MGMT Demo"
  }
}

# Deploy 2 Public Subnets
resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "1public-ddbb"
  }
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "2public-ddbb"
  }
}

# Deploy 2 Private Subnets
resource "aws_subnet" "private1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = false

  tags = {
    Name = "1private-ddbb"
  }
}

resource "aws_subnet" "private2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "eu-west-2b"
  map_public_ip_on_launch = false

  tags = {
    Name = "2private-ddbb"
  }
}
# Deploy Route Table
resource "aws_route_table" "rt-public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }
  # Route traffic to the HVN peering connection
  route {
    cidr_block                = var.hvn_cidr
    vpc_peering_connection_id = hcp_aws_network_peering.peer.provider_peering_id
  }

  tags = {
    Name = "Internet and HVN routes"
  }
}

resource "aws_route_table" "rt-private" {
  vpc_id = aws_vpc.vpc.id

  # Route traffic to the HVN peering connection
  route {
    cidr_block                = var.hvn_cidr
    vpc_peering_connection_id = hcp_aws_network_peering.peer.provider_peering_id
  }

  tags = {
    Name = "HVN routes"
  }
}

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.rt-public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.rt-public.id
}

resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.rt-private.id
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.rt-private.id
}

data "http" "current" {
  url = "https://ifconfig.me/ip"
}
/*
# Associate Subnets With Route Table
resource "aws_route_table_association" "route1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "route2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.rt.id
}
*/

# Deploy Security Groups
resource "aws_security_group" "publicsg" {
  name        = "Worker Security Group"
  description = "Boundary DB MGMT Demo"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${data.http.current.response_body}/32"]
  }

  ingress {
    from_port   = 9200
    to_port     = 9202
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
}

resource "aws_security_group" "privatesg" {
  name        = "Private Subnet Endpoints"
  description = "Boundary DB MGMT Demo"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.aws_vpc_cidr, var.hvn_cidr]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.publicsg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
}

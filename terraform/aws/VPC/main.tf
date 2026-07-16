resource "aws_vpc" "primary_vpc" {
  cidr_block       = "10.0.0.0/16"
  provider = aws.primary
  enable_dns_hostnames = true
  enable_dns_support = true
  instance_tenancy = "default"

  tags = {
    Name = "primary_vpc"
    deployment = "dev"
  }
}

resource "aws_vpc" "secondary_vpc" {
  cidr_block       = "10.0.0.0/16"
  provider = aws.secondary
  enable_dns_hostnames = true
  enable_dns_support = true
  instance_tenancy = "default"

  tags = {
    Name = "secondary_vpc"
    deployment = "dev"
  }
}

resource "aws_subnet" "primary_subnet" {
  provider = aws.primary
  vpc_id     = aws_vpc.primary_vpc.id
  cidr_block = var.primary_vpc_cidr
  availability_zone = data.aws_availability_zones.primary.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name  = "Primary-Subnet-${var.primary_region}"
    Environment = "Demo"
  }
}

resource "aws_subnet" "secondary_subnet" {
  provider = aws.secondary
  vpc_id     = aws_vpc.secondary_vpc.id
  cidr_block = var.secondary_vpc_cidr
  availability_zone = data.aws_availability_zones.secondary.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name  = "secondary-Subnet-${var.secondary_region}"
    Environment = "Demo"
  }
}

resource "aws_internet_gateway" "primary_igw" {
  vpc_id = aws_vpc.primary_vpc.id
  provider = aws.primary

  tags = {
    Name = "Primary-igw-${var.primary_region}"
    Environment = "Demo"
  }
}

resource "aws_internet_gateway" "secondary_igw" {
  vpc_id = aws_vpc.secondary_vpc.id
  provider = aws.secondary
  tags = {
    Name = "secondary-igw-${var.secondary_region}"
    Environment = "Demo"
  }
}

resource "aws_route_table" "primary_rt" {
  vpc_id = aws_vpc.primary_vpc.id
  provider = aws.primary

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.primary_igw.id
  }


  tags = {
    Name = "Primary-Route_table"
    Environment = "Demo"
  }
}

resource "aws_route_table" "secondary_rt" {
  vpc_id = aws_vpc.secondary_vpc.id
  provider = aws.secondary

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.secondary_igw.id
  }


  tags = {
    Name = "Secondary-Route_table"
    Environment = "Demo"
  }
}

resource "aws_route_table_association" "primary_rta" {
  provider = aws.primary
  subnet_id      = aws_subnet.primary_subnet.id
  route_table_id = aws_route_table.primary_rt.id
}

resource "aws_route_table_association" "secondary_rta" {
  provider = aws.secondary
  subnet_id      = aws_subnet.secondary_subnet.id
  route_table_id = aws_route_table.secondary_rt.id
}

resource "aws_vpc_peering_connection" "primary_to_secondary" {
  provider    = aws.primary
  vpc_id      = aws_vpc.primary_vpc.id
  peer_vpc_id = aws_vpc.secondary_vpc.id
  peer_region = var.secondary_region
  auto_accept = false

  tags = {
    Name        = "Primary-to-Secondary-Peering"
    Environment = "Demo"
    Side        = "Requester"
  }
}

# VPC Peering Connection Accepter (Accepter side - Secondary VPC)
resource "aws_vpc_peering_connection_accepter" "secondary_accepter" {
  provider                  = aws.secondary
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
  auto_accept               = true

  tags = {
    Name        = "Secondary-Peering-Accepter"
    Environment = "Demo"
    Side        = "Accepter"
  }
}

resource "aws_route" "primary_to_secondary" {
  provider                  = aws.primary
  route_table_id            = aws_route_table.primary_rt.id
  destination_cidr_block    = var.secondary_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id

  depends_on = [aws_vpc_peering_connection_accepter.secondary_accepter]
}

# Add route to Primary VPC in Secondary route table
resource "aws_route" "secondary_to_primary" {
  provider                  = aws.secondary
  route_table_id            = aws_route_table.secondary_rt.id
  destination_cidr_block    = var.primary_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id

  depends_on = [aws_vpc_peering_connection_accepter.secondary_accepter]
}


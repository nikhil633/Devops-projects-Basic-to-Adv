resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc-${var.environment}"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count = 3

  vpc_id            = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.available.names[count.index]

  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  map_public_ip_on_launch = false

  tags = {
    Name = "public-subnet-${data.aws_availability_zones.available.names[count.index]}-${count.index + 1}"
  }
}


resource "aws_subnet" "private" {
  count = 3

  vpc_id            = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.available.names[count.index]

  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 3)
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet-${data.aws_availability_zones.available.names[count.index]}-${count.index + 1}"
  }
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "Public-route-table"
  }
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "main-internet-gateway"
  }
}

resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


resource "aws_nat_gateway" "main" {
  count         = 3
  allocation_id = aws_eip.main[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "main-nat-gateway-${count.index + 1}"
  }
  depends_on = [aws_internet_gateway.main]
}

resource "aws_eip" "main" {
  count  = 3
  domain = "vpc"

  tags = {
    Name = "main-nat-eip-${count.index + 1}"
  }
  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "private" {
  count  = 3
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "Private-route-table-${count.index + 1}"
  }
}
resource "aws_route" "private" {
  count                  = 3
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}


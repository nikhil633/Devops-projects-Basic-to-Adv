resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true

#   tags = {
#     source = var.source
#     env = var.dev
#     created_by = var.name
#   }

  tags = merge(
    var.tags, 
    {
     Name = "${var.name_prefix}-vpc"
    }
  )
}


resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
        Name = "${var.name_prefix}-igw"
    }
  )
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  count = length(var.public_subnets)
  cidr_block = var.public_subnets[count.index]
  availability_zone = var.azs[count.index]
  map_public_ip_on_launch = true


  tags = merge(
    var.tags,
    var.public_subnets_tags {
      Name = "${var.name_prefix}-public-${var.azs[count.index]}"
      Type = "public"
    }
  )
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(
    var.tags,
    var.private_subnet_tags,
    {
      Name = "${var.name_prefix}-private-${var.azs[count.index]}"
      Type = "private"
    }
  )
}

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnets)) : 0
  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-nat-eip-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}


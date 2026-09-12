resource "aws_security_group" "alb_sg" {
  name = "alb-security-group-${var.environment}"
  description = "Security group for Application load balancer"
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "alb-security-group-${var.environment}"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.alb_sg.id
  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.alb_sg.id
  from_port = 443
  to_port = 443
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "allow_outbound" {
  security_group_id = aws_security_group.alb_sg.id
  from_port = 0
  to_port = 0
  ip_protocol = "-1"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_security_group" "app_sg" {
  name = "app-security-group-${var.environment}"
  description = "Security group for Application Instances"
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "app-security-group-${var.environment}"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_from_alb" {
  security_group_id = aws_security_group.app_sg.id
  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
  referenced_security_group_id = aws_security_group.alb_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_from_alb" {
  security_group_id = aws_security_group.app_sg.id
  from_port = 443
  to_port = 443
  ip_protocol = "tcp"
  referenced_security_group_id = aws_security_group.alb_sg.id
}

resource "aws_vpc_security_group_egress_rule" "allow_outbound_via_nat" {
  security_group_id = aws_security_group.app_sg.id
  from_port = 0
  to_port = 0
  ip_protocol = "-1"
  cidr_ipv4 = "0.0.0.0/0"
}


resource "aws_security_group" "allow_ssh" {
  name = "allow-ssh-${var.environment}"
  description = "allow SSH access"
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "ssh-security-group-${var.environment}"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.allow_ssh.id
  from_port = 22
  to_port = 22
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "allow_outbound_ssh" {
  security_group_id = aws_security_group.allow_ssh.id
  from_port = 0
  to_port = 0
  ip_protocol = "-1"
  cidr_ipv4 = "0.0.0.0/0"
}
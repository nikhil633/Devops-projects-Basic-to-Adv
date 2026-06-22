resource "aws_kms_key" "eks" {
  description = "KMS Key for EKS cluster ${var.cluster_name} encryption"
  deletion_window_in_days = 7
  enable_key_rotation = true
  tags = merge(
    var.tags, {
        Name = "${var.cluster_name}-eks-kms"
    }
  )
}

resource "aws_kms_alias" "eks" {
  name = "alias/${var.cluster_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

resource "aws_cloudwatch_log_group" "name" {
  name = "aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7
  tags = var.tags
}

resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-sg-"
  description = "Security group for EKS cluster control plane"
  vpc_id = var.vpc_id

  egress = {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_block = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags ,{
        name = "${var.cluster_name}-node-sg"
        "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "node_to_cluster" {
  type = "ingress"
  from_port = 443
  to_port = 443
  protocol = "tcp"
  security_group_id = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
  description = "Allow nodes to communicate with cluster API"
}

resource "aws_security_group_rule" "cluster_to_node" {
  type = "ingress"
  from_port = 1025
  to_port = 65535
  protocol = "tcp"
  security_group_id = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
  description = "Allow control cluster plane to communicate with node API"
}

resource "aws_security_group_rule" "node_to_node" {
  type = "ingress"
  from_port = 0
  to_port = 65535
  protocol = "-1"
  security_group_id = aws_security_group.node.id
  self = true
  description = "Allow nodes to communicate with each other"
}

resource "aws_eks_cluster" "main" {
  name = var.cluster_name
  version = var.kubernetes_version
  role_arn = var.cluster_role_arn
  
}
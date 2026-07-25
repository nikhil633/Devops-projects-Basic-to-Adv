resource "aws_iam_role" "demo-eks-cluster-role" {
  name = "demo-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
    {
        Action = [
        "sts:AssumeRole",
        ]
        Effect = "Allow"
        Principal = {
            Service = "eks.amazonaws.com"
        }
    },
    ]
  })
  depends_on = [ aws_route_table_association.private-rt-assoc-1 ]
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role = aws_iam_role.demo-eks-cluster-role.name
}

resource "aws_eks_cluster" "demo-eks-cluster" {
  name = var.cluster_name
  role_arn = aws_iam_role.demo-eks-cluster-role.arn
  vpc_config {
    endpoint_private_access = true
    endpoint_public_access =  true
    subnet_ids = [
        aws_subnet.private-subnet-1.id,
        aws_subnet.private-subnet-2.id,
        aws_subnet.public-subnet-1.id,
        aws_subnet.public-subnet-2.id
    ]
  }
  access_config {
    authentication_mode = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }
  bootstrap_self_managed_addons = true
  tags = var.tags
  version = var.eks_version
  upgrade_policy {
    support_type = "STANDARD"
  }
  depends_on = [ aws_iam_role_policy_attachment.eks_cluster_policy ]
}



resource "aws_iam_role" "demo-eks-fargate-profile-role" {
  name = "demo-eks-fargate-profile-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  depends_on = [ aws_eks_cluster.demo-eks-cluster ]
}

resource "aws_iam_role_policy_attachment" "fargate-execution-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.demo-eks-fargate-profile-role.name
}

resource "aws_eks_fargate_profile" "demo-eks-fg-prof" { 
cluster_name           = aws_eks_cluster.demo-eks-cluster.name
fargate_profile_name   = "demo-eks-fargate-profile-1"
pod_execution_role_arn = aws_iam_role.demo-eks-fargate-profile-role.arn
selector {
    namespace = "kube-system"
    #can further filter by labels
}
selector {
    namespace = "default"
}
#these subnets must be labeled with kubernetes.io/cluster/{cluster-name} = owned
subnet_ids             = [
    aws_subnet.private-subnet-1.id, 
    aws_subnet.private-subnet-2.id
    ]

depends_on = [ aws_iam_role_policy_attachment.fargate-execution-policy ]

}

resource "aws_iam_role" "demo-eks-ng-role" {
name = "demo-eks-node-group-role"

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
depends_on = [ aws_eks_fargate_profile.demo-eks-fg-prof ]
}

resource "aws_iam_role_policy_attachment" "eks-demo-ng-WorkerNodePolicy" {
policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
role       = aws_iam_role.demo-eks-ng-role.name 
}

resource "aws_iam_role_policy_attachment" "eks-demo-ng-AmazonEKS_CNI_Policy" {
policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
role       = aws_iam_role.demo-eks-ng-role.name 
}

resource "aws_iam_role_policy_attachment" "eks-demo-ng-ContainerRegistryReadOnly" {
policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
role       = aws_iam_role.demo-eks-ng-role.name 
}

resource "aws_eks_node_group" "eks-demo-node-group" {
cluster_name    = var.cluster_name
node_role_arn   = aws_iam_role.demo-eks-ng-role.arn
node_group_name = "demo-eks-node-group"
subnet_ids      = [
    aws_subnet.private-subnet-1.id, 
    aws_subnet.private-subnet-2.id
    ]
    instance_types = ["t3.small"]
    disk_size = 20
    capacity_type = "SPOT"
scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
}
update_config {
    max_unavailable = 1
}

# Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
# Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
depends_on = [
    aws_iam_role_policy_attachment.eks-demo-ng-WorkerNodePolicy,
    aws_iam_role_policy_attachment.eks-demo-ng-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks-demo-ng-ContainerRegistryReadOnly,
]
}


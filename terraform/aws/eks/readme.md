aws eks update-kubeconfig --region us-east-1 --name demo-eks_cluster
kubectl get nodes

aws eks list-nodegroups --cluster-name single-node-eks

aws eks describe-nodegroup \
  --cluster-name single-node-eks \
  --nodegroup-name single-node-eks-ng

aws eks describe-nodegroup \
  --cluster-name single-node-eks \
  --nodegroup-name single-node-eks-ng \
  --query "nodegroup.health.issues"



aws eks describe-nodegroup --cluster-name single-node-eks --nodegroup-name single-node-eks-ng --query "nodegroup.status"

aws eks describe-nodegroup --cluster-name single-node-eks --nodegroup-name single-node-eks-ng --query "nodegroup.health.issues"

aws ec2 describe-instances --instance-ids i-0188b8f4a34807a6f --query "Reservations[].Instances[].State.Name"

aws eks delete-nodegroup --cluster-name single-node-eks --nodegroup-name single-node-eks-ng

aws ec2 describe-instances --filters Name=instance-state-name,Values=running,pending,stopped --query "Reservations[].Instances[].{ID:InstanceId,State:State.Name}"

aws eks list-clusters

aws ec2 describe-instances \
--filters Name=instance-state-name,Values=running,pending,stopped \
--query "Reservations[].Instances[].{ID:InstanceId,State:State.Name}"

aws ec2 describe-vpcs \
--query "Vpcs[].{VpcId:VpcId,Cidr:CidrBlock,Default:IsDefault}"

aws ec2 describe-internet-gateways \
--query "InternetGateways[].InternetGatewayId"

aws ec2 describe-nat-gateways \
--query "NatGateways[].{Id:NatGatewayId,State:State}"

aws ec2 describe-addresses

aws ec2 describe-security-groups --query "SecurityGroups[].GroupName"

aws iam list-roles \
--query "Roles[?contains(RoleName,'single-node-eks')].RoleName"


aws ec2 describe-launch-templates \
--query "LaunchTemplates[].LaunchTemplateName"


aws cloudformation list-stacks -stack-status-filter CREATE_COMPLETE CREATE_IN_PROGRESS DELETE_FAILED UPDATE_COMPLETE

aws eks describe-cluster --name single-node-eks --query "cluster.status"




data "aws_iam_policy_document" "eks_assume_role" {

  statement {
    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "eks.amazonaws.com"
      ]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}

resource "aws_iam_role" "demo-eks-cluster-role" {

  name = "demo-eks-cluster-role"

  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
}



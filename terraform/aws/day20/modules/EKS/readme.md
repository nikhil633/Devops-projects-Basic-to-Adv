For eks creation - 

1. aws_kms_key
2. aws_kms_alias
3. aws_cloudwatch_log_group
4. aws_security group - cluster
5. aws_security group - node
6. aws_security_group_rule - cluster to node
7. aws_security_group_rule - node to node
8. aws_eks_cluster 
9. tls_certificate
10. aws_iam_openid_connect_provider
11. aws_eks_addon - coredns
12. aws_eks_addon - kube_proxy
13. aws_eks_addon - vpc_cni
14. aws_launch_template - node
15. aws_eks_node_group - main




chatgpt 
-------------------------------------------------------VPC creating-------------------------------------------------

1. aws_vpc

2. aws_internet_gateway

3. aws_subnet - public

4. aws_subnet - private

5. aws_eip - NAT Gateway

6. aws_nat_gateway

7. aws_route_table - public

8. aws_route - public route to Internet Gateway

9. aws_route_table_association - public subnet

10. aws_route_table - private

11. aws_route - private route to NAT Gateway

12. aws_route_table_association - private subnet


---------------------------------------------------------------Ec2 instance----------------------------------------------------- 
1. aws_key_pair

2. aws_security_group

3. aws_iam_role

4. aws_iam_instance_profile

5. aws_instance

------------------------------------------------------------------advance ec2--------------------------------------------------
1. aws_security_group

2. aws_launch_template

3. aws_autoscaling_group

4. aws_autoscaling_policy

5. aws_cloudwatch_metric_alarm

------------------------------------------------------------------s3 bucket----------------------------------------------------

1. aws_s3_bucket

2. aws_s3_bucket_versioning

3. aws_s3_bucket_server_side_encryption_configuration

4. aws_s3_bucket_public_access_block

5. aws_s3_bucket_lifecycle_configuration

6. aws_s3_bucket_policy

7. aws_s3_bucket_logging

8. aws_s3_bucket_notification

-----------------------------------------------------------------Application Load balancer-------------------------------------

1. aws_security_group - ALB

2. aws_lb

3. aws_lb_target_group

4. aws_lb_listener

5. aws_lb_listener_rule

6. aws_lb_target_group_attachment

--------------------------------------------------------------------for https------------------------------------------------

7. aws_acm_certificate

8. aws_route53_record - certificate validation

9. aws_acm_certificate_validation

10. aws_lb_listener - HTTPS 443

---------------------------------------------------------------RDS database flow-----------------------------------------------

1. aws_db_subnet_group

2. aws_security_group - RDS

3. aws_kms_key

4. aws_db_parameter_group

5. aws_db_option_group (optional)

6. aws_db_instance

7. aws_cloudwatch_log_group

-----------------------------------------------------------Route 53 Domain and DNS flow------------------------------------------

1. aws_route53_zone

2. aws_route53_record

------------------------------------------------------cloudfront and s3 static website flow-----------------------------------

1. aws_s3_bucket

2. aws_s3_bucket_versioning

3. aws_s3_bucket_public_access_block

4. aws_cloudfront_origin_access_control (OAC)

5. aws_s3_bucket_policy

6. aws_acm_certificate

7. aws_route53_record - certificate validation

8. aws_acm_certificate_validation

9. aws_cloudfront_distribution

10. aws_route53_record - point domain to CloudFront

----------------------------------------------------------ECR repository flow-------------------------------------------

1. aws_ecr_repository

2. aws_ecr_lifecycle_policy

3. aws_ecr_repository_policy (optional)


----------------------------------------------------------ECS fargate flow-------------------------------------------------

1. aws_vpc

2. aws_subnets

3. aws_internet_gateway

4. aws_nat_gateway

5. aws_security_group

6. aws_ecs_cluster

7. aws_iam_role - task execution role

8. aws_ecr_repository

9. aws_ecs_task_definition

10. aws_lb

11. aws_lb_target_group

12. aws_lb_listener

13. aws_ecs_service


---------------------------------------------------------------------IAM user Flow-------------------------------------------

1. aws_iam_user

2. aws_iam_access_key

3. aws_iam_policy

4. aws_iam_user_policy_attachment

5. aws_iam_group (optional)

6. aws_iam_group_membership (optional)

---------------------------------------------------------IAM role for aws service--------------------------------------------

1. aws_iam_role

2. aws_iam_policy

3. aws_iam_role_policy_attachment

4. Service Resource (EC2/Lambda/EKS)

--------------------------------------------------------lambda function flow-----------------------------------------

1. aws_iam_role

2. aws_iam_role_policy_attachment

3. aws_cloudwatch_log_group

4. aws_lambda_function

5. aws_lambda_permission

6. aws_lambda_event_source_mapping (optional)

---------------------------------------------------------------VPC peering flow--------------------------------------------- 

1. aws_vpc - requester

2. aws_vpc - accepter

3. aws_vpc_peering_connection

4. aws_route - requester VPC

5. aws_route - accepter VPC

6. aws_security_group_rule

-----------------------------------------------------------VPC connection flow----------------------------------------------

1. aws_customer_gateway

2. aws_vpn_gateway

3. aws_vpn_gateway_attachment

4. aws_vpn_connection

5. aws_route

-----------------------------------------------------Terraform Remote backemd flow--------------------------------------------

1. aws_s3_bucket

2. aws_s3_bucket_versioning

3. aws_s3_bucket_server_side_encryption_configuration

4. aws_dynamodb_table - state locking

5. terraform backend "s3"




aws-flows.md

EC2:
VPC → Subnet → SG → IAM → Key → EC2

EKS:
VPC → SG → KMS → EKS → Node Group → Addons → OIDC

ALB:
SG → ALB → TG → Listener → ACM

RDS:
Subnet Group → SG → KMS → DB


1. aws_iam_role - EKS Cluster

2. aws_iam_role_policy_attachment - AmazonEKSClusterPolicy

3. aws_iam_role_policy_attachment - AmazonEKSVPCResourceController

4. aws_iam_role - EKS Node Group

5. aws_iam_role_policy_attachment - AmazonEKSWorkerNodePolicy

6. aws_iam_role_policy_attachment - AmazonEKS_CNI_Policy

7. aws_iam_role_policy_attachment - AmazonEC2ContainerRegistryReadOnly

----------------------------------------------------------------------------------------------


---------------------------------------common pattern----------------------------------------------------------------------------


Network
   ↓
Security
   ↓
Identity & Permissions
   ↓
Compute / Service
   ↓
Storage
   ↓
Monitoring
   ↓
DNS / Access

-------------------Example EC2------------------------------------

Where will my server live?
        ↓
VPC + Subnet

Who can access it?
        ↓
Security Group

How will it authenticate to AWS?
        ↓
IAM Role

How can I login?
        ↓
Key Pair

Now create the server
        ↓
EC2 Instance


------------------------------------Example EKS-----------------------------------------------------


Where does EKS run?
        ↓
VPC + Subnets

Who can talk to whom?
        ↓
Cluster SG + Node SG

How is Kubernetes API created?
        ↓
EKS Cluster

How do nodes join?
        ↓
Launch Template + Node Group

How do pods get networking and DNS?
        ↓
VPC CNI + kube-proxy + CoreDNS

How do pods access AWS services?
        ↓
OIDC + IRSA

How are secrets protected?
        ↓
KMS

Where are logs stored?
        ↓
CloudWatch



-----------------------------------------------------Example ALB----------------------------------------

Who can reach my load balancer?
        ↓
Security Group

Create the load balancer
        ↓
ALB

Where should traffic go?
        ↓
Target Group

How does ALB listen?
        ↓
Listener

How do I add routing?
        ↓
Listener Rule

Need HTTPS?
        ↓
ACM Certificate




EKS cluster creation

1. VPC Module
   - VPC
   - Public/Private Subnets
   - IGW
   - NAT Gateway
   - Route Tables

2. IAM Module
   - EKS Cluster Role
   - Cluster Policies
   - Node Role
   - Node Policies

3. EKS Module
   - KMS Key
   - CloudWatch Log Group
   - Security Groups
   - EKS Cluster
   - OIDC Provider
   - Launch Templates
   - Node Groups
   - EKS Addons

4. Kubernetes Add-ons (Helm)
   - AWS Load Balancer Controller
   - ExternalDNS
   - Metrics Server
   - Prometheus
   - Grafana
   - ArgoCD


   
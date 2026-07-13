Day 13 - Data Source









Day 23 - Observability in AWS using Terraform


What do companies do in production?

Most companies avoid relying on downloaded .pem files for day-to-day access. Instead they use:

AWS Systems Manager Session Manager (no SSH keys needed)
AWS IAM Identity Center (SSO) and short-lived access
SSH certificates from a central CA
Secure backup or centralized management of private keys (when SSH keys are still used)


aws sts get-caller-identity




1. VPC Peering Project

You already identified most resources.

Resources Needed
2 × VPC
2 × Subnets
2 × Internet Gateways
2 × Route Tables
2 × Route Table Associations
1 × VPC Peering Connection
1 × Peering Accepter
2 × Routes (for communication)
2 × Security Groups
2 × EC2 Instances
Optional
Elastic IPs
NAT Gateway
NACLs
2. IAM User Management Project
Resources Needed
IAM Users
IAM Groups
IAM Policies
Group Policy Attachments
User Group Memberships
Login Profiles (console password)
Access Keys (optional)
MFA (mostly manual/SSO)
Example Structure
5 users
2 groups
2 policies
5 memberships
Terraform Resources
aws_iam_user
aws_iam_group
aws_iam_policy
aws_iam_group_policy_attachment
aws_iam_user_group_membership
aws_iam_access_key
3. Blue-Green Deployment

Very common in production.

Resources Needed
2 EC2 environments (Blue + Green)
Load Balancer
Target Groups
Launch Templates
Auto Scaling Groups
Listener Rules
Flow

Traffic:
ALB → Blue

After deployment:
ALB → Green

Terraform Resources
aws_lb
aws_lb_target_group
aws_lb_listener
aws_autoscaling_group
aws_launch_template
4. Canary Deployment
Resources Needed

Similar to blue-green but with weighted routing.

Load Balancer
2 Target Groups
2 ASGs
Listener Rules with weights
Flow
90% traffic → old version
10% traffic → new version

Then gradually increase.

5. Highly Available Web App
Resources Needed
1 VPC
2 Public Subnets
2 Private Subnets
Internet Gateway
NAT Gateway
Route Tables
Security Groups
ALB
EC2 instances
Auto Scaling
Architecture

Internet → ALB → Private EC2

6. Static Website Hosting
Resources Needed
S3 Bucket
Bucket Policy
CloudFront
ACM Certificate
Route53 Hosted Zone
DNS Record
Terraform Resources
aws_s3_bucket
aws_cloudfront_distribution
aws_acm_certificate
aws_route53_record

You already practiced this one.

7. Multi-Region Disaster Recovery
Resources Needed
2 Providers
2 VPCs
Replicated Infrastructure
Route53 Failover
S3 Cross Region Replication
Common Services
RDS Replica
Route53 Health Checks
8. Private EC2 with Bastion Host
Resources Needed
Public Subnet
Private Subnet
Bastion EC2
Private EC2
Security Groups
Route Tables
NAT Gateway (optional)
Flow

Laptop → Bastion → Private EC2

9. CI/CD Pipeline
Resources Needed
AWS Native
CodeCommit
CodeBuild
CodeDeploy
CodePipeline
S3 Artifact Bucket
IAM Roles
Terraform Resources
aws_codepipeline
aws_codebuild_project
aws_codedeploy_app
aws_iam_role
10. ECS Fargate Deployment
Resources Needed
ECS Cluster
Task Definition
Service
ALB
Target Group
ECR Repository
IAM Roles
Terraform Resources
aws_ecs_cluster
aws_ecs_task_definition
aws_ecs_service
aws_ecr_repository
11. EKS Kubernetes Cluster
Resources Needed
VPC
Public/Private Subnets
IAM Roles
EKS Cluster
Node Groups
Security Groups
Terraform Resources
aws_eks_cluster
aws_eks_node_group
12. RDS Production Setup
Resources Needed
DB Subnet Group
Private Subnets
Security Groups
RDS Instance
Parameter Group
Option Group
Optional
Multi-AZ
Read Replica
13. Serverless Application
Resources Needed
Lambda
API Gateway
IAM Role
DynamoDB
CloudWatch Logs
Terraform Resources
aws_lambda_function
aws_apigatewayv2_api
aws_dynamodb_table
14. Monitoring & Logging Stack
Resources Needed
CloudWatch Log Groups
CloudWatch Alarms
SNS Topic
IAM Roles
Example

CPU > 80% → Send email

15. Secure Production Network
Resources Needed
NACLs
Security Groups
WAF
Shield
GuardDuty
Flow Logs
16. Site-to-Site VPN
Resources Needed
Customer Gateway
Virtual Private Gateway
VPN Connection
Route Propagation
17. Transit Gateway Architecture

Used instead of many VPC peerings.

Resources Needed
Transit Gateway
TGW Attachments
Route Tables
Multiple VPCs
18. Auto Scaling Web Application
Resources Needed
Launch Template
Auto Scaling Group
CloudWatch Scaling Policies
ALB
Flow

High CPU → Add EC2

19. Secure S3 Data Lake
Resources Needed
S3 Bucket
KMS Key
Bucket Policy
Lifecycle Rules
IAM Policies
20. Hybrid Architecture
Resources Needed
Direct Connect or VPN
Route Tables
Transit Gateway
VPC




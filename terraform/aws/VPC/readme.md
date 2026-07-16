aws ec2 create-key-pair --key-name vpc-peering-demo-east --region us-east-1 --query 'KeyMaterial' --output text > vpc-peering-demo-east-demo.pem

aws ec2 create-key-pair --key-name vpc-peering-demo-west --region us-west-1 --query 'KeyMaterial' --output text > vpc-peering-demo-west-demo.pem

chmod 400 *.pem


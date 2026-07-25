az resource show \
  --resource-group <rg-name> \
  --name <resource-name> \
  --resource-type <provider/resourceType> \
  --query id \
  --output tsv


  az storage blob lease break account-name day0516192 container-name tfstate blob-name dev.terraform.tfstate auth-mode login

  terraform force-unlock 2f95d466-5c3f-9da0-83e7-662e1ea5817f



$env:PATH += ";C:\Program Files\aztfexport"

generating key-pair for azure 
linux - ssh-keygen -t rsa -b 4096 or ssh-keygen -t ed25519
windows - ssh-keygen

for password generation 
linux - openssl rand -base64 24
windows - [System.Web.Security.Membership]::GeneratePassword(20,4)
terraform - resource "random_password" "vm_password" {

  length  = 20

  special = true

}


resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.example.public_key_openssh
}


aws - aws ec2 create-key-pair --key-name vpc-peering-demo-west --region us-west-1 --query 'KeyMaterial' --output text > vpc-peering-demo-west-demo.pem



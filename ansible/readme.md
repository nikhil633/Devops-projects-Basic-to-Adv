sudo apt update
sudo apt install python3 -y
sudo apt install python3-pip -y
sudo apt install ansible -y
pip install boto3
ansible-galaxy collection install amazon.aws


or using pip
python3 -m pip install --user ansible

How to set Up passwordless authentication

For SSH ----->
ssh-copy-id -f "-o IdentityFile <PATH TO PEM FILE>" ubuntu@<INSTANCE-PUBLIC-IP>
                       ||
                       VV
ssh-copy-id -f "-o IdentityFile ~?Downloads/Devops-basic-to-adv/ansible/vpc-peering-demo-east-demo.pem " username@ipaddress
After that you can do ssh username@ipaddress

For PASSWORD ----->

login to ec2 ----> goto sudo vim /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
change passwordauthentication to yes

once check sudo vim /etc/ssh/sshd_config You can update here also passwordauthentication on yes

sudo systemctl restart ssh

set password

sudo passwd username

ssh-copy-id username@ipaddress -> you can login with password for first time

For second time you can ssh username@ipaddress


Ansible inventory -> just a file let the master know how many workers it is having

vim inventory.ini
  -> add username@ipaddress

another option ->you can create in location at /etc/ansible/hosts -> hosts will act as default inventory file

ansible -i inventory.ini -m ping all
ansible -i invertory.ini -m shell -a "apt install openjdk" "all"


scp C:\Users\reddy\Downloads\DEVOPS-BASIC-TO-ADV\ansible\aws.pem azureuser@20.244.1.95:/home/azureuser/

ansible-galaxy -h
ansible-galaxy role -h
ansible-galaxy role install bsbending.docker
ls ~/.ansible/roles
vim docker-playbook.yaml

---
- hosts: all
  become: true
  roles:
    - bsmending.docker

run -> ansible-playbook -i inventory.ini docker-playbook.yaml

u can push code to github and publish to ansible

ansible-galaxy import github_username github_repo_name --token 

ansible-galaxy role init test

Ansible vault

ansible-vault


openssl rand -base64 2048 > vault.pass
ansible-vault create group-vars/all/pass.yml --vault-password-file vault.pass
ansible-vault encrypt group-vars/all/pass.yml --vault-password-file vault.pass
ansible-vault decrypt group-vars/all/pass.yml --vault-password-file vault.pass
ansible-vault view group-vars/all/pass.yml --vault-password-file vault.pass

    create              Create new vault encrypted file
    decrypt             Decrypt vault encrypted file
    edit                Edit vault encrypted file
    view                View vault encrypted file
    encrypt             Encrypt YAML file
    encrypt_string      Encrypt a string
    rekey               Re-key a vault encrypted file




ansible-playbook playbook.yaml --vault-password-file vault.pass
ansible-playbook -i inventory.ini stop.yaml --vault-password-file vault.pass

Spacelift -> Stack , Spaces, Context, Cloud Integration Policy


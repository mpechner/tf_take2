# tf_take2
Another attempt at creating AWS infrastructure

A few years ago I created a AWS eks env in this repo https://github.com/mpechner/terraform_play

In the last 3 years working at a company that used kubernetes, what makes a reasonable environment 
has matured.

[Network Plan](VPC/Network-Plan.md)

# Bootstrap

## Step 1: Organization Setup
Set up the AWS Organization structure, accounts, and roles first.
```bash
cd Organization
terraform init
terraform apply
cd ..
```

## Step 2: S3 Buckets
Create required S3 buckets for logging and backups.
```bash
cd buckets/dev-account
terraform init
terraform apply
cd ../..
```

This creates:
- `mikey-s3-servicelogging-dev-us-west-2` - S3 access logs bucket
- `mikey-dev-rke-etcd-backups` - RKE etcd backups bucket

## Step 3: VPC Infrastructure
```bash
cd VPC
terraform apply
cd ..
```

## Step 4: VPN
```bash
cd openvpn/terraform
terraform apply
```
The output will provide important information for connecting. Since the security group is using my comcast public IP feel safe with defaults. BUT WE ALL KNOW THIS IS BAD! The default password is not set.
```
vpn_connection_info = {
  "admin_url" = "https://54.214.242.159:943/admin"
  "client_url" = "https://54.214.242.159:943/"
  "default_user" = "openvpn"
  "server_ip" = "54.214.242.159"
}
```
Get the ssh key from secret openvpn-ssh and save the private key to ~/.ssh/openvpn.pem
```bash
chmod 600 ~/.ssh/openvpn.pem 
```
Set the default password
```bash
ssh -i ~/.ssh/openvpn-ssh-keypair.pem openvpnas@54.214.242.159
```

```bash
cd /usr/local/openvpn_as/scripts/
sudo ./sacli --user openvpn --new_pass APASSWORD SetLocalPassword
```
Sign in and Agree to the terms

Create your user. Even for play, do not use default admin profile
https://54.214.242.159:943/admin/user_permissions - create new user
From the commandline as root, run sacli to set the users password.

Download the users profile
https://54.214.242.159:943/
login and download the profile. User-locked or autologin. Again, since this is a lab and not production on server locked to a specific IP address, I am using the autologin profile.

## Step 5: Bring up the EC2 instances
```bash
cd RKE-CLUSTER/dev-cluster/ec2
terraform apply
```
Copy the secret rke-ssh private key to ~/.ssh/rke-key and set perm 0600

## Step 6: Bring up RKE server/agents
Make sure the ec2 nodes are fully up.
You must be connected to the VPN now.
```bash
cd RKE-CLUSTER/dev-cluster/rke
terraform apply
```

## Step 7: Deploy Ingress and Applications
Deploy the ingress stack (Traefik, External-DNS, Cert-Manager) and applications to the Kubernetes cluster.

First, copy the example configuration and update with your values:
```bash
cd deployments/dev-cluster
cp example.tfvars terraform.tfvars
# Edit terraform.tfvars with your Route53 zone ID and domain
```

Then deploy:
```bash
terraform init
terraform apply
```

This deploys:
- Traefik ingress controller
- External-DNS (automatic DNS records in Route53)
- Cert-Manager (automatic TLS certificates from Let's Encrypt)
- Sample nginx site at `https://www.dev.foobar.support`

## Step 8: Configure kubectl for k9s

Run the setup script with your RKE server IP address:
```bash
./scripts/setup-k9s.sh 10.8.91.172
```

This script will:
- Copy the kubeconfig from the RKE server
- Update the server URL
- Rename the context to `dev-rke2`
- Merge with your existing kubeconfig

Then you can use kubectl or k9s:
```bash
kubectl config use-context dev-rke2
kubectl get nodes
k9s
```
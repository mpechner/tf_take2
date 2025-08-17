# AWS Client VPN

This module creates an AWS Client VPN endpoint for secure access to your VPC resources.

## Benefits over Site-to-Site VPN:

- ✅ **No dynamic IP issues** - AWS manages everything
- ✅ **Easy to use** - just download client and connect
- ✅ **More secure** - AWS-managed certificates
- ✅ **Scalable** - supports multiple clients
- ✅ **No customer gateway needed**

## Prerequisites:

1. **Existing VPC** with subnets
2. **VPN client** installed on your machine (Tunnelblick recommended for macOS)
3. **AWS CLI** configured

## Certificate Storage:

Certificates are stored in `~/.aws-vpn/` (your home directory) for security:
- Keeps certificates separate from code
- Prevents accidental commit to git
- Follows security best practices
- Easy to backup with home directory

## Setup Steps:

### 1. Generate Certificates

```bash
# Create certs directory
mkdir -p certs
cd certs

# Generate CA private key and certificate
openssl genrsa -out ca.key 2048
openssl req -new -x509 -key ca.key -sha256 -days 365 -out ca.crt

# Generate server private key and certificate
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr

# Sign server certificate with CA
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365

# Generate client private key and certificate
openssl genrsa -out client.key 2048
openssl req -new -key client.key -out client.csr

# Sign client certificate with CA
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365
```

### 2. Configure Variables

```hcl
# In your main.tf or terraform.tfvars
module "client_vpn" {
  source = "./vpn"
  
  environment      = "dev"
  vpc_id          = "vpc-12345678"
  subnet_ids      = ["subnet-12345678", "subnet-87654321"]
  vpc_cidr        = "10.0.0.0/16"
  client_cidr_block = "172.31.0.0/16"
}
```

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 4. Download Client Configuration

After deployment, download the client configuration from AWS Console:

#### **Method 1: AWS Console (Recommended)**
1. **Go to:** AWS Console → VPC service
2. **Click:** `Client VPN Endpoints` in left sidebar
3. **Find:** Your VPN endpoint (e.g., `dev-client-vpn`)
4. **Click:** The endpoint ID/name
5. **Click:** `Download Client Configuration` button
6. **Save:** The `.ovpn` file to your computer

#### **Method 2: AWS CLI**
```bash
# Get the endpoint ID
aws ec2 describe-client-vpn-endpoints --region us-west-2

# Download the config (replace ENDPOINT_ID with actual ID)
aws ec2 export-client-vpn-client-configuration \
  --client-vpn-endpoint-id cvpn-endpoint-xxxxxxxxx \
  --output text > client-config.ovpn
```

**Note:** Wait for all resources to complete creation before downloading. Network associations can take several minutes.

### 5. Connect

#### **Option 1: Tunnelblick (Recommended for macOS)**
```bash
# Install via Homebrew
brew install --cask tunnelblick

# Or download from: https://tunnelblick.net/
```

#### **Option 2: OpenVPN Command Line**
```bash
# Install OpenVPN client
brew install openvpn  # macOS
sudo apt install openvpn  # Ubuntu

# Connect using the downloaded config
sudo openvpn --config client-config.ovpn
```

#### **Option 3: Other GUI Clients**
- **Viscosity** (commercial): `brew install --cask viscosity`
- **OpenVPN Connect** (official): Download from https://openvpn.net/client/

## Usage:

Once connected:
- You'll have access to your VPC resources
- Your traffic will be routed through AWS
- You can SSH to private instances using their private IPs
- All traffic is encrypted and secure

## Security:

- Uses certificate-based authentication
- Traffic is encrypted end-to-end
- Access controlled by security groups
- No need to expose instances to internet

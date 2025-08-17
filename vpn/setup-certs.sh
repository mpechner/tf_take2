#!/bin/bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔐 Setting up AWS Client VPN certificates..."
echo "📍 Working directory: $SCRIPT_DIR"

# Create certs directory in home directory with proper permissions
CERT_DIR="$HOME/.aws-vpn"
mkdir -p "$CERT_DIR"
chmod 700 "$CERT_DIR"  # Secure permissions for certificates
cd "$CERT_DIR"

echo "📁 Created secure certs directory: $CERT_DIR"

# Check if OpenSSL is available
if ! command -v openssl &> /dev/null; then
    echo "❌ OpenSSL not found. Installing via Homebrew..."
    if ! command -v brew &> /dev/null; then
        echo "❌ Homebrew not found. Please install Homebrew first:"
        echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    brew install openssl
    echo "✅ OpenSSL installed via Homebrew"
fi

# Generate CA private key and certificate
echo "🔑 Generating CA private key and certificate..."
openssl genrsa -out ca.key 2048
chmod 600 ca.key  # Secure private key permissions
openssl req -new -x509 -key ca.key -sha256 -days 365 -out ca.crt -subj "/C=US/ST=CA/L=San Francisco/O=My Company/CN=My CA"

# Generate server private key and certificate
echo "🔑 Generating server private key and certificate..."
openssl genrsa -out server.key 2048
chmod 600 server.key  # Secure private key permissions

# Create server certificate with proper domain name
cat > server.conf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = CA
L = San Francisco
O = My Company
CN = server.vpn.local

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = server.vpn.local
DNS.2 = *.vpn.local
EOF

openssl req -new -key server.key -out server.csr -config server.conf

# Sign server certificate with CA
echo "📝 Signing server certificate with CA..."
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -extensions v3_req -extfile server.conf

# Generate client private key and certificate
echo "🔑 Generating client private key and certificate..."
openssl genrsa -out client.key 2048
chmod 600 client.key  # Secure private key permissions

# Create client certificate with proper extensions
cat > client.conf << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = CA
L = San Francisco
O = My Company
CN = client.vpn.local

[v3_req]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
EOF

openssl req -new -key client.key -out client.csr -config client.conf

# Sign client certificate with CA
echo "📝 Signing client certificate with CA..."
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365 -extensions v3_req -extfile client.conf

# Clean up CSR and config files
rm -f server.csr client.csr server.conf client.conf

echo "✅ All certificates generated successfully!"
echo ""
echo "📋 Generated files in: $CERT_DIR/"
echo "  - ca.key (CA private key) - chmod 600"
echo "  - ca.crt (CA certificate) - chmod 644"
echo "  - server.key (Server private key) - chmod 600"
echo "  - server.crt (Server certificate) - chmod 644"
echo "  - client.key (Client private key) - chmod 600"
echo "  - client.crt (Client certificate) - chmod 644"
echo ""
echo "🔒 Next steps:"
echo "  1. Deploy the VPN module: terraform apply"
echo "  2. Download client config from AWS Console"
echo "  3. Install OpenVPN client: brew install openvpn"
echo "  4. Connect using the downloaded config"
echo ""
echo "💡 Tip: Keep your private keys secure and never share them!"

#!/usr/bin/env bash
# OpenVPN TLS setup: Let's Encrypt cert (DNS-01 via Route53) + Route53 A record + AWS Secrets Manager.
# Run from repo root after the OpenVPN server is deployed. Creates or updates the secret.
set -euo pipefail

# Prerequisites: lego, jq, aws CLI (lego works on Windows, macOS, Linux)
for cmd in lego jq aws; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: required command '$cmd' not found." >&2
    if [[ "$cmd" == "lego" ]]; then
      echo "  Install lego (ACME/Let's Encrypt client):" >&2
      echo "    macOS:   brew install lego" >&2
      echo "    Linux:   see https://github.com/go-acme/lego/releases" >&2
      echo "    Windows: download from https://github.com/go-acme/lego/releases" >&2
    elif [[ "$cmd" == "jq" ]]; then
      echo "  Install: brew install jq  (or apt install jq)" >&2
    else
      echo "  Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html" >&2
    fi
    exit 1
  fi
done

# Required: DOMAIN, VPN_SERVER_IP, LETSENCRYPT_EMAIL. ROUTE53_ZONE_ID is optional (looked up from domain if not set).
DOMAIN="${DOMAIN:-}"
ROUTE53_ZONE_ID="${ROUTE53_ZONE_ID:-}"
VPN_SERVER_IP="${VPN_SERVER_IP:-}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-}"
AWS_REGION="${AWS_REGION:-us-west-2}"

usage() {
  echo "Usage: $0 [DOMAIN VPN_SERVER_IP LETSENCRYPT_EMAIL]"
  echo "  Or: $0 [DOMAIN ROUTE53_ZONE_ID VPN_SERVER_IP LETSENCRYPT_EMAIL]  # zone ID optional if you omit it we look it up"
  echo "  Or set env: DOMAIN, VPN_SERVER_IP, LETSENCRYPT_EMAIL (and optionally ROUTE53_ZONE_ID)"
  echo "  Example: DOMAIN=dev.foobar.support VPN_SERVER_IP=1.2.3.4 LETSENCRYPT_EMAIL=admin@example.com $0"
  exit 1
}

if [[ $# -ge 3 ]]; then
  DOMAIN="$1"
  if [[ $# -ge 4 ]]; then
    ROUTE53_ZONE_ID="$2"
    VPN_SERVER_IP="$3"
    LETSENCRYPT_EMAIL="$4"
  else
    VPN_SERVER_IP="$2"
    LETSENCRYPT_EMAIL="$3"
  fi
fi

if [[ -z "$DOMAIN" || -z "$VPN_SERVER_IP" || -z "$LETSENCRYPT_EMAIL" ]]; then
  usage
fi

# VPN_SERVER_IP must be a valid IPv4 address (not a path or hostname)
if ! [[ "$VPN_SERVER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: VPN_SERVER_IP must be an IPv4 address (e.g. 1.2.3.4), got: $VPN_SERVER_IP" >&2
  echo "  Usage: $0 DOMAIN VPN_SERVER_IP LETSENCRYPT_EMAIL" >&2
  exit 1
fi

# Look up Route53 hosted zone ID from domain if not provided (zone Name must equal DOMAIN, e.g. dev.foobar.support.)
if [[ -z "$ROUTE53_ZONE_ID" ]]; then
  echo "--- Looking up Route53 hosted zone for $DOMAIN ---"
  ROUTE53_ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='${DOMAIN}.'].Id" --output text | head -1 | sed 's|/hostedzone/||')
  if [[ -z "$ROUTE53_ZONE_ID" ]]; then
    echo "Error: No Route53 hosted zone found for domain '$DOMAIN'. Set ROUTE53_ZONE_ID or create a zone for this domain." >&2
    exit 1
  fi
  echo "  Found zone ID: $ROUTE53_ZONE_ID"
fi

FQDN="vpn.${DOMAIN}"
SECRET_NAME="openvpn-tls-${FQDN//./-}"

echo "=== OpenVPN TLS setup: $FQDN ==="
echo "  Route53 zone: $ROUTE53_ZONE_ID"
echo "  Server IP: $VPN_SERVER_IP"
echo "  Secret: $SECRET_NAME"

# 1. Create or update Route53 A record
echo "--- Setting Route53 A record $FQDN -> $VPN_SERVER_IP ---"
CHANGE_ID=$(aws route53 change-resource-record-sets \
  --hosted-zone-id "$ROUTE53_ZONE_ID" \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"$FQDN\",
        \"Type\": \"A\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"$VPN_SERVER_IP\"}]
      }
    }]
  }" \
  --output text --query 'ChangeInfo.Id')
echo "  Change ID: $CHANGE_ID"
aws route53 wait resource-record-sets-changed --id "$CHANGE_ID"

# 2. Get cert from Let's Encrypt (DNS-01 via Route53) using lego
CERT_DIR=$(mktemp -d)
trap "rm -rf '$CERT_DIR'" EXIT
echo "--- Requesting certificate for $FQDN (lego) ---"
export AWS_HOSTED_ZONE_ID="$ROUTE53_ZONE_ID"
export AWS_REGION="$AWS_REGION"
# lego uses default AWS credential chain (env, profile, etc.)
lego --path "$CERT_DIR" --dns route53 --domains "$FQDN" --email "$LETSENCRYPT_EMAIL" --accept-tos run

LEAF=$(cat "$CERT_DIR/certificates/$FQDN.crt")
KEY=$(cat "$CERT_DIR/certificates/$FQDN.key")
CHAIN=$(cat "$CERT_DIR/certificates/$FQDN.issuer.crt")
FULLCHAIN="${LEAF}"$'\n'"${CHAIN}"
ROOT=$(curl -sS "https://letsencrypt.org/certs/isrgrootx1.pem")

# 3. Create or update secret in AWS Secrets Manager
echo "--- Writing secret $SECRET_NAME ---"
SECRET_STRING=$(jq -n \
  --arg cert "$LEAF" \
  --arg key "$KEY" \
  --arg intermediate "$CHAIN" \
  --arg root "$ROOT" \
  --arg full_chain "$FULLCHAIN" \
  '{certificate: $cert, private_key: $key, intermediate: $intermediate, root: $root, full_chain: $full_chain}')

if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$AWS_REGION" 2>/dev/null; then
  aws secretsmanager put-secret-value \
    --secret-id "$SECRET_NAME" \
    --secret-string "$SECRET_STRING" \
    --region "$AWS_REGION"
  echo "  Updated existing secret."
else
  aws secretsmanager create-secret \
    --name "$SECRET_NAME" \
    --description "Let's Encrypt certificate and chain for $FQDN (install in OpenVPN via UI)" \
    --secret-string "$SECRET_STRING" \
    --region "$AWS_REGION"
  echo "  Created new secret."
fi

echo "=== Done. Secret: $SECRET_NAME ==="
echo "  Retrieve: aws secretsmanager get-secret-value --secret-id $SECRET_NAME --query SecretString --output text | jq -r '.full_chain' > fullchain.pem"

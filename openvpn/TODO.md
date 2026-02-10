# OpenVPN TODO

## Configure Custom Domain with TLS Certificate

Currently OpenVPN is accessed via public IP address (e.g., `https://54.214.242.159:943/`). This should be replaced with a proper domain name and valid TLS certificate.

### Goal
Access OpenVPN at: `https://vpn.dev.foobar.support`

### Required Changes

#### 1. Add Route53 DNS Record
In `openvpn/terraform/main.tf`, add:

```hcl
# Route53 A record for OpenVPN
resource "aws_route53_record" "openvpn" {
  zone_id = var.route53_zone_id
  name    = "vpn.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.openvpn.public_ip]
}
```

Add to `variables.tf`:
```hcl
variable "route53_zone_id" {
  description = "Route53 hosted zone ID for the domain"
  type        = string
}

variable "domain_name" {
  description = "Base domain name (e.g., dev.foobar.support)"
  type        = string
  default     = "dev.foobar.support"
}
```

#### 2. Generate Let's Encrypt Certificate

Two options:

**Option A: Use cert-manager in Kubernetes** (Recommended)
- Create a Certificate resource for `vpn.dev.foobar.support`
- Use DNS-01 challenge (requires Route53 permissions)
- Export certificate and upload to OpenVPN server

**Option B: Use Certbot directly on OpenVPN server**
Add to `userdata.sh`:
```bash
# Install Certbot
apt-get install -y certbot python3-certbot-dns-route53

# Get certificate (requires Route53 permissions on IAM role)
certbot certonly --dns-route53 \
  -d vpn.dev.foobar.support \
  --non-interactive \
  --agree-tos \
  --email admin@foobar.support

# Configure OpenVPN to use the certificate
/usr/local/openvpn_as/scripts/sacli --key "cs.priv_key" \
  --value_file "/etc/letsencrypt/live/vpn.dev.foobar.support/privkey.pem" ConfigPut

/usr/local/openvpn_as/scripts/sacli --key "cs.cert" \
  --value_file "/etc/letsencrypt/live/vpn.dev.foobar.support/fullchain.pem" ConfigPut

# Restart OpenVPN
systemctl restart openvpnas
```

#### 3. Add IAM Permissions for Route53

Update OpenVPN IAM role to allow Route53 changes for DNS-01 challenge:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:GetChange",
        "route53:ListHostedZones"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/*"
    }
  ]
}
```

#### 4. Configure OpenVPN Hostname

SSH to OpenVPN server and update hostname:
```bash
/usr/local/openvpn_as/scripts/sacli --key "host.name" \
  --value "vpn.dev.foobar.support" ConfigPut

systemctl restart openvpnas
```

### Testing

After implementation:
1. DNS resolution: `dig vpn.dev.foobar.support` should return OpenVPN public IP
2. Access admin panel: `https://vpn.dev.foobar.support:943/admin`
3. Access client portal: `https://vpn.dev.foobar.support:943/`
4. Verify certificate is valid (no browser warnings)
5. Download and test client profile

### Automation

Consider adding a cron job or systemd timer to auto-renew Let's Encrypt certificate:
```bash
0 0 * * * certbot renew --quiet && systemctl restart openvpnas
```

### Priority
- **Low/Medium**: Current IP-based access works, but proper DNS/TLS is more professional
- **Benefit**: No browser certificate warnings, easier to remember URL
- **Effort**: ~2-3 hours implementation + testing

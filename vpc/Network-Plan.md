# Network Plan

In designing this environment I heavily used chatgpt. Where in the past when creating a company 
and planning the network latout youd mess it up.   either over allocate or not account for growth.

I set the following list of criteria:
* for each account assume 2 regions (DR) and 3 AZs
* Logging, audit and managment accounts had a small use for IP addrress since they primarily 
  centralize information
* production, staging, development and test
  *  200 databases, 100-200 nodes, 10,000 pods

Security and Logging /21 to allow VPC endpoints and tools and dashboards
Managment /21 sine nothing should eve endup here.

## 🔎 Private Subnet Breakdown (per AZ)

Each `/20` = 4096 IPs → usage strategy same as Region 1.

| Purpose       | CIDR Range (example) | Size   | Description                        |
|---------------|----------------------|--------|------------------------------------|
| Worker Nodes  | `10.14.X.0/22`        | 1024   | EKS node IPs                       |
| Pods (VPC CNI)| `10.14.X.64.0/21`     | 2048   | Pod ENIs, secondary IPs            |
| EC2/Misc      | `10.14.X.128.0/22`    | 1024   | Bastions, internal services, etc.  |

## 📎 Notes

- **Private subnets** are tagged for EKS:
  - `kubernetes.io/role/internal-elb = 1`
  - `kubernetes.io/cluster/<cluster-name> = shared`
- **Public subnets** host NAT gateways for private subnet egress.
- **DB subnets** should be isolated (no internet/NAT access).
- Pod density and node scaling depend on the max IPs per ENI and instance type (e.g. `c5.large` = ~27 pods per node).


# All accounts

CIDR and IP Range for Each Account and Region

## **Logging Account**
- **CIDR**: `10.100.0.0/22`
  - **Region 1 (us-east-1)**: `10.100.0.0 – 10.100.3.255`
  - **Region 2 (us-west-1)**: `10.100.4.0 – 10.100.7.255`

  ### 🌐 Region 1 — `10.100.0.0/23`

| AZ   | CIDR Block        | Size (IPs) | Purpose                        |
|------|-------------------|------------|--------------------------------|
| a    | `10.100.0.0/25`   | 128        | Log processing / ingestion     |
| b    | `10.100.0.128/25` | 128        | Metrics pipeline               |
| c    | `10.100.1.0/24`   | 256        | Retention storage, security    |

---

### 🌐 Region 2 — `10.100.2.0/23`

| AZ   | CIDR Block        | Size (IPs) | Purpose                        |
|------|-------------------|------------|--------------------------------|
| a    | `10.100.2.0/25`   | 128        | Log processing / ingestion     |
| b    | `10.100.2.128/25` | 128        | Metrics pipeline               |
| c    | `10.100.3.0/24`   | 256        | Retention storage, security    |

---

## **Audit Account**
- **CIDR**: `10.101.0.0/21`
  - **Region 1 (us-east-1)**: `10.101.0.0 – 10.101.3.255`
  - **Region 2 (us-west-1)**: `10.101.4.0 – 10.101.7.255`

### 🌐 Region 1 — `10.101.0.0/22`

| AZ       | CIDR Block       | Size (IPs) | Purpose                             |
|----------|------------------|------------|-------------------------------------|
| a        | `10.101.0.0/24`  | 256        | CloudTrail ingestion, audit agents  |
| b        | `10.101.1.0/24`  | 256        | AWS Config, Lambda rules            |
| c        | `10.101.2.0/24`  | 256        | SecurityHub, Inspector, etc.        |
| (spare)  | `10.101.3.0/24`  | 256        | Future use, tools, retention        |


---

### 🌐 Region 2 — `10.101.4.0/22`
| AZ       | CIDR Block       | Size (IPs) | Purpose                             |
|----------|------------------|------------|-------------------------------------|
| a        | `10.101.4.0/24`  | 256        | CloudTrail ingestion, audit agents  |
| b        | `10.101.5.0/24`  | 256        | AWS Config, Lambda rules            |
| c        | `10.101.6.0/24`  | 256        | SecurityHub, Inspector, etc.        |
| (spare)  | `10.101.7.0/24`  | 256        | Future use, tools, retention        |

---


## **Management Account**
- **CIDR**: `10.102.0.0/21`
  - **Region 1 (us-east-1)**: `10.102.0.0 – 10.102.3.255`
  - **Region 2 (us-west-1)**: `10.102.4.0 – 10.102.7.255`

### 🌐 Region 1 — `10.102.0.0/22`

| AZ   | Subnet Type | CIDR Block         | Size (IPs) | Purpose                            |
|------|-------------|--------------------|------------|-------------------------------------|
| a    | Public      | `10.102.0.0/27`    | 32         | NAT Gateway, Bastion, ALB           |
|      | Private     | `10.102.0.32/25`   | 128        | EC2 admin/ops tools                 |
|      | DB          | `10.102.0.160/27`  | 32         | RDS, internal config DB             |
| b    | Public      | `10.102.1.0/27`    | 32         |                                     |
|      | Private     | `10.102.1.32/25`   | 128        |                                     |
|      | DB          | `10.102.1.160/27`  | 32         |                                     |
| c    | Public      | `10.102.2.0/27`    | 32         |                                     |
|      | Private     | `10.102.2.32/25`   | 128        |                                     |
|      | DB          | `10.102.2.160/27`  | 32         |                                     |
| spare| —           | `10.102.3.0/24`    | 256        | Reserved for future needs           |

---

### 🌐 Region 2 — `10.102.4.0/22`

| AZ   | Subnet Type | CIDR Block         | Size (IPs) | Purpose                            |
|------|-------------|--------------------|------------|-------------------------------------|
| a    | Public      | `10.102.4.0/27`    | 32         | NAT Gateway, Bastion, ALB           |
|      | Private     | `10.102.4.32/25`   | 128        | EC2 admin/ops tools                 |
|      | DB          | `10.102.4.160/27`  | 32         | RDS, internal config DB             |
| b    | Public      | `10.102.5.0/27`    | 32         |                                     |
|      | Private     | `10.102.5.32/25`   | 128        |                                     |
|      | DB          | `10.102.5.160/27`  | 32         |                                     |
| c    | Public      | `10.102.6.0/27`    | 32         |                                     |
|      | Private     | `10.102.6.32/25`   | 128        |                                     |
|      | DB          | `10.102.6.160/27`  | 32         |                                     |
| spare| —           | `10.102.7.0/24`    | 256        | Reserved for future needs           |

---

## **Prod Account**
- **CIDR**: `10.0.0.0/14`
  - **Region 1 (us-east-1)**: `10.0.0.0 – 10.1.255.255`
  - **Region 2 (us-west-1)**: `10.2.0.0 – 10.3.255.255`

  ### 🌐 Region 1 — `10.0.0.0/15`

| AZ   | Subnet Type | CIDR Block       | Size (IPs) | Description                         |
|------|-------------|------------------|------------|-------------------------------------|
| a    | Public      | `10.0.0.0/24`    | 256        | ALBs, NAT, ingress points           |
|      | Private     | `10.0.16.0/20`   | 4,096      | EKS nodes, EC2 services             |
|      | DB          | `10.0.32.0/26`   | 64         | RDS, ElastiCache, DMS, etc.         |
| b    | Public      | `10.0.64.0/24`   | 256        |                                     |
|      | Private     | `10.0.80.0/20`   | 4,096      |                                     |
|      | DB          | `10.0.96.0/26`   | 64         |                                     |
| c    | Public      | `10.0.128.0/24`  | 256        |                                     |
|      | Private     | `10.0.144.0/20`  | 4,096      |                                     |
|      | DB          | `10.0.160.0/26`  | 64         |                                     |
| spare| —           | `10.0.192.0/18`  | 16,384     | Reserved for future expansion       |

---

### 🌐 Region 2 — `10.2.0.0/15`

| AZ   | Subnet Type | CIDR Block       | Size (IPs) | Description                         |
|------|-------------|------------------|------------|-------------------------------------|
| a    | Public      | `10.2.0.0/24`    | 256        | ALBs, NAT, ingress points           |
|      | Private     | `10.2.16.0/20`   | 4,096      | EKS nodes, EC2 services             |
|      | DB          | `10.2.32.0/26`   | 64         | RDS, ElastiCache, DMS, etc.         |
| b    | Public      | `10.2.64.0/24`   | 256        |                                     |
|      | Private     | `10.2.80.0/20`   | 4,096      |                                     |
|      | DB          | `10.2.96.0/26`   | 64         |                                     |
| c    | Public      | `10.2.128.0/24`  | 256        |                                     |
|      | Private     | `10.2.144.0/20`  | 4,096      |                                     |
|      | DB          | `10.2.160.0/26`  | 64         |                                     |
| spare| —           | `10.2.192.0/18`  | 16,384     | Reserved for future expansion       |

---

## **Staging Account**
- **CIDR**: `10.4.0.0/14`
  - **Region 1 (us-east-1)**: `10.4.0.0 – 10.5.255.255`
  - **Region 2 (us-west-1)**: `10.6.0.0 – 10.7.255.255`

  ---

### 🌐 Region 1 — `10.4.0.0/15`

| AZ   | Subnet Type | CIDR Block       | Size (IPs) | Description                         |
|------|-------------|------------------|------------|-------------------------------------|
| a    | Public      | `10.4.0.0/24`    | 256        | NAT, ALB, bastion                   |
|      | Private     | `10.4.16.0/20`   | 4,096      | EKS nodes, EC2                      |
|      | DB          | `10.4.32.0/26`   | 64         | RDS, Redis, DMS, etc.               |
| b    | Public      | `10.4.64.0/24`   | 256        |                                     |
|      | Private     | `10.4.80.0/20`   | 4,096      |                                     |
|      | DB          | `10.4.96.0/26`   | 64         |                                     |
| c    | Public      | `10.4.128.0/24`  | 256        |                                     |
|      | Private     | `10.4.144.0/20`  | 4,096      |                                     |
|      | DB          | `10.4.160.0/26`  | 64         |                                     |
| spare| —           | `10.4.192.0/18`  | 16,384     | Reserved for future expansion       |

---

### 🌐 Region 2 — `10.6.0.0/15`

| AZ   | Subnet Type | CIDR Block       | Size (IPs) | Description                         |
|------|-------------|------------------|------------|-------------------------------------|
| a    | Public      | `10.6.0.0/24`    | 256        | NAT, ALB, bastion                   |
|      | Private     | `10.6.16.0/20`   | 4,096      | EKS nodes, EC2                      |
|      | DB          | `10.6.32.0/26`   | 64         | RDS, Redis, DMS, etc.               |
| b    | Public      | `10.6.64.0/24`   | 256        |                                     |
|      | Private     | `10.6.80.0/20`   | 4,096      |                                     |
|      | DB          | `10.6.96.0/26`   | 64         |                                     |
| c    | Public      | `10.6.128.0/24`  | 256        |                                     |
|      | Private     | `10.6.144.0/20`  | 4,096      |                                     |
|      | DB          | `10.6.160.0/26`  | 64         |                                     |
| spare| —           | `10.6.192.0/18`  | 16,384     | Reserved for future expansion       |

---

## **Dev Account**

- **CIDR**: `10.8.0.0/14`
  - **Region 1 (us-east-1)**: `10.8.0.0 – 10.9.255.255`
  - **Region 2 (us-west-1)**: `10.10.0.0 – 10.11.255.255`


### 🌐 Region 1 — `10.8.0.0/15`

| AZ   | Subnet Type | CIDR Block       | Size (IPs) | Description                       |
|------|-------------|------------------|------------|-----------------------------------|
| a    | Public      | `10.8.0.0/24`    | 256        | NAT, ALB, bastion                 |
|      | Private     | `10.8.16.0/20`   | 4,096      | EKS nodes, EC2 services           |
|      | DB          | `10.8.32.0/26`   | 64         | RDS, Redis, DMS, etc.             |
| b    | Public      | `10.8.64.0/24`   | 256        |                                   |
|      | Private     | `10.8.80.0/20`   | 4,096      |                                   |
|      | DB          | `10.8.96.0/26`   | 64         |                                   |
| c    | Public      | `10.8.128.0/24`  | 256        |                                   |
|      | Private     | `10.8.144.0/20`  | 4,096      |                                   |
|      | DB          | `10.8.160.0/26`  | 64         |                                   |
| spare| —           | `10.8.192.0/18`  | 16,384     | Reserved for future expansion     |



### 🌐 Region 2 — `10.10.0.0/15`

| AZ   | Subnet Type | CIDR Block       | Size (IPs) | Description                       |
|------|-------------|------------------|------------|-----------------------------------|
| a    | Public      | `10.8.0.0/24`    | 256        | NAT, ALB, bastion                 |
|      | Private     | `10.8.16.0/20`   | 4,096      | EKS nodes, EC2 services           |
|      | DB          | `10.8.32.0/26`   | 64         | RDS, Redis, DMS, etc.             |
| b    | Public      | `10.8.64.0/24`   | 256        |                                   |
|      | Private     | `10.8.80.0/20`   | 4,096      |                                   |
|      | DB          | `10.8.96.0/26`   | 64         |                                   |
| c    | Public      | `10.8.128.0/24`  | 256        |                                   |
|      | Private     | `10.8.144.0/20`  | 4,096      |                                   |
|      | DB          | `10.8.160.0/26`  | 64         |                                   |
| spare| —           | `10.8.192.0/18`  | 16,384     | Reserved for future expansion     |

---



---

## **Test Account**
- **CIDR**: `10.12.0.0/14`
  - **Region 1 (us-east-1)**: `10.12.0.0 – 10.13.255.255`
  - **Region 2 (us-west-1)**: `10.14.0.0 – 10.15.255.255`

### 🟦 Region 1 — `10.12.0.0/15`

| AZ   | Subnet Type | CIDR Block        | Size (IPs) | Description                       |
|------|-------------|-------------------|------------|-----------------------------------|
| a    | Public      | `10.12.0.0/24`    | 256        | NAT, ALB, bastion                 |
|      | Private     | `10.12.16.0/20`   | 4,096      | EKS nodes, EC2 services           |
|      | DB          | `10.12.32.0/26`   | 64         | RDS, Redis, DMS, etc.             |
| b    | Public      | `10.12.64.0/24`   | 256        |                                   |
|      | Private     | `10.12.80.0/20`   | 4,096      |                                   |
|      | DB          | `10.12.96.0/26`   | 64         |                                   |
| c    | Public      | `10.12.128.0/24`  | 256        |                                   |
|      | Private     | `10.12.144.0/20`  | 4,096      |                                   |
|      | DB          | `10.12.160.0/26`  | 64         |                                   |
| spare| —           | `10.12.192.0/18`  | 16,384     | Reserved for future expansion     |



### 🟨 Region 2 — `10.14.0.0/15`

| AZ   | Subnet Type | CIDR Block        | Size (IPs) | Description                       |
|------|-------------|-------------------|------------|-----------------------------------|
| a    | Public      | `10.14.0.0/24`    | 256        | NAT, ALB, bastion                 |
|      | Private     | `10.14.16.0/20`   | 4,096      | EKS nodes, EC2 services           |
|      | DB          | `10.14.32.0/26`   | 64         | RDS, Redis, DMS, etc.             |
| b    | Public      | `10.14.64.0/24`   | 256        |                                   |
|      | Private     | `10.14.80.0/20`   | 4,096      |                                   |
|      | DB          | `10.14.96.0/26`   | 64         |                                   |
| c    | Public      | `10.14.128.0/24`  | 256        |                                   |
|      | Private     | `10.14.144.0/20`  | 4,096      |                                   |
|      | DB          | `10.14.160.0/26`  | 64         |                                   |
| spare| —           | `10.14.192.0/18`  | 16,384     | Reserved for future expansion     |




For Cross account we will setup network account for the transit gateway account cross connections

# Network Account Plan (Transit Gateway)

## Purpose

The **Network Account** is dedicated to managing centralized networking infrastructure across all AWS accounts. This includes hosting the **Transit Gateway (TGW)** for cross-account and cross-region VPC connectivity.

---

## CIDR Allocation

## **Network Account**
- **CIDR**: `10.16.0.0/14`
  - **Region 1 (us-east-1)**: `10.16.0.0 – 10.17.255.255`
  - **Region 2 (us-west-1)**: `10.18.0.0 – 10.19.255.255`

### 🌐 Region 1 — `10.16.0.0/15`

| AZ   | Subnet Type | CIDR Block        | Size (IPs) | Purpose                           |
|------|-------------|-------------------|------------|-----------------------------------|
| a    | Public      | `10.16.0.0/24`    | 256        | NAT Gateway, VPCe, IGW, TGW       |
|      | Private     | `10.16.16.0/24`   | 256        | TGW attachments, shared services  |
| b    | Public      | `10.16.32.0/24`   | 256        |                                   |
|      | Private     | `10.16.48.0/24`   | 256        |                                   |
| c    | Public      | `10.16.64.0/24`   | 256        |                                   |
|      | Private     | `10.16.80.0/24`   | 256        |                                   |
| spare| —           | `10.16.96.0/19`   | 8,192      | Reserved for future network infra |



### 🌐 Region 2 — `10.18.0.0/15`

| AZ   | Subnet Type | CIDR Block        | Size (IPs) | Purpose                           |
|------|-------------|-------------------|------------|-----------------------------------|
| a    | Public      | `10.18.0.0/24`    | 256        | NAT Gateway, VPCe, IGW, TGW       |
|      | Private     | `10.18.16.0/24`   | 256        | TGW attachments, shared services  |
| b    | Public      | `10.18.32.0/24`   | 256        |                                   |
|      | Private     | `10.18.48.0/24`   | 256        |                                   |
| c    | Public      | `10.18.64.0/24`   | 256        |                                   |
|      | Private     | `10.18.80.0/24`   | 256        |                                   |
| spare| —           | `10.18.96.0/19`   | 8,192      | Reserved for future network infra |


o
---

## Services Hosted

- Transit Gateway (TGW) with VPC attachments from all other accounts
- NAT Gateways (optional)
- VPC Endpoints (S3, DynamoDB, etc.)
- Route 53 Resolver for centralized DNS
- CloudWatch metrics forwarding
- VPC Flow Logs to centralized S3
- Optional interface endpoints for shared tools

---

## Best Practices

- Deploy TGW attachments in 3 AZs for high availability
- Use separate route tables per attachment or environment
- Apply strict NACLs and Security Groups
- Enable flow logging for traffic visibility
- Consistently tag all resources (`Environment`, `Owner`, `Purpose`, etc.)


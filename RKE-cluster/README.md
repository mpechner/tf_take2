# RKE2 Terraform Modules

There are 2 Terraform modules to create an RKE2 cluster:
- `modules/server` - RKE2 server (control plane) nodes
- `modules/agent` - RKE2 agent (worker) nodes

## Container Registry Configuration

Each node runs an `ecr-login.sh` script (refreshed every 6 hours via cron) that writes `/etc/rancher/rke2/registries.yaml`. Three options are available and can be combined independently.

### Option 1: Default — ECR auth only (no extra variables needed)

The EC2 nodes have `AmazonEC2ContainerRegistryPullOnly` attached via IAM instance profile. The ECR login script authenticates to your private ECR registry automatically. No variables need to be set.

### Option 2: Docker Hub credentials (avoids rate limits)

Store credentials in AWS Secrets Manager as JSON with keys `user` and `token`:

```bash
aws secretsmanager create-secret \
  --name "admin/dockerhub" \
  --secret-string '{"user":"myuser","token":"dckr_pat_..."}' \
  --region us-west-2
```

Then pass the ARN:

```hcl
dockerhub_secret_arn = "arn:aws:secretsmanager:us-west-2:123456789:secret:admin/dockerhub-Xxxxx"
```

The script fetches the credentials at runtime and appends an `index.docker.io` auth entry to `registries.yaml`.

### Option 3: Alternate registry mirror (e.g. ECR pull-through cache)

Redirects all `docker.io` pulls through a mirror endpoint:

```hcl
registry_mirror = "123456789.dkr.ecr.us-west-2.amazonaws.com/docker-hub"
```

The existing ECR token covers authentication to the pull-through cache — no Docker Hub credentials are needed when using this option.

### Combining options

| Scenario | Variables to set |
|---|---|
| ECR private registry only | _(nothing)_ |
| Docker Hub credentials | `dockerhub_secret_arn` |
| ECR pull-through cache mirror | `registry_mirror` |
| Mirror + Docker Hub auth | both (though mirror alone is usually sufficient) |

### Note: Bitnami images

**Free Bitnami images** (e.g. `bitnami/postgresql`) are hosted on Docker Hub under the `bitnami/` namespace. These are covered by Option 2 — a Docker Hub token is all that's needed.

**Paid Bitnami subscription** (hardened/FIPS images) are hosted at `registry.bitnami.com` with separate credentials. This is not currently wired up. If needed in the future, it would follow the same pattern as Option 2: store the credentials in Secrets Manager and add a `registry.bitnami.com` auth entry to `registries.yaml` alongside the existing entries. Bitnami's paid registry uses a username/password pair (not a token), both of which would be stored in the secret.

These variables are set on the root `RKE/` module and propagate to both server and agent nodes automatically.

## ECR Authentication (pod-level via IRSA)

This cluster does NOT include the `ecr-credential-provider` binary by default (see [GitHub discussion #7691](https://github.com/rancher/rke2/discussions/7691) for why). 

For ECR authentication, you have two options:

### Option 1: IAM Instance Profile (Node-Level Access)
The EC2 nodes already have `AmazonEC2ContainerRegistryPullOnly` policy attached via IAM instance profile. This allows ALL pods on the node to pull from ECR.

**Limitation**: This is node-level access - any pod on the node can pull any ECR image the node has access to.

### Option 2: IRSA - IAM Roles for Service Accounts (Pod-Level Access) - RECOMMENDED

IRSA allows fine-grained access control where specific service accounts can assume specific IAM roles.

#### Step 1: Create OIDC Provider for the Cluster

Since RKE2 is self-managed (not EKS), you need to set up OIDC manually:

```bash
# 1. Generate a signing keypair for the cluster
openssl genrsa -out sa-signer.key 2048
openssl rsa -in sa-signer.key -pubout -out sa-signer.pub

# 2. Create a self-signed OIDC discovery document
# You'll need to host this on S3 or a public HTTPS endpoint

# 3. Create the OIDC provider in AWS
aws iam create-open-id-connect-provider \
  --url https://s3.amazonaws.com/YOUR_BUCKET/oidc \
  --thumbprint-list $(curl -s https://s3.amazonaws.com/YOUR_BUCKET/oidc/.well-known/openid-configuration | openssl x509 -fingerprint -noout -sha1 | cut -d= -f2 | tr -d ':') \
  --client-id-list sts.amazonaws.com
```

**Alternative**: Use `eksctl` with a fake EKS cluster name, or use a tool like [aws-pod-identity-webhook](https://github.com/aws/amazon-eks-pod-identity-webhook) configured for RKE2.

#### Step 2: Configure RKE2 for IRSA

Add these kubelet args to your RKE2 config (`/etc/rancher/rke2/config.yaml`):

```yaml
kubelet-arg:
  - "service-account-issuer=https://s3.amazonaws.com/YOUR_BUCKET/oidc"
  - "service-account-signing-key-file=/etc/rancher/rke2/sa-signer.key"
  - "service-account-key-file=/etc/rancher/rke2/sa-signer.pub"
  - "api-audiences=sts.amazonaws.com"
```

Upload the `sa-signer.pub` to your OIDC S3 bucket at `.well-known/openid-configuration`.

#### Step 3: Install AWS Pod Identity Webhook

```bash
# Deploy the webhook
kubectl apply -k "github.com/aws/amazon-eks-pod-identity-webhook/deploy?ref=master"

# Create the service account annotation secret
kubectl create serviceaccount pod-identity-webhook -n kube-system

# Configure the webhook with your OIDC issuer
kubectl set env deployment/pod-identity-webhook -n kube-system \
  AWS_DEFAULT_REGION=us-west-2 \
  AUDIENCE=sts.amazonaws.com
```

#### Step 4: Create IAM Role for ECR Access

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/s3.amazonaws.com/YOUR_BUCKET/oidc"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "s3.amazonaws.com/YOUR_BUCKET/oidc:sub": "system:serviceaccount:YOUR_NAMESPACE:YOUR_SERVICEACCOUNT"
        }
      }
    }
  ]
}
```

Attach this policy to the role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "arn:aws:ecr:us-west-2:YOUR_ACCOUNT_ID:repository/YOUR_REPO"
    }
  ]
}
```

#### Step 5: Annotate Service Account

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::YOUR_ACCOUNT_ID:role/YOUR_ECR_ROLE
```

#### Step 6: Use in Your Pod

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      serviceAccountName: my-app
      containers:
        - name: app
          image: YOUR_ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com/my-repo:latest
```

### Option 3: Static Credentials in registries.yaml (Not Recommended)

For a simpler but less secure approach, configure ECR credentials directly:

```yaml
# /etc/rancher/rke2/registries.yaml
configs:
  "123456789.dkr.ecr.us-west-2.amazonaws.com":
    auth:
      username: AWS
      password: $(aws ecr get-login-password --region us-west-2)
```

**Note**: This requires AWS CLI to be configured on nodes and credentials will be static.

## References

- [RKE2 Private Registry Configuration](https://docs.rke2.io/install/private_registry)
- [AWS Pod Identity Webhook](https://github.com/aws/amazon-eks-pod-identity-webhook)
- [IRSA for Self-Managed Clusters](https://blog.kubernauts.io/iam-roles-for-service-accounts-in-self-managed-kubernetes-clusters-on-aws-7ab6b8d76c42)
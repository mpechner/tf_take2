# RKE2 Terraform Modules

There are 2 Terraform modules to create an RKE2 cluster:
- `modules/server` - RKE2 server (control plane) nodes
- `modules/agent` - RKE2 agent (worker) nodes

## ECR Authentication

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
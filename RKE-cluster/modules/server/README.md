# RKE Server Module

This Terraform module configures existing EC2 instances as RKE (Rancher Kubernetes Engine) server (control plane) nodes using Ansible for automated provisioning.

## Features

- **Existing Instance Support**: Works with pre-existing EC2 instances that have Ansible installed
- **Ansible Integration**: Uses Ansible playbooks to configure RKE server nodes
- **Dynamic Discovery**: Automatically discovers server nodes based on naming patterns
- **Comprehensive Configuration**: Installs and configures Docker, RKE, and all required dependencies
- **Cluster Initialization**: Automatically initializes the Kubernetes cluster
- **Security**: Implements proper security groups and IAM roles for RKE server nodes
- **High Availability**: Supports multi-node control plane configuration

## Prerequisites

- Terraform >= 1.0
- Ansible >= 2.12
- AWS CLI configured with appropriate permissions
- SSH key pair for accessing EC2 instances
- Existing EC2 instances with Ansible installed
- EC2 instances should be tagged with `Name: {cluster_name}-rke-server*` pattern

## Required Ansible Collections

Install the required Ansible collections:

```bash
ansible-galaxy collection install amazon.aws
ansible-galaxy collection install community.general
```

Or install from the requirements file:

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
```

### Quick Setup

Use the provided setup script to automatically install Ansible collections:

```bash
./scripts/setup-ansible.sh
```

## Usage

### Basic Usage

```hcl
module "rke_servers" {
  source = "./modules/server"

  cluster_name = "my-rke-cluster"
  vpc_id       = "vpc-12345678"
  subnet_ids   = ["subnet-12345678", "subnet-87654321"]
  key_name     = "my-ssh-key"
  
  # Ensure your existing instances are tagged with: Name = "my-rke-cluster-rke-server*"
  
  ssh_cidr_blocks = ["10.0.0.0/8"]
  cluster_cidr_blocks = ["10.0.0.0/8"]
  
  tags = {
    Environment = "production"
    Project     = "rke-cluster"
  }
}
```

### Advanced Usage

```hcl
module "rke_servers" {
  source = "./modules/server"

  cluster_name = "my-rke-cluster"
  vpc_id       = "vpc-12345678"
  subnet_ids   = ["subnet-12345678", "subnet-87654321"]
  key_name     = "my-ssh-key"
  
  # Ensure your existing instances are tagged with: Name = "my-rke-cluster-rke-server*"
  
  ssh_cidr_blocks     = ["10.0.0.0/8", "192.168.1.0/24"]
  cluster_cidr_blocks = ["10.0.0.0/8"]
  
  docker_version = "20.10"
  rke_version    = "v1.4.0"
  kubernetes_version = "v1.24.10-rke2r1"
  
  etcd_backup_enabled = true
  etcd_backup_retention = 7
  
  network_plugin = "flannel"
  service_cluster_ip_range = "10.43.0.0/16"
  cluster_dns_service = "10.43.0.10"
  
  pod_security_policy = false
  audit_log_enabled = true
  
  ansible_user = "ec2-user"
  ansible_ssh_private_key_file = "~/.ssh/my-key.pem"
  
  aws_region = "us-west-2"
  
  tags = {
    Environment = "production"
    Project     = "rke-cluster"
    Owner       = "devops-team"
  }
}
```

## 🏗️ Module Structure

The module uses Terraform templates to generate all Ansible files dynamically:

```
RKE-cluster/modules/server/
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── README.md                  # Comprehensive documentation
├── templates/
│   ├── ansible-playbook.yml.tftpl      # Ansible playbook template
│   ├── ansible-inventory.ini.tftpl     # Ansible inventory template
│   ├── rke-server-config.yml.tftpl     # RKE config template
│   ├── rke-server.service.tftpl        # Systemd service template
│   └── init-cluster.sh.tftpl           # Cluster init script template
├── ansible/
│   ├── requirements.yml       # Ansible collection requirements
│   └── templates/             # Generated Ansible templates
├── scripts/
│   └── setup-ansible.sh       # Setup script for Ansible
└── example/
    └── main.tf               # Usage example
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the RKE cluster | `string` | n/a | yes |
| vpc_id | VPC ID where the RKE server nodes are located | `string` | n/a | yes |
| subnet_ids | List of subnet IDs where RKE server nodes are located | `list(string)` | n/a | yes |
| key_name | Name of the SSH key pair to use for RKE server nodes | `string` | n/a | yes |
| server_count | Number of RKE server nodes to configure (for reference only) | `number` | `3` | no |
| ssh_cidr_blocks | CIDR blocks allowed to SSH to RKE server nodes | `list(string)` | `["0.0.0.0/0"]` | no |
| cluster_cidr_blocks | CIDR blocks for cluster internal communication | `list(string)` | `["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]` | no |
| associate_public_ip | Whether to associate public IP addresses with RKE server nodes | `bool` | `false` | no |
| target_group_arns | List of target group ARNs to attach to the Auto Scaling Group | `list(string)` | `[]` | no |
| aws_region | AWS region where resources will be created | `string` | `"us-west-2"` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |
| docker_version | Docker version to install on RKE server nodes | `string` | `"20.10"` | no |
| rke_version | RKE version to use for server configuration | `string` | `"v1.4.0"` | no |
| kubernetes_version | Kubernetes version to install | `string` | `"v1.24.10-rke2r1"` | no |
| ansible_user | Ansible user to connect to the instances | `string` | `"ec2-user"` | no |
| ansible_ssh_private_key_file | Path to the SSH private key file for Ansible | `string` | `"~/.ssh/id_rsa"` | no |
| etcd_backup_enabled | Whether to enable etcd backup | `bool` | `true` | no |
| etcd_backup_retention | Number of etcd backups to retain | `number` | `5` | no |
| network_plugin | Network plugin to use (flannel, calico, canal) | `string` | `"flannel"` | no |
| service_cluster_ip_range | Kubernetes service cluster IP range | `string` | `"10.43.0.0/16"` | no |
| cluster_dns_service | Kubernetes cluster DNS service IP | `string` | `"10.43.0.10"` | no |
| pod_security_policy | Whether to enable pod security policy | `bool` | `false` | no |
| audit_log_enabled | Whether to enable audit logging | `bool` | `false` | no |
| audit_log_max_age | Maximum age of audit log files in days | `number` | `30` | no |
| audit_log_max_backup | Maximum number of audit log backup files | `number` | `10` | no |
| audit_log_max_size | Maximum size of audit log files in MB | `number` | `100` | no |

## Outputs

| Name | Description |
|------|-------------|
| security_group_id | ID of the security group created for RKE server nodes |
| iam_role_arn | ARN of the IAM role created for RKE server nodes |
| instance_profile_arn | ARN of the instance profile for RKE server nodes |
| kubeconfig_path | Path to the generated kubeconfig file |
| cluster_token | Token for joining nodes to the cluster |

## Ansible Playbook

The module includes an Ansible playbook that:

1. **Discovers Server Nodes**: Automatically finds EC2 instances with names starting with the cluster name and "rke-server"
2. **Configures System**: Updates packages, installs Docker, and configures system parameters
3. **Sets Up RKE**: Downloads and configures RKE server binaries and services
4. **Initializes Cluster**: Creates and initializes the Kubernetes cluster on the first server node

### Instance Requirements

Before using this module, ensure your EC2 instances meet these requirements:

- **Ansible Installed**: Instances must have Ansible installed and configured
- **SSH Access**: SSH key-based authentication must be working
- **Proper Tagging**: Instances must be tagged with `Name: {cluster_name}-rke-server*`
- **Network Access**: Instances must have internet access for package installation
- **User Permissions**: The Ansible user must have sudo privileges
- **Minimum Resources**: Recommended 4GB RAM, 2 vCPUs for control plane nodes

### Template-Based Generation

All Ansible files are generated from Terraform templates, providing:

- **Dynamic Configuration**: Variables are injected at runtime
- **Consistency**: All files use the same variable values
- **Flexibility**: Easy to customize without editing static files
- **Version Control**: Template changes are tracked in Terraform

### Manual Playbook Execution

You can run the Ansible playbook manually after Terraform generates the files:

```bash
cd ansible
ansible-playbook -i inventory.ini rke-server-playbook.yml \
  --extra-vars "cluster_name=my-cluster region=us-west-2"
```

## Security

The module implements several security measures:

- **Security Groups**: Restricts access to only necessary ports
- **IAM Roles**: Minimal permissions for EC2 instances
- **SSH Access Control**: Configurable CIDR blocks for SSH access
- **Private Networking**: Option to use private subnets only
- **RBAC**: Kubernetes RBAC enabled by default

## Networking

The module configures the following ports for RKE server nodes:

- **22**: SSH access
- **6443**: Kubernetes API server
- **10250**: Kubelet API
- **10251**: kube-scheduler
- **10252**: kube-controller-manager
- **10255**: Read-only kubelet port
- **2379-2380**: etcd client and peer communication
- **8472**: Canal/Flannel VXLAN overlay network
- **9099**: Canal/Flannel health check

## Cluster Management

### Accessing the Cluster

After successful deployment, you can access the cluster using:

```bash
# Copy kubeconfig from the first server node
scp ec2-user@<server-ip>:/opt/rke/kube_config_cluster.yml ./kubeconfig

# Set KUBECONFIG environment variable
export KUBECONFIG=./kubeconfig

# Verify cluster access
kubectl get nodes
```

### Adding Agent Nodes

To add agent nodes to the cluster:

1. Use the agent module to configure worker nodes
2. Copy the join token from the server node: `/opt/rke/join-token`
3. Use the token to join agent nodes to the cluster

## Troubleshooting

### Common Issues

1. **Ansible Connection Failures**: Ensure SSH key permissions are correct (600)
2. **Docker Installation Issues**: Check if the AMI supports Docker installation
3. **RKE Binary Download**: Verify internet connectivity and GitHub access
4. **Cluster Initialization Failures**: Check system resources and network connectivity
5. **etcd Issues**: Verify disk space and I/O performance

### Logs

- **Terraform**: Check Terraform logs for infrastructure issues
- **Ansible**: Use `-v` flag for verbose Ansible output
- **RKE Server**: Check `/var/log/rke-server.log` on server nodes
- **Kubernetes**: Check `/var/log/containers/` for container logs
- **System**: Check `/var/log/messages` for system-level issues

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This module is licensed under the MIT License. 
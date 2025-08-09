# RKE Agent Module

This Terraform module configures existing EC2 instances as RKE (Rancher Kubernetes Engine) agent nodes using Ansible for automated provisioning.

## Features

- **Existing Instance Support**: Works with pre-existing EC2 instances that have Ansible installed
- **Ansible Integration**: Uses Ansible playbooks to configure RKE agent nodes
- **Dynamic Discovery**: Automatically discovers agent nodes based on naming patterns
- **Comprehensive Configuration**: Installs and configures Docker, RKE, and all required dependencies
- **Security**: Implements proper security groups and IAM roles for RKE agent nodes

## Prerequisites

- Terraform >= 1.0
- Ansible >= 2.12
- AWS CLI configured with appropriate permissions
- SSH key pair for accessing EC2 instances
- Existing EC2 instances with Ansible installed
- EC2 instances should be tagged with `Name: {cluster_name}-rke-agent*` pattern

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
module "rke_agents" {
  source = "./modules/agent"

  cluster_name = "my-rke-cluster"
  vpc_id       = "vpc-12345678"
  subnet_ids   = ["subnet-12345678", "subnet-87654321"]
  key_name     = "my-ssh-key"
  
  # Ensure your existing instances are tagged with: Name = "my-rke-cluster-rke-agent-*"
  
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
module "rke_agents" {
  source = "./modules/agent"

  cluster_name = "my-rke-cluster"
  vpc_id       = "vpc-12345678"
  subnet_ids   = ["subnet-12345678", "subnet-87654321"]
  key_name     = "my-ssh-key"
  
  # Ensure your existing instances are tagged with: Name = "my-rke-cluster-rke-agent-*"
  
  ssh_cidr_blocks     = ["10.0.0.0/8", "192.168.1.0/24"]
  cluster_cidr_blocks = ["10.0.0.0/8"]
  
  associate_public_ip = false
  target_group_arns   = ["arn:aws:elasticloadbalancing:region:account:targetgroup/my-tg/1234567890123456"]
  
  docker_version = "20.10"
  rke_version    = "v1.4.0"
  
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

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the RKE cluster | `string` | n/a | yes |
| vpc_id | VPC ID where the RKE agent nodes will be deployed | `string` | n/a | yes |
| subnet_ids | List of subnet IDs where RKE agent nodes will be deployed | `list(string)` | n/a | yes |
| key_name | Name of the SSH key pair to use for RKE agent nodes | `string` | n/a | yes |
| agent_count | Number of RKE agent nodes to configure (for reference only) | `number` | `2` | no |
| ssh_cidr_blocks | CIDR blocks allowed to SSH to RKE agent nodes | `list(string)` | `["0.0.0.0/0"]` | no |
| cluster_cidr_blocks | CIDR blocks for cluster internal communication | `list(string)` | `["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]` | no |
| associate_public_ip | Whether to associate public IP addresses with RKE agent nodes | `bool` | `false` | no |
| target_group_arns | List of target group ARNs to attach to the Auto Scaling Group | `list(string)` | `[]` | no |
| aws_region | AWS region where resources will be created | `string` | `"us-west-2"` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |
| docker_version | Docker version to install on RKE agent nodes | `string` | `"20.10"` | no |
| rke_version | RKE version to use for agent configuration | `string` | `"v1.4.0"` | no |
| ansible_user | Ansible user to connect to the instances | `string` | `"ec2-user"` | no |
| ansible_ssh_private_key_file | Path to the SSH private key file for Ansible | `string` | `"~/.ssh/id_rsa"` | no |

## Outputs

| Name | Description |
|------|-------------|
| security_group_id | ID of the security group created for RKE agent nodes |
| iam_role_arn | ARN of the IAM role created for RKE agent nodes |
| launch_template_id | ID of the launch template created for RKE agent nodes |
| autoscaling_group_name | Name of the Auto Scaling Group for RKE agent nodes |
| autoscaling_group_arn | ARN of the Auto Scaling Group for RKE agent nodes |
| instance_profile_arn | ARN of the instance profile for RKE agent nodes |

## 🏗️ Module Structure

The module uses Terraform templates to generate all Ansible files dynamically:

```
RKE-cluster/modules/agent/
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── README.md                  # Comprehensive documentation
├── templates/
│   ├── ansible-playbook.yml.tftpl      # Ansible playbook template
│   ├── ansible-inventory.ini.tftpl     # Ansible inventory template
│   ├── rke-agent-config.yml.tftpl      # RKE config template
│   ├── rke-agent.service.tftpl         # Systemd service template
│   └── join-cluster.sh.tftpl           # Cluster join script template
├── ansible/
│   ├── requirements.yml       # Ansible collection requirements
│   └── templates/             # Generated Ansible templates
└── example/
    └── main.tf               # Usage example
```

## Ansible Playbook

The module includes an Ansible playbook that:

1. **Discovers Agent Nodes**: Automatically finds EC2 instances with names starting with the cluster name and "rke-agent"
2. **Configures System**: Updates packages, installs Docker, and configures system parameters
3. **Sets Up RKE**: Downloads and configures RKE agent binaries and services
4. **Prepares for Cluster Join**: Creates configuration files and join scripts

### Instance Requirements

Before using this module, ensure your EC2 instances meet these requirements:

- **Ansible Installed**: Instances must have Ansible installed and configured
- **SSH Access**: SSH key-based authentication must be working
- **Proper Tagging**: Instances must be tagged with `Name: {cluster_name}-rke-agent*`
- **Network Access**: Instances must have internet access for package installation
- **User Permissions**: The Ansible user must have sudo privileges

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
ansible-playbook -i inventory.ini rke-agent-playbook.yml \
  --extra-vars "cluster_name=my-cluster region=us-west-2"
```

## Security

The module implements several security measures:

- **Security Groups**: Restricts access to only necessary ports
- **IAM Roles**: Minimal permissions for EC2 instances
- **SSH Access Control**: Configurable CIDR blocks for SSH access
- **Private Networking**: Option to use private subnets only

## Networking

The module configures the following ports for RKE agent nodes:

- **22**: SSH access
- **6443**: Kubernetes API server
- **10250**: Kubelet API
- **2379-2380**: etcd client and peer communication
- **8472**: Canal/Flannel VXLAN overlay network
- **9099**: Canal/Flannel health check

## Troubleshooting

### Common Issues

1. **Ansible Connection Failures**: Ensure SSH key permissions are correct (600)
2. **Docker Installation Issues**: Check if the AMI supports Docker installation
3. **RKE Binary Download**: Verify internet connectivity and GitHub access
4. **Cluster Join Failures**: Ensure the join token is properly configured

### Logs

- **Terraform**: Check Terraform logs for infrastructure issues
- **Ansible**: Use `-v` flag for verbose Ansible output
- **RKE Agent**: Check `/var/log/rke-agent.log` on agent nodes
- **System**: Check `/var/log/user-data.log` for user data script execution

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This module is licensed under the MIT License. 
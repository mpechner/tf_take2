module "rks-nodes" {
  source      = "../modules/ec2"
  ec2_ssh_key = aws_key_pair.rke_ssh.key_name
  subnet_ids = data.aws_subnets.node_subnets.ids
  agent_hostnames = local.agent_hostnames
  agent_ami = data.aws_ami.ubuntu_2204.id
  agent_instance_type = "t3a.small"

  server_hostnames = local.server_hostnames
  server_ami = data.aws_ami.ubuntu_2204.id
  server_instance_type = "t3a.small"

}

module "rke-server"{
  source= "../modules/server"
  cluster_name = local.cluster_name
  vpc_id = data.aws_vpc.current.id
  subnet_ids = data.aws_subnets.node_subnets.ids
  key_name = aws_key_pair.rke_ssh.key_name
  ssh_cidr_blocks = local.node_subnet_cidrs
  cluster_cidr_blocks = local.rke_subnet_cidrs
  aws_region = var.aws_region
  server_instance_ips = module.rks-nodes.server_instance_ips
  ansible_user = "ubuntu"
  ansible_ssh_private_key_file = "~/.ssh/id_rsa"
  
  depends_on = [module.rks-nodes]
}

module "rke-agent" {
  source = "../modules/agent"
  cluster_name = local.cluster_name
  vpc_id = data.aws_vpc.current.id
  subnet_ids = data.aws_subnets.node_subnets.ids
  key_name = aws_key_pair.rke_ssh.key_name
  ssh_cidr_blocks = local.node_subnet_cidrs
  cluster_cidr_blocks = local.rke_subnet_cidrs
  aws_region = var.aws_region
  agent_instance_ips = module.rks-nodes.agent_instance_ips
  ansible_user = "ubuntu"
  ansible_ssh_private_key_file = "~/.ssh/id_rsa"
  
  depends_on = [module.rks-nodes]
}
# RKE Server Module - Main Configuration
# This module configures existing EC2 instances as RKE server (control plane) nodes using Ansible
# Note: Security groups are managed by the EC2 module, not here

# IAM role for RKE server nodes
resource "aws_iam_role" "rke_server" {
  name = "${var.cluster_name}-rke-server-role"

  assume_role_policy = file("${path.module}/policies/ec2-assume-role-policy.json")

  tags = var.tags
}

# IAM instance profile
resource "aws_iam_instance_profile" "rke_server" {
  name = "${var.cluster_name}-rke-server-profile"
  role = aws_iam_role.rke_server.name
}

# Create Ansible inventory file from template
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/ansible-inventory.ini.tftpl", {
    ansible_user                 = var.ansible_user
    ansible_ssh_private_key_file = var.ansible_ssh_private_key_file
    server_instance_ips          = var.server_instance_ips
  })
  filename = "${path.module}/ansible/inventory.ini"
}

# Create Ansible playbook from template
resource "local_file" "ansible_playbook" {
  content = templatefile("${path.module}/templates/ansible-playbook.yml.tftpl", {
    cluster_name                 = var.cluster_name
    aws_region                   = var.aws_region
    aws_account_id               = data.aws_caller_identity.current.account_id
    ansible_user                 = var.ansible_user
    ansible_ssh_private_key_file = var.ansible_ssh_private_key_file
    docker_version               = var.docker_version
    rke_version                  = var.rke_version
    rke2_version                 = var.rke2_version
    awscli_version               = var.awscli_version
    kubernetes_version           = var.kubernetes_version
    etcd_backup_enabled          = var.etcd_backup_enabled
    etcd_backup_retention        = var.etcd_backup_retention
    server_instance_ips          = var.server_instance_ips
  })
  filename = "${path.module}/ansible/rke-server-playbook.yml"
}

# Create Ansible template files
resource "local_file" "rke_server_config_template" {
  content = templatefile("${path.module}/templates/rke-server-config.yml.tftpl", {
    cluster_name                 = var.cluster_name
    docker_version               = var.docker_version
    kubernetes_version           = var.kubernetes_version
    etcd_backup_enabled          = var.etcd_backup_enabled
    etcd_backup_retention        = var.etcd_backup_retention
    network_plugin               = var.network_plugin
    service_cluster_ip_range     = var.service_cluster_ip_range
    pod_security_policy          = var.pod_security_policy
    audit_log_enabled            = var.audit_log_enabled
    audit_log_max_age            = var.audit_log_max_age
    audit_log_max_backup         = var.audit_log_max_backup
    audit_log_max_size           = var.audit_log_max_size
    cluster_dns_service          = var.cluster_dns_service
    node_ip                      = "{{ ansible_default_ipv4.address }}"
    ansible_user                 = var.ansible_user
    ansible_ssh_private_key_file = var.ansible_ssh_private_key_file
  })
  filename = "${path.module}/ansible/templates/rke-server-config.yml.j2"
}

resource "local_file" "rke_server_service_template" {
  content = templatefile("${path.module}/templates/rke-server.service.tftpl", {
    ansible_user = var.ansible_user
  })
  filename = "${path.module}/ansible/templates/rke-server.service.j2"
}

resource "local_file" "cluster_init_script_template" {
  content = templatefile("${path.module}/templates/init-cluster.sh.tftpl", {
    cluster_name = var.cluster_name
    ansible_user = var.ansible_user
    aws_region   = var.aws_region
  })
  filename = "${path.module}/ansible/templates/init-cluster.sh.j2"
}

# Note: Ansible provisioning should be run separately after Terraform creates the infrastructure
# The server module creates the necessary files and infrastructure, but Ansible execution
# should be handled manually or through a separate CI/CD pipeline

# Bootstrap the first server node (index 0). All other servers must wait for this to complete.
resource "null_resource" "ansible_provision_primary" {
  depends_on = [
    local_file.ansible_inventory,
    local_file.ansible_playbook,
    local_file.rke_server_config_template,
    local_file.rke_server_service_template,
    local_file.cluster_init_script_template,
  ]

  triggers = {
    cluster_name           = var.cluster_name
    docker_version         = var.docker_version
    rke_version            = var.rke_version
    rke2_version           = var.rke2_version
    awscli_version         = var.awscli_version
    kubernetes_version     = var.kubernetes_version
    instance_ip            = var.server_instance_ips[0]
    playbook_template_hash = filesha256("${path.module}/templates/ansible-playbook.yml.tftpl")
    ssh_user               = var.ansible_user
    ssh_key_file           = var.ansible_ssh_private_key_file
    dockerhub_secret_arn   = var.dockerhub_secret_arn
    registry_mirror        = var.registry_mirror
  }

  provisioner "file" {
    source      = "${path.module}/ansible/"
    destination = "/home/${var.ansible_user}/ansible-playbook"

    connection {
      type        = "ssh"
      user        = var.ansible_user
      private_key = file(var.ansible_ssh_private_key_file)
      host        = var.server_instance_ips[0]
    }
  }

  provisioner "remote-exec" {
    inline = [
      "for i in $(seq 1 30); do if command -v ansible-playbook >/dev/null 2>&1; then break; fi; sleep 5; done",
      "sudo pip3 install --no-cache-dir --upgrade 'boto3>=1.34.0' 'botocore>=1.34.0' || true",
      "cd /home/${var.ansible_user}/ansible-playbook",
      "ls -la",
      "for a in 1 2 3 4 5; do ansible-galaxy collection install -r requirements.yml --force && break; [ $a -eq 5 ] && { echo 'Ansible Galaxy unavailable after 5 attempts. Re-run apply later.'; exit 1; }; echo \"Galaxy attempt $a failed, retrying in 15s...\"; sleep 15; done",
      "test -f rke-server-playbook.yml || { echo 'missing rke-server-playbook.yml in $(pwd)'; exit 1; }",
      "ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3 ansible-playbook -i 'localhost,' -c local rke-server-playbook.yml --extra-vars 'cluster_name=${var.cluster_name} region=${var.aws_region} ansible_user=${var.ansible_user} dockerhub_secret_arn=${var.dockerhub_secret_arn} registry_mirror=${var.registry_mirror}'"
    ]

    connection {
      type        = "ssh"
      user        = var.ansible_user
      private_key = file(var.ansible_ssh_private_key_file)
      host        = var.server_instance_ips[0]
    }
  }

  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    inline = [
      "echo 'Uninstalling RKE2 server...'",
      "sudo -n systemctl stop rke2-server 2>/dev/null || true",
      "sudo -n /usr/local/bin/rke2-uninstall.sh 2>/dev/null || true",
      "sudo -n rm -rf /etc/rancher/rke2 /var/lib/rancher/rke2 2>/dev/null || true",
      "echo 'RKE2 server uninstalled (or skipped)'"
    ]

    connection {
      type        = "ssh"
      user        = self.triggers.ssh_user
      private_key = file(self.triggers.ssh_key_file)
      host        = self.triggers.instance_ip
    }
  }

  # Consolidated post-bootstrap health check — runs in a SINGLE SSH session to
  # eliminate reconnection gaps where the API could be transiently down.
  # Waits for node Ready status (not just API responding) to survive the etcd
  # bootstrap window where the API is briefly up then crashes.
  provisioner "remote-exec" {
    inline = [
      "echo '=== Phase 1: Waiting for kubectl binary ==='",
      "for i in $(seq 1 60); do sudo -n test -x ${var.rke2_kubectl_path} && break; sleep 2; done",
      "sudo -n test -x ${var.rke2_kubectl_path} || { echo 'FATAL: kubectl not found at ${var.rke2_kubectl_path}'; exit 1; }",

      "echo '=== Phase 2: Waiting for node Ready status (up to 10 minutes) ==='",
      "KC='sudo -n ${var.rke2_kubectl_path} --kubeconfig=/etc/rancher/rke2/rke2.yaml'; READY=0; for i in $(seq 1 60); do STATUS=$($KC get nodes --no-headers 2>/dev/null || echo ''); if echo \"$STATUS\" | grep -qw Ready && ! echo \"$STATUS\" | grep -qw NotReady; then echo \"Node is Ready after $((i*10))s\"; READY=1; break; fi; echo \"attempt $i/60 - status: $STATUS\"; sleep 10; done; [ $READY -eq 1 ] || { echo 'FATAL: Node not Ready after 10 minutes'; $KC get nodes -o wide 2>&1 || true; $KC get pods -n kube-system 2>&1 || true; exit 1; }",

      "echo '=== Phase 3: Waiting for CNI (Canal) pods ==='",
      "sudo -n ${var.rke2_kubectl_path} --kubeconfig=/etc/rancher/rke2/rke2.yaml wait --for=condition=Ready pod -l k8s-app=canal -n kube-system --timeout=300s || { echo 'Warning: CNI pods not ready after 5 minutes'; sudo -n ${var.rke2_kubectl_path} --kubeconfig=/etc/rancher/rke2/rke2.yaml get pods -n kube-system -l k8s-app=canal 2>&1 || true; }",

      "echo '=== Phase 4: Waiting for control plane node condition ==='",
      "sudo -n ${var.rke2_kubectl_path} --kubeconfig=/etc/rancher/rke2/rke2.yaml wait --for=condition=Ready node --selector=node-role.kubernetes.io/control-plane=true --timeout=120s || echo 'Warning: control plane node not ready after 2 minutes'",

      "echo '=== Phase 5: Stability verification (5 checks over 60s) ==='",
      "KC='sudo -n ${var.rke2_kubectl_path} --kubeconfig=/etc/rancher/rke2/rke2.yaml'; for i in 1 2 3 4 5; do STATUS=$($KC get nodes --no-headers 2>/dev/null || echo ''); if echo \"$STATUS\" | grep -qw Ready && ! echo \"$STATUS\" | grep -qw NotReady; then echo \"Stability check $i/5 passed\"; else echo \"FATAL: Stability check $i/5 failed: $STATUS\"; $KC get nodes -o wide 2>&1 || true; exit 1; fi; [ $i -lt 5 ] && sleep 12; done",

      "echo '=== Primary server bootstrap complete ==='",
      "sudo -n ${var.rke2_kubectl_path} --kubeconfig=/etc/rancher/rke2/rke2.yaml get nodes -o wide"
    ]

    connection {
      type        = "ssh"
      user        = var.ansible_user
      private_key = file(var.ansible_ssh_private_key_file)
      host        = var.server_instance_ips[0]
    }
  }
}

# Join additional server nodes (index 1+) only after the primary server is fully bootstrapped.
resource "null_resource" "ansible_provision" {
  count = length(var.server_instance_ips) - 1

  # Critical: do not start until the primary server's API is confirmed ready
  depends_on = [
    null_resource.ansible_provision_primary,
    local_file.ansible_inventory,
    local_file.ansible_playbook,
  ]

  triggers = {
    cluster_name           = var.cluster_name
    docker_version         = var.docker_version
    rke_version            = var.rke_version
    rke2_version           = var.rke2_version
    awscli_version         = var.awscli_version
    kubernetes_version     = var.kubernetes_version
    instance_ip            = var.server_instance_ips[count.index + 1]
    playbook_template_hash = filesha256("${path.module}/templates/ansible-playbook.yml.tftpl")
    ssh_user               = var.ansible_user
    ssh_key_file           = var.ansible_ssh_private_key_file
    dockerhub_secret_arn   = var.dockerhub_secret_arn
    registry_mirror        = var.registry_mirror
  }

  provisioner "file" {
    source      = "${path.module}/ansible/"
    destination = "/home/${var.ansible_user}/ansible-playbook"

    connection {
      type        = "ssh"
      user        = var.ansible_user
      private_key = file(var.ansible_ssh_private_key_file)
      host        = var.server_instance_ips[count.index + 1]
    }
  }

  provisioner "remote-exec" {
    inline = [
      "for i in $(seq 1 30); do if command -v ansible-playbook >/dev/null 2>&1; then break; fi; sleep 5; done",
      "sudo pip3 install --no-cache-dir --upgrade 'boto3>=1.34.0' 'botocore>=1.34.0' || true",
      "cd /home/${var.ansible_user}/ansible-playbook",
      "ls -la",
      "for a in 1 2 3 4 5; do ansible-galaxy collection install -r requirements.yml --force && break; [ $a -eq 5 ] && { echo 'Ansible Galaxy unavailable after 5 attempts. Re-run apply later.'; exit 1; }; echo \"Galaxy attempt $a failed, retrying in 15s...\"; sleep 15; done",
      "test -f rke-server-playbook.yml || { echo 'missing rke-server-playbook.yml in $(pwd)'; exit 1; }",
      "ANSIBLE_PYTHON_INTERPRETER=/usr/bin/python3 ansible-playbook -i 'localhost,' -c local rke-server-playbook.yml --extra-vars 'cluster_name=${var.cluster_name} region=${var.aws_region} ansible_user=${var.ansible_user} dockerhub_secret_arn=${var.dockerhub_secret_arn} registry_mirror=${var.registry_mirror}'"
    ]

    connection {
      type        = "ssh"
      user        = var.ansible_user
      private_key = file(var.ansible_ssh_private_key_file)
      host        = var.server_instance_ips[count.index + 1]
    }
  }

  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    inline = [
      "echo 'Uninstalling RKE2 server...'",
      "sudo -n systemctl stop rke2-server 2>/dev/null || true",
      "sudo -n /usr/local/bin/rke2-uninstall.sh 2>/dev/null || true",
      "sudo -n rm -rf /etc/rancher/rke2 /var/lib/rancher/rke2 2>/dev/null || true",
      "echo 'RKE2 server uninstalled (or skipped)'"
    ]

    connection {
      type        = "ssh"
      user        = self.triggers.ssh_user
      private_key = file(self.triggers.ssh_key_file)
      host        = self.triggers.instance_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Additional server node provisioning complete'"
    ]

    connection {
      type        = "ssh"
      user        = var.ansible_user
      private_key = file(var.ansible_ssh_private_key_file)
      host        = var.server_instance_ips[count.index + 1]
    }
  }
} 
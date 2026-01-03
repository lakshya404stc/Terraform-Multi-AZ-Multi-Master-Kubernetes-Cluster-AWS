locals {
  all_nodes_list = concat(var.master_nodes, var.worker_nodes)

  all_nodes_map = {
    for idx, node in local.all_nodes_list :
    idx => node
  }
}

# # Network Load Balancer for HA Control Plane
# resource "aws_lb" "control_plane" {
#   name               = "${var.cluster_name}-cp-nlb"
#   internal           = true
#   load_balancer_type = "network"
#   subnets            = values(var.private_subnets)

#   enable_cross_zone_load_balancing = true

#   tags = {
#     Name    = "${var.cluster_name}-control-plane-lb"
#     Cluster = var.cluster_name
#   }
# }

# # Target Group for K8s API Server (port 6443)
# resource "aws_lb_target_group" "kube_apiserver" {
#   name     = "${var.cluster_name}-api-tg"
#   port     = 6443
#   protocol = "TCP"
#   vpc_id   = var.vpc_id

#   health_check {
#     protocol            = "TCP"
#     port                = 6443
#     interval            = 10
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#   }

#   tags = {
#     Name    = "${var.cluster_name}-apiserver-tg"
#     Cluster = var.cluster_name
#   }
# }

# Security Group for Bastion
resource "aws_security_group" "bastion" {
  name_prefix = "${var.cluster_name}-bastion-"
  vpc_id      = var.vpc_id
  description = "Security group for bastion host"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_cidrs
    description = "SSH from allowed IPs"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name    = "${var.cluster_name}-bastion-sg"
    Cluster = var.cluster_name
  }
}

# # Listener for API Server
# resource "aws_lb_listener" "kube_apiserver" {
#   load_balancer_arn = aws_lb.control_plane.arn
#   port              = 6443
#   protocol          = "TCP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.kube_apiserver.arn
#   }
# }

# # Attach master nodes to target group
# resource "aws_lb_target_group_attachment" "masters" {
#   count            = length(var.master_nodes)
#   target_group_arn = aws_lb_target_group.kube_apiserver.arn
#   target_id        = var.master_nodes[count.index].id
#   port             = 6443
# }

# Security Group for Master Nodes
resource "aws_security_group" "master" {
  name_prefix = "${var.cluster_name}-master-"
  vpc_id      = var.vpc_id
  description = "Security group for Kubernetes master nodes"

  # API Server
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Kubernetes API Server"
  }

  # etcd
  ingress {
    from_port = 2379
    to_port   = 2380
    protocol  = "tcp"
    self      = true
    description = "etcd server client API"
  }

  # Kubelet API
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Kubelet API"
  }

  # Kube Scheduler
  ingress {
    from_port = 10259
    to_port   = 10259
    protocol  = "tcp"
    self      = true
    description = "Kube Scheduler"
  }

  # Kube Controller Manager
  ingress {
    from_port = 10257
    to_port   = 10257
    protocol  = "tcp"
    self      = true
    description = "Kube Controller Manager"
  }

  # SSH from bastion
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
    description     = "SSH from bastion"
  }

  # All traffic between masters
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
    description = "All traffic between masters"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name    = "${var.cluster_name}-master-sg"
    Cluster = var.cluster_name
  }
}

# Security Group for Worker Nodes
resource "aws_security_group" "worker" {
  name_prefix = "${var.cluster_name}-worker-"
  vpc_id      = var.vpc_id
  description = "Security group for Kubernetes worker nodes"

  # Kubelet API
  ingress {
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_security_group.master.id]
    description     = "Kubelet API from masters"
  }

  # NodePort Services
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "NodePort Services"
  }

  # SSH from bastion
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
    description     = "SSH from bastion"
  }

  # Pod network (CNI)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
    description = "All traffic between workers"
  }

  # Allow traffic from masters
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.master.id]
    description     = "All traffic from masters"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name    = "${var.cluster_name}-worker-sg"
    Cluster = var.cluster_name
  }
}

# Attach security groups to instances
resource "aws_network_interface_sg_attachment" "master" {
  count                = length(var.master_nodes)
  security_group_id    = aws_security_group.master.id
  network_interface_id = var.master_nodes[count.index].primary_network_interface_id
}

resource "aws_network_interface_sg_attachment" "worker" {
  count                = length(var.worker_nodes)
  security_group_id    = aws_security_group.worker.id
  network_interface_id = var.worker_nodes[count.index].primary_network_interface_id
}

resource "aws_network_interface_sg_attachment" "bastion" {
  security_group_id    = aws_security_group.bastion.id
  network_interface_id = var.bastion_node.primary_network_interface_id
}

# null resource common setup
resource "null_resource" "common_setup" {
  for_each = local.all_nodes_map

  connection {
    type                = "ssh"
    user                = var.ssh_user
    private_key         = file(var.private_key_path)
    host                = each.value.private_ip
    bastion_host        = var.bastion_node.public_ip
    bastion_user        = var.ssh_user
    bastion_private_key = file(var.private_key_path)
  }

  provisioner "file" {
    source      = "${path.module}/scripts/common.sh"
    destination = "/tmp/common.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/common.sh",
      "sudo /tmp/common.sh"
    ]
  }

  triggers = {
    node_index = each.key
  }
}

# Null resource to bootstrap first master
resource "null_resource" "bootstrap_first_master" {
  depends_on = [
    # aws_lb.control_plane,
    null_resource.common_setup,
    aws_network_interface_sg_attachment.master
  ]

  connection {
    type                = "ssh"
    user                = var.ssh_user
    private_key         = file(var.private_key_path)
    host                = var.master_nodes[0].private_ip
    bastion_host        = var.bastion_node.public_ip
    bastion_user        = var.ssh_user
    bastion_private_key = file(var.private_key_path)
  }

  # Upload kubeadm config
  provisioner "file" {
    content = templatefile("${path.module}/templates/kubeadm-config.yaml.tpl", {
      control_plane_endpoint = var.master_nodes[0].private_ip
      pod_subnet             = var.pod_subnet_cidr
      service_subnet         = var.service_subnet_cidr
      kubernetes_version     = var.kubernetes_version
    })
    destination = "/tmp/kubeadm-config.yaml"
  }

  # Bootstrap script
  provisioner "file" {
    content = templatefile("${path.module}/scripts/bootstrap-master.sh", {
      kubernetes_version = var.kubernetes_version
      cni_plugin         = var.cni_plugin
      pod_subnet         = var.pod_subnet_cidr
    })
    destination = "/tmp/bootstrap-master.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/bootstrap-master.sh",
      "sudo /tmp/bootstrap-master.sh"
    ]
  }

  provisioner "local-exec" {
    command = <<-EOT
      ssh -o StrictHostKeyChecking=no \
          -o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=no ${var.ssh_user}@${var.bastion_node.public_ip} -i ${var.private_key_path}" \
          ${var.ssh_user}@${var.master_nodes[0].private_ip} -i ${var.private_key_path} \
          'sudo cat /etc/kubernetes/admin.conf' \
          | awk '{gsub(/server: https:\/\/[^:]*:6443/, "server: https://${var.master_nodes[0].private_ip}:6443"); print}' \
          > ${path.root}/kubeconfig-${var.cluster_name}.yaml
    EOT
  }

  triggers = {
    cluster_instance_ids = join(",", [for node in var.master_nodes : node.id])
  }
}

data "external" "join_command_master" {
  depends_on = [null_resource.bootstrap_first_master]

  program = ["bash", "-c", <<-EOT
    ssh -o StrictHostKeyChecking=no \
      -i ${var.private_key_path} \
      -J ${var.ssh_user}@${var.bastion_node.public_ip} \
      ${var.ssh_user}@${var.master_nodes[0].private_ip} \
      'cat /tmp/join-command-master.sh' | jq -Rs '{command: .}'
  EOT
  ]
}
data "external" "join_command_worker" {
  depends_on = [null_resource.bootstrap_first_master]

  program = ["bash", "-c", <<-EOT
    ssh -o StrictHostKeyChecking=no \
      -i ${var.private_key_path} \
      -J ${var.ssh_user}@${var.bastion_node.public_ip} \
      ${var.ssh_user}@${var.master_nodes[0].private_ip} \
      'cat /tmp/join-command-worker.sh' | jq -Rs '{command: .}'
  EOT
  ]
}

# Join additional masters
resource "null_resource" "join_masters" {
  count = length(var.master_nodes) - 1

  depends_on = [
    null_resource.bootstrap_first_master,
    data.external.join_command_master
  ]

  connection {
    type                = "ssh"
    user                = var.ssh_user
    private_key         = file(var.private_key_path)
    host                = var.master_nodes[count.index + 1].private_ip
    bastion_host        = var.bastion_node.public_ip
    bastion_user        = var.ssh_user
    bastion_private_key = file(var.private_key_path)
  }

  provisioner "file" {
    content     = data.external.join_command_master.result.command
    destination = "/tmp/join-command-master.sh"
  }

  provisioner "file" {
    content = templatefile("${path.module}/scripts/join-master.sh", {
      first_master_ip = var.master_nodes[0].private_ip
    })
    destination = "/tmp/join-master.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/join-master.sh",
      "sudo /tmp/join-master.sh"
    ]
  }
}

# Join worker nodes
resource "null_resource" "join_workers" {
  count = length(var.worker_nodes)

  depends_on = [
    null_resource.bootstrap_first_master,
    null_resource.join_masters,
    data.external.join_command_worker
  ]

  connection {
    type                = "ssh"
    user                = var.ssh_user
    private_key         = file(var.private_key_path)
    host                = var.worker_nodes[count.index].private_ip
    bastion_host        = var.bastion_node.public_ip
    bastion_user        = var.ssh_user
    bastion_private_key = file(var.private_key_path)
  }

  provisioner "file" {
    content     = data.external.join_command_worker.result.command
    destination = "/tmp/join-command-worker.sh"
  }

  provisioner "file" {
    content = templatefile("${path.module}/scripts/join-worker.sh", {
      first_master_ip = var.master_nodes[0].private_ip
    })
    destination = "/tmp/join-worker.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/join-worker.sh",
      "sudo /tmp/join-worker.sh"
    ]
  }
}
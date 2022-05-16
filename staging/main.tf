provider "aws" {
  region = "${var.aws_region}"
}

resource "aws_security_group" "microservices-demo-staging-k8s" {
  name        = "microservices-demo-staging-k8s"
  description = "allow all internal traffic, all traffic from bastion and http from anywhere"
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = "true"
  }
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = ["${var.bastion_security_group}"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    git_commit           = "ed1fed30e987977d5e6fd439fb309239bd364f64"
    git_file             = "staging/main.tf"
    git_last_modified_at = "2016-11-01 09:21:37"
    git_last_modified_by = "thijs.schnitger@container-solutions.com"
    git_modifiers        = "thijs.schnitger"
    git_org              = "fsengil-panw"
    git_repo             = "microservices-demo"
    yor_trace            = "ac637927-96e4-4c77-be9e-b84cbea62d8d"
  }
}

resource "aws_instance" "k8s-node" {
  depends_on      = ["aws_instance.k8s-master"]
  count           = "${var.nodecount}"
  instance_type   = "${var.node_instance_type}"
  ami             = "${lookup(var.aws_amis, var.aws_region)}"
  key_name        = "${var.key_name}"
  security_groups = ["${aws_security_group.microservices-demo-staging-k8s.name}"]
  tags {
    Name = "microservices-demo-staging-node"
  }

  root_block_device {
    volume_type = "gp2"
    volume_size = "50"
  }

  connection {
    user        = "${var.instance_user}"
    private_key = "${file("${var.private_key_file}")}"
    host        = "${self.private_ip}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo sh -c 'curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -'",
      "sudo sh -c 'echo deb http://apt.kubernetes.io/ kubernetes-xenial main > /etc/apt/sources.list.d/kubernetes.list'",
      "sudo apt-get update",
      "sudo apt-get install -y docker.io kubelet kubeadm kubectl kubernetes-cni"
    ]
  }

  provisioner "local-exec" {
    command = "ssh -i ${var.private_key_file} -o StrictHostKeyChecking=no ubuntu@${self.private_ip} sudo `cat join.cmd`"
  }

  tags = {
    git_commit           = "3ed133436e7787073d59fe519782eb2992bf8c3d"
    git_file             = "staging/main.tf"
    git_last_modified_at = "2017-05-15 12:10:51"
    git_last_modified_by = "vishal.lal@container-solutions.com"
    git_modifiers        = "alex.giurgiu/thijs.schnitger/vishal.lal"
    git_org              = "fsengil-panw"
    git_repo             = "microservices-demo"
    yor_trace            = "84f24d43-4e3a-4159-86ab-46f46b83acd5"
  }
}

resource "aws_instance" "k8s-master" {
  instance_type   = "${var.master_instance_type}"
  ami             = "${lookup(var.aws_amis, var.aws_region)}"
  key_name        = "${var.key_name}"
  security_groups = ["${aws_security_group.microservices-demo-staging-k8s.name}"]
  tags {
    Name = "microservices-demo-staging-master"
  }

  root_block_device {
    volume_type = "gp2"
    volume_size = "50"
  }

  connection {
    user        = "${var.instance_user}"
    private_key = "${file("${var.private_key_file}")}"
    host        = "${self.private_ip}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo sh -c 'curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -'",
      "sudo sh -c 'echo deb http://apt.kubernetes.io/ kubernetes-xenial main > /etc/apt/sources.list.d/kubernetes.list'",
      "sudo apt-get update",
      "sudo apt-get install -y docker.io kubelet kubeadm kubectl kubernetes-cni",
      "mkdir -p /home/ubuntu/microservices-demo/deploy/kubernetes/manifests"
    ]
  }

  provisioner "local-exec" {
    command = "ssh -i ${var.private_key_file} -o StrictHostKeyChecking=no ubuntu@${self.private_ip} sudo kubeadm init | grep -e --token > join.cmd"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo cp /etc/kubernetes/admin.conf ~/config",
      "sudo chown -R ubuntu ~/config"
    ]
  }

  provisioner "local-exec" {
    command = "scp -i ${var.private_key_file} -o StrictHostKeyChecking=no ubuntu@${self.private_ip}:~/config ~/.kube/"
  }
  tags = {
    git_commit           = "3ed133436e7787073d59fe519782eb2992bf8c3d"
    git_file             = "staging/main.tf"
    git_last_modified_at = "2017-05-15 12:10:51"
    git_last_modified_by = "vishal.lal@container-solutions.com"
    git_modifiers        = "alex.giurgiu/thijs.schnitger/vishal.lal/vlal"
    git_org              = "fsengil-panw"
    git_repo             = "microservices-demo"
    yor_trace            = "e9735f94-334e-450b-8a11-30b19c07aecf"
  }
}

resource "null_resource" "up" {
  depends_on = ["aws_instance.k8s-node"]
  provisioner "local-exec" {
    command = "./up.sh ${var.weave_cloud_token}"
  }
}

resource "aws_elb" "microservices-demo-staging-k8s" {
  depends_on         = ["aws_instance.k8s-node"]
  name               = "microservices-demo-staging-k8s"
  instances          = ["${aws_instance.k8s-node.*.id}"]
  availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  security_groups    = ["${aws_security_group.microservices-demo-staging-k8s.id}"]

  listener {
    lb_port           = 80
    instance_port     = 30001
    lb_protocol       = "http"
    instance_protocol = "http"
  }
  tags = {
    git_commit           = "5462c059174777fba4d70745f6eb37d6714cff2c"
    git_file             = "staging/main.tf"
    git_last_modified_at = "2017-01-10 21:42:08"
    git_last_modified_by = "vishal.lal@container-solutions.com"
    git_modifiers        = "vishal.lal/vlal"
    git_org              = "fsengil-panw"
    git_repo             = "microservices-demo"
    yor_trace            = "df89c136-2c06-4a0a-b267-6703e5b094f8"
  }
}

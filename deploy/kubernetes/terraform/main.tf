provider "aws" {
  region = "${var.aws_region}"
}

resource "aws_security_group" "k8s-security-group" {
  name        = "md-k8s-security-group"
  description = "allow all internal traffic, ssh, http from anywhere"
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = "true"
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9411
    to_port     = 9411
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 30001
    to_port     = 30001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 30002
    to_port     = 30002
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 31601
    to_port     = 31601
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
    git_commit           = "b34877c6e8b3779fae32c3274abd1a42f62d4051"
    git_file             = "deploy/kubernetes/terraform/main.tf"
    git_last_modified_at = "2016-12-16 10:02:19"
    git_last_modified_by = "alex.giurgiu@gmail.com"
    git_modifiers        = "alex.giurgiu/vishal"
    git_org              = "fsengil-panw"
    git_repo             = "microservices-demo"
    yor_trace            = "ffc3f7e8-151b-4f58-b77a-fc515fd56d84"
  }
}

resource "aws_instance" "ci-sockshop-k8s-master" {
  instance_type   = "${var.master_instance_type}"
  ami             = "${lookup(var.aws_amis, var.aws_region)}"
  key_name        = "${var.key_name}"
  security_groups = ["${aws_security_group.k8s-security-group.name}"]
  tags {
    Name = "ci-sockshop-k8s-master"
  }

  connection {
    user        = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
  }

  provisioner "file" {
    source      = "deploy/kubernetes/manifests"
    destination = "/tmp/"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -",
      "sudo echo \"deb http://apt.kubernetes.io/ kubernetes-xenial main\" | sudo tee --append /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update",
      "sudo apt-get install -y docker.io",
      "sudo apt-get install -y kubelet kubeadm kubectl kubernetes-cni"
    ]
  }
  tags = {
    git_commit           = "f8b4615f8849566e87fd2147c392337dc38a321a"
    git_file             = "deploy/kubernetes/terraform/main.tf"
    git_last_modified_at = "2017-02-02 09:55:42"
    git_last_modified_by = "alex.giurgiu@gmail.com"
    git_modifiers        = "alex.giurgiu/vishal"
    git_org              = "fsengil-panw"
    git_repo             = "microservices-demo"
    yor_trace            = "c3a99430-3082-4764-9424-ba09789f9270"
  }
}

resource "aws_instance" "ci-sockshop-k8s-node" {
  instance_type   = "${var.node_instance_type}"
  count           = "${var.node_count}"
  ami             = "${lookup(var.aws_amis, var.aws_region)}"
  key_name        = "${var.key_name}"
  security_groups = ["${aws_security_group.k8s-security-group.name}"]
  tags {
    Name = "ci-sockshop-k8s-node"
  }

  connection {
    user        = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -",
      "sudo echo \"deb http://apt.kubernetes.io/ kubernetes-xenial main\" | sudo tee --append /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update",
      "sudo apt-get install -y docker.io",
      "sudo apt-get install -y kubelet kubeadm kubectl kubernetes-cni",
      "sudo sysctl -w vm.max_map_count=262144"
    ]
  }
  tags = {
    git_commit           = "f8b4615f8849566e87fd2147c392337dc38a321a"
    git_file             = "deploy/kubernetes/terraform/main.tf"
    git_last_modified_at = "2017-02-02 09:55:42"
    git_last_modified_by = "alex.giurgiu@gmail.com"
    git_modifiers        = "alex.giurgiu/vishal"
    git_org              = "fsengil-panw"
    git_repo             = "microservices-demo"
    yor_trace            = "7e642e06-f7ed-46b1-94ea-c54864c0bdcc"
  }
}

resource "aws_elb" "ci-sockshop-k8s-elb" {
  depends_on         = ["aws_instance.ci-sockshop-k8s-node"]
  name               = "ci-sockshop-k8s-elb"
  instances          = ["${aws_instance.ci-sockshop-k8s-node.*.id}"]
  availability_zones = ["${data.aws_availability_zones.available.names}"]
  security_groups    = ["${aws_security_group.k8s-security-group.id}"]
  listener {
    lb_port           = 80
    instance_port     = 30001
    lb_protocol       = "http"
    instance_protocol = "http"
  }

  listener {
    lb_port           = 9411
    instance_port     = 30002
    lb_protocol       = "http"
    instance_protocol = "http"
  }

  tags = {
    git_commit           = "d24f8de7b6afac83ddfe9cb6a878764176b478bb"
    git_file             = "deploy/kubernetes/terraform/main.tf"
    git_last_modified_at = "2017-02-08 17:51:07"
    git_last_modified_by = "alex.giurgiu@gmail.com"
    git_modifiers        = "alex.giurgiu"
    git_org              = "fsengil-panw"
    git_repo             = "microservices-demo"
    yor_trace            = "8de84023-7883-42a8-b0a4-a79d7eaa4222"
  }
}


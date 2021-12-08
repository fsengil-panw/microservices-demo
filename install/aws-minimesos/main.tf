// This script expects the aws key and secret as variables. This is necessary because we need access to the aws varialbes during the provisioning step.
// e.g. terraform apply -var 'access_key=......' -var 'secret_key=......' .

// So, first run 'terraform get'
// Finally, run the plan and apply steps to create the cluster. You can also provide the aws credentials with environmental variables like: TF_VAR_access_keys...

resource "aws_instance" "minimesos" {

  count             = 1
  ami               = "${lookup(var.aws_amis, var.aws_region)}"
  availability_zone = "eu-west-1b"

  root_block_device {
    volume_size = 50
    volume_type = "gp2"
  }

  instance_type = "m4.xlarge"
  key_name      = "${var.aws_key_name}"
  subnet_id     = "${aws_subnet.terraform.id}"

  vpc_security_group_ids = [
  "${aws_security_group.terraform.id}"]

  tags {
    Name = "minimesos-${count.index}"
  }

  connection {
    user        = "ubuntu"
    private_key = "${var.private_key_file}"
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done"
    ]
  }
  provisioner "file" {
    source      = "provision.sh"
    destination = "/tmp/provision.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/provision.sh",
      "/tmp/provision.sh"
    ]
  }
  tags = {
    git_commit           = "e4de878ed59dcd318a39140f4484470be72213da"
    git_file             = "install/aws-minimesos/main.tf"
    git_last_modified_at = "2016-07-14 14:58:42"
    git_last_modified_by = "phil@winderresearch.com"
    git_modifiers        = "phil"
    git_org              = "fsengil-panw"
    git_repo             = "microservices-demo"
    yor_trace            = "2458d737-7a4d-4d4b-868d-1a76e1478cf8"
  }
}



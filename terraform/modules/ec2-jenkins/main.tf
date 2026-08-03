data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_subnet" "jenkins" {
  id = var.subnet_id
}

resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  key_name                    = var.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e
    hostnamectl set-hostname ${var.project_name}-jenkins
    apt-get update -y
    apt-get install -y python3
  EOF

  tags = merge(var.tags, {
    Name = "${var.project_name}-jenkins"
    Role = "jenkins"
  })
}

# Trwały dysk z jobami/credentials — przeżywa terraform destroy (przez skrypt pause).
resource "aws_ebs_volume" "jenkins_home" {
  count = var.jenkins_home_volume_id == "" ? 1 : 0

  availability_zone = data.aws_subnet.jenkins.availability_zone
  size              = var.jenkins_home_volume_size_gb
  type              = "gp3"
  encrypted         = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-jenkins-home"
    Role = "jenkins-data"
  })
}

locals {
  jenkins_home_volume_id = var.jenkins_home_volume_id != "" ? var.jenkins_home_volume_id : aws_ebs_volume.jenkins_home[0].id
}

resource "aws_volume_attachment" "jenkins_home" {
  device_name  = "/dev/sdf"
  volume_id    = local.jenkins_home_volume_id
  instance_id  = aws_instance.jenkins.id
  force_detach = true
}

resource "aws_eip" "jenkins" {
  instance = aws_instance.jenkins.id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project_name}-jenkins-eip"
  })
}

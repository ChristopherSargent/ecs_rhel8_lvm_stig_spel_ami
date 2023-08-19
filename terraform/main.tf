# Security Group
resource "aws_security_group" "default" {
  name        = "pg-rhel8-lvm-stig-spel-terraform-sg"
  description = "Used in the terraform"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.https_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 instance
resource "aws_instance" "pg-rhel8-lvm-stig-spel-terraform-ec2" {
  ami                         = var.ami_id
  associate_public_ip_address = true # Enable/disable pibluc IP
  availability_zone           = var.availability_zone
  enclave_options {
    enabled = false
  }

  get_password_data                    = false
  hibernation                          = false
  instance_initiated_shutdown_behavior = "stop"
  instance_type                        = var.instance_type
  ipv6_address_count                   = 0
  key_name                             = "alpha_key_pair"

  maintenance_options {
    auto_recovery = "default"
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = "1"
    http_tokens                 = "optional"
    instance_metadata_tags      = "disabled"
  }

  monitoring = true

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = "arn:aws-us-gov:kms:us-gov-west-1:036436800059:key/23051040-d05e-4080-99f6-bbd740bb1b14"
    volume_size           = 128
    volume_type           = "gp2"
  }

  source_dest_check = true
  subnet_id         = var.subnet_id
  tenancy                = "default"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]

  tags = var.tags
}

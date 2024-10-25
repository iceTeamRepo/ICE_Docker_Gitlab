data "aws_availability_zones" "main" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

resource "random_id" "name" {
  count = var.create ? 1 : 0

  byte_length = 4
  prefix      = "${var.name}-"
}


resource "aws_security_group" "bastion" {
  count = var.create ? 1 : 0

  name_prefix = "${var.name}-bastion-"
  description = "Security Group for ${var.name} Bastion hosts"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { "Name" = format("%s-bastion", var.name) })
}

resource "aws_security_group_rule" "ssh" {
  count = var.create ? 1 : 0

  security_group_id = aws_security_group.bastion[count.index].id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "http" {
  count = var.create ? 1 : 0

  security_group_id = aws_security_group.bastion[count.index].id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "https" {
  count = var.create ? 1 : 0

  security_group_id = aws_security_group.bastion[count.index].id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "openldap_secure" {
  count = var.create ? 1 : 0

  security_group_id = aws_security_group.bastion[count.index].id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 636
  to_port           = 636
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "openldap" {
  count = var.create ? 1 : 0

  security_group_id = aws_security_group.bastion[count.index].id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 389
  to_port           = 389
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "phpldapadmin" {
  count = var.create ? 1 : 0

  security_group_id = aws_security_group.bastion[count.index].id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 8090
  to_port           = 8090
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "egress_public" {
  count = var.create ? 1 : 0

  security_group_id = aws_security_group.bastion[count.index].id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

locals {
  bastion_name = format("bastion-%s", random_id.name[0].hex)
  user_data = templatefile("${path.module}/templates/userdata.sh.tpl", {
    domain         = var.domain
    traefik_domain = var.traefik_domain
  })
}

module "bastion_ec2_instance" {
  count   = var.create ? 1 : 0
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = " ~> 3.6.0"

  name = local.bastion_name

  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.instance_type
  key_name             = var.ssh_key_name
  iam_instance_profile = var.iam_instance_profile

  vpc_security_group_ids = aws_security_group.bastion.*.id
  subnet_id              = var.subnet_id
  user_data_base64       = base64encode(local.user_data)

  root_block_device = [
    {
      volume_size           = 60    # 볼륨 크기 (GB)
      volume_type           = "gp2" # 볼륨 타입 (예: gp2, io1 등)
      delete_on_termination = true  # 인스턴스 종료 시 볼륨 삭제 여부
      encrypted             = false # 볼륨 암호화 여부 
    }
  ]

  tags = var.tags
}

resource "local_file" "userdata" {
  count    = var.create ? 1 : 0
  content  = local.user_data
  filename = "${path.root}/debug/userdata.sh"
}


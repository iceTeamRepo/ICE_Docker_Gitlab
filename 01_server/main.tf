
locals {
  gitlab-bastion = {
    key_name             = "devops_tool_key"
    key_local_path       = "C://Key/devops_tool_key.pem"
    key_remote_copy_path = "/home/ec2-user/devops_tool_key.pem"
  }
}

module "gitlab-network" {
  source            = "./modules/terraform-aws-network"
  create            = true
  create_vpc        = true
  name              = var.gitlab_network_name
  vpc_cidr          = var.gitlab_network_vpc_cidr
  vpc_cidrs_public  = var.gitlab_network_vpc_cidrs_public
  nat_count         = var.gitlab_network_nat_count
  vpc_cidrs_private = var.gitlab_network_vpc_cidrs_private
}

module "gitlab_server" {
  source        = "./modules/terraform-aws-gitlab-server"
  create        = true
  ssh_key_name  = local.gitlab-bastion.key_name
  vpc_id        = module.gitlab-network.vpc_id
  subnet_id     = module.gitlab-network.subnet_public_ids[0]
  instance_type = "m5.large"
}

output "gitlab_server" {
  value = {
    bastion_info = module.gitlab_server.bastion_info
  }
}

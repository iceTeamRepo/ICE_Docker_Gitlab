module "gitlab_network" {
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
  source         = "./modules/terraform-aws-gitlab-server"
  create         = true
  ssh_key_name   = var.key_name
  vpc_id         = module.gitlab_network.vpc_id
  subnet_id      = module.gitlab_network.subnet_public_ids[0]
  instance_type  = "m5.large"
  domain         = var.domain
}

data "aws_route53_zone" "gitlab" {
  name         = var.zone_name
  private_zone = false
}

resource "aws_route53_record" "gitlab" {
  zone_id = data.aws_route53_zone.gitlab.zone_id
  name    = var.domain
  type    = "A"
  ttl     = 300
  records = [module.gitlab_server.bastion_info.public_ip]
}

module "certs" {
  source = "./modules/terraform-tls-certificate"

  private_key_algorithm   = "RSA"
  private_key_rsa_bits    = 2048
  private_key_ecdsa_curve = "P256"
  cert_file_name          = var.domain

  ca_certificate = {
    common_name           = "Root CA"
    organization          = "Plateer Inc"
    organizational_unit   = "Development"
    street_address        = ["1234 Main Street"]
    locality              = "Seoul"
    province              = "ON"
    country               = "Korea"
    postal_code           = "A123456"
    validity_period_hours = 87600 # 10 years
    allowed_uses          = ["key_encipherment", "digital_signature", "cert_signing", "crl_signing"]
  }

  certificates = {
    "gitlab" = {
      common_name         = "gitlab"
      organization        = "Plateer Inc"
      organizational_unit = "Development"
      street_address      = ["1234 Main Street"]
      locality            = "Seoul"
      province            = "ON"
      country             = "Korea"
      postal_code         = "A123456"
      dns_names = [
        var.domain
      ]
      ip_addresses = [
        "127.0.0.1",
      ]
      validity_period_hours = 43800 # 5 years
      allowed_uses          = ["key_encipherment", "digital_signature", "data_encipherment", "code_signing", "server_auth", "client_auth", ]
    }
  }
}

module "gitlab_cert_file_copy" {
  source                   = "./modules/terraform-ssh-file-copy"
  create                   = true
  server_user              = "ubuntu"
  server_ip                = module.gitlab_server.bastion_info.public_ip
  private_key_local_path   = var.key_local_path
  private_file_local_path  = "./output/gitlab/gitlab.idtice.com.crt"
  private_file_remote_path = "/home/ubuntu/gitlab.idtice.com.crt"
  depends_on               = [module.gitlab_server]
}

module "gitlab_key_file_copy" {
  source                   = "./modules/terraform-ssh-file-copy"
  create                   = true
  server_user              = "ubuntu"
  server_ip                = module.gitlab_server.bastion_info.public_ip
  private_key_local_path   = var.key_local_path
  private_file_local_path  = "./output/gitlab/gitlab.idtice.com.key"
  private_file_remote_path = "/home/ubuntu/gitlab.idtice.com.key"
  depends_on               = [module.gitlab_server]
}



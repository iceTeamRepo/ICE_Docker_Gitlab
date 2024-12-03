#######################################################################################
# Network 변수
#######################################################################################
variable "gitlab_network_name" {
  description = "gitlab network name"
  type = string
  default = "gitlab-poc-network"
}

variable "gitlab_network_vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "172.19.0.0/16"
}

variable "gitlab_network_vpc_cidrs_public" {
  description = "CIDR blocks for the public subnets"
  type        = list(string)
  default     = ["172.19.0.0/20"]
}

variable "gitlab_network_nat_count" {
  description = "Number of NAT gateways"
  type        = number
  default     = 1
}

variable "gitlab_network_vpc_cidrs_private" {
  description = "CIDR blocks for the private subnets"
  type        = list(string)
  default     = ["172.19.48.0/20"]
}

variable "zone_name" {
  description = "Route53 zone name"
  default = "idtice.com"
}

variable "domain" {
  description = "gitlab domain name"
  default = "gitlab.idtice.com"
}

variable "key_name" {
  description = "The name of the key"
  type        = string
  default     = "devops_tool_key"
}

variable "key_local_path" {
  description = "The local path to the key file"
  type        = string
  default     = "C://Key/devops_tool_key.pem"
}
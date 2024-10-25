output "gitlab_server" {
  description = "gitlap server 정보 확인"
  value = {
    bastion_info = module.gitlab_server.bastion_info
  }
}

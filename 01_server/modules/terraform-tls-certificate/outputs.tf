
output "ca_cert_files" {
  description = "Deployed CA certificate and key file paths"
  value = {
    pem_bundle = var.create ? local_sensitive_file.ca_pem_bundle[0].content : null
    cert       = var.create ? local_sensitive_file.cacert[0].content : null
    key        = var.create ? local_sensitive_file.cakey[0].content : null
  }
}

output "key_files" {
  description = "Deployed client certificate key file paths"
  value = {
    for key, content in local_sensitive_file.key : 
    key => content
  }
}

output "cert_files" {
  description = "Deployed client certificate file paths"
  value = {
    for key, content in local_sensitive_file.cert : 
    key => content
  }
}
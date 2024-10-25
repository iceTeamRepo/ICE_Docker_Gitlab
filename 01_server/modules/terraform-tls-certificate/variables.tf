variable "create" {
  description = "Create Module, defaults to true."
  default     = true
}

variable "cert_file_name" {
  description = "Certificate's file name"
}

variable "ca_certificate" {
  description = "List of objects for the Vault identity entity"
  type = object({
    validity_period_hours = number
    allowed_uses          = list(string)
    common_name           = string
    organization          = string
    organizational_unit   = string
    street_address        = list(string)
    locality              = string
    province              = string
    country               = string
    postal_code           = string
  })
  default = null
}

variable "certificates" {
  description = "List of objects for the Vault identity entity"
  type = map(object({
    validity_period_hours = number
    allowed_uses          = list(string)
    ip_addresses          = list(string) # List of IP addresses for which the certificate will be valid (e.g. 127.0.0.1)
    dns_names             = list(string) # List of DNS names for which the certificate will be valid (e.g. vault.service.consul, foo.example.com)
    common_name           = string
    organization          = string
    organizational_unit   = string
    street_address        = list(string)
    locality              = string
    province              = string
    country               = string
    postal_code           = string
  }))
  default = {}
}

variable "private_key_algorithm" {
  description = "The name of the algorithm to use for private keys. Must be one of: RSA or ECDSA."
  type        = string
  default     = "RSA"
}

variable "private_key_ecdsa_curve" {
  description = "The name of the elliptic curve to use. Should only be used if var.private_key_algorithm is ECDSA. Must be one of P224, P256, P384 or P521."
  type        = string
  default     = "P224"

  validation {
    condition     = can(regex("^P(224|256|384|521)$", var.private_key_ecdsa_curve))
    error_message = "The 'private_key_ecdsa_curve' must be one of P224, P256, P384, or P521."
  }
}

variable "private_key_rsa_bits" {
  description = "The size of the generated RSA key in bits. Should only be used if var.private_key_algorithm is RSA."
  type        = string
  default     = "4096"
}


# ---------------------------------------------------------------------------------------------------------------------
#  CA 인증서 만들기
# ---------------------------------------------------------------------------------------------------------------------
resource "tls_private_key" "ca" {
  count       = var.create ? 1 : 0
  algorithm   = var.private_key_algorithm
  ecdsa_curve = var.private_key_ecdsa_curve
  rsa_bits    = var.private_key_rsa_bits
}

resource "tls_self_signed_cert" "ca" {
  count             = var.create && var.ca_certificate != null ? 1 : 0
  key_algorithm     = var.private_key_algorithm
  private_key_pem   = tls_private_key.ca[0].private_key_pem
  is_ca_certificate = true

  validity_period_hours = var.ca_certificate.validity_period_hours
  allowed_uses          = var.ca_certificate.allowed_uses

  subject {
    common_name         = var.ca_certificate.common_name
    organization        = var.ca_certificate.organization
    organizational_unit = var.ca_certificate.organizational_unit
    street_address      = var.ca_certificate.street_address
    locality            = var.ca_certificate.locality
    province            = var.ca_certificate.province
    country             = var.ca_certificate.country
    postal_code         = var.ca_certificate.postal_code
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# CA 인증서를 사용하여 서명된 TLS 인증서 만들기
# ---------------------------------------------------------------------------------------------------------------------
resource "tls_private_key" "cert" {
  for_each    = var.create ? var.certificates : {}
  algorithm   = var.private_key_algorithm
  ecdsa_curve = var.private_key_ecdsa_curve
  rsa_bits    = var.private_key_rsa_bits
}

resource "tls_cert_request" "cert" {
  for_each        = var.create ? var.certificates : {}
  key_algorithm   = var.private_key_algorithm
  private_key_pem = tls_private_key.cert[each.key].private_key_pem
  dns_names       = each.value.dns_names
  ip_addresses    = each.value.ip_addresses

  subject {
    common_name         = each.value.common_name
    organization        = each.value.organization
    organizational_unit = each.value.organizational_unit
    street_address      = each.value.street_address
    locality            = each.value.locality
    province            = each.value.province
    country             = each.value.country
    postal_code         = each.value.postal_code
  }
}

resource "tls_locally_signed_cert" "cert" {
  for_each              = var.create ? var.certificates : {}
  ca_key_algorithm      = var.private_key_algorithm
  cert_request_pem      = tls_cert_request.cert[each.key].cert_request_pem
  ca_private_key_pem    = tls_private_key.ca[0].private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca[0].cert_pem
  validity_period_hours = each.value.validity_period_hours
  allowed_uses          = each.value.allowed_uses
}

# ---------------------------------------------------------------------------------------------------------------------
# Output Files
# ---------------------------------------------------------------------------------------------------------------------
resource "local_sensitive_file" "cakey" {
  count    = var.create ? 1 : 0
  content  = tls_private_key.ca[0].private_key_pem
  filename = "${path.root}/output/root_ca/ca_key.pem"
}

resource "local_sensitive_file" "cacert" {
  count    = var.create ? 1 : 0
  content  = tls_self_signed_cert.ca[0].cert_pem
  filename = "${path.root}/output/root_ca/ca_cert.pem"
}

resource "local_sensitive_file" "ca_pem_bundle" {
  count    = var.create ? 1 : 0
  content  = "${tls_private_key.ca[0].private_key_pem}${tls_self_signed_cert.ca[0].cert_pem}"
  filename = "${path.root}/output/root_ca/ca_cert_key_bundle.pem"
}

resource "local_sensitive_file" "key" {
  for_each = var.create ? var.certificates : {}
  content  = tls_private_key.cert[each.key].private_key_pem
  filename = "${path.root}/output/${each.key}/${var.cert_file_name}.key"
}

resource "local_sensitive_file" "cert" {
  for_each = var.create ? var.certificates : {}
  content  = tls_locally_signed_cert.cert[each.key].cert_pem
  filename = "${path.root}/output/${each.key}/${var.cert_file_name}.crt"
}


resource "random_id" "tf_prefix" {
  byte_length = 4
}

resource "google_project_service" "certificatemanager_svc" {
  service            = "certificatemanager.googleapis.com"
  project   = var.project_id
  disable_on_destroy = false
}
resource "tls_private_key" "glb_key" {
  algorithm = "RSA"
  rsa_bits = 2048
}

# resource "tls_cert_request" "origin_cert_request" {
#   private_key_pem = tls_private_key.origin_private_key.private_key_pem

#   subject {
#     organization = "Netrunners"
#   }
# }

resource "tls_self_signed_cert" "glb_certificate" {
  private_key_pem = tls_private_key.glb_key.private_key_pem
  subject {
    common_name  = "*.${local.domain}, ${local.domain}"
    organization = "Netrun, Inc"
  }
  #is_ca_certificate = true
  validity_period_hours = 8760
  dns_names             = [  "*.${local.domain}", local.domain]
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_ssl_certificate" "glb_certificate" {
  project = var.project_id

  name        = format("default-cert-%s", random_id.id.hex)
  private_key = tls_private_key.glb_key.private_key_pem
  certificate = tls_self_signed_cert.glb_certificate.cert_pem
  lifecycle {
    create_before_destroy = true
  }
}
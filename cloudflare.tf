terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

## Create the necessary CNAME so that Google can DNS authorize the certificate

# resource "cloudflare_record" "certificate_root_cname" {
#   zone_id = var.cloudflare_zone_id
#   name    = google_certificate_manager_dns_authorization.root_domain_auth.dns_resource_record[0].name
#   value   = google_certificate_manager_dns_authorization.root_domain_auth.dns_resource_record[0].data
#   type    = "CNAME"
#   ttl     = 60
# }

resource "cloudflare_record" "wildcard_a_record" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  value   = google_compute_global_address.default.address
  type    = "A"
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "zone_apex" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  value   = google_compute_global_address.default.address
  type    = "A"
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "www_a_record" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  value   = google_compute_global_address.default.address
  type    = "A"
  proxied = true
  ttl     = 1
}

# Enable mTLS on a zone level

resource "cloudflare_authenticated_origin_pulls" "my_aop" {
  zone_id = var.cloudflare_zone_id
  enabled = true
}

resource "cloudflare_authenticated_origin_pulls_certificate" "zone_app_cert" {
  zone_id     = var.cloudflare_zone_id
  certificate = tls_self_signed_cert.mtls_leaf_certificate.cert_pem
  private_key = tls_private_key.mtls_key.private_key_pem
  type        = "per-zone"
}

resource "tls_self_signed_cert" "mtls_leaf_certificate" {
  private_key_pem = tls_private_key.mtls_key.private_key_pem
  subject {
    common_name  = "*.${local.domain}, ${local.domain}"
    organization = "Netrun, Inc"
  }
  is_ca_certificate = false
  validity_period_hours = 8760
  dns_names             = [  "*.${local.domain}", local.domain]
  allowed_uses = [
    "client_auth",
  ]
  lifecycle {
    create_before_destroy = true
  }
}

## Request CloudFlare Origin Certificate

# resource "tls_private_key" "origin_private_key" {
#   algorithm = "RSA"
# }

# resource "tls_cert_request" "origin_cert_request" {
#   private_key_pem = tls_private_key.origin_private_key.private_key_pem

#   subject {
#     organization = "Netrunners"
#   }
# }

# resource "cloudflare_origin_ca_certificate" "origin_certificate" {
#   csr          = tls_cert_request.origin_cert_request.cert_request_pem
#   hostnames    = [local.domain, "*.${local.domain}"]
#   request_type = "origin-rsa"
# }
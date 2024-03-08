resource "random_id" "tf_prefix" {
  byte_length = 4
}

resource "google_project_service" "certificatemanager_svc" {
  service            = "certificatemanager.googleapis.com"
  project   = var.project_id
  disable_on_destroy = false
}
resource "tls_private_key" "mtls_key" {
  algorithm = "RSA"
  rsa_bits = 2048
}

# resource "tls_cert_request" "origin_cert_request" {
#   private_key_pem = tls_private_key.origin_private_key.private_key_pem

#   subject {
#     organization = "Netrunners"
#   }
# }

resource "tls_self_signed_cert" "mtls_certificate" {
  private_key_pem = tls_private_key.mtls_key.private_key_pem
  subject {
    common_name  = "*.${local.domain}, ${local.domain}"
    organization = "Netrun, Inc"
  }
  is_ca_certificate = true
  validity_period_hours = 8760
  dns_names             = [  "*.${local.domain}", local.domain]
  allowed_uses = [  ]
  lifecycle {
    create_before_destroy = true
  }
}



# resource "google_certificate_manager_certificate" "origin_certificate" {
#   name        = "${local.name}-selfsigned-${random_id.tf_prefix.hex}"
#   description = "Global cert"
#   project   = var.project_id
#   scope       = "ALL_REGIONS"
#   self_managed {
#     pem_certificate = tls_self_signed_cert.origin_certificate.cert_pem
#     pem_private_key = tls_private_key.origin_private_key.private_key_pem
#   }
# }

resource "google_compute_ssl_certificate" "mtls_certificate" {
  project = var.project_id

  name        = format("default-cert-%s", random_id.id.hex)
  private_key = tls_private_key.mtls_key.private_key_pem
  certificate = tls_self_signed_cert.mtls_certificate.cert_pem
  lifecycle {
    create_before_destroy = true
  }
}

# resource "google_network_security_server_tls_policy" "server_mtls_policy" {
#   provider    = google-beta
#   name                  = "${local.name}-mtls-${random_id.tf_prefix.hex}"
#   description           = "Mutual TLS Policy"
#   location = "global"
#   project = var.project_id
#   #server_certificate = google_compute_ssl_certificate.default[0].self_link
#   mtls_policy {
#    # client_validation_trust_config = google_certificate_manager_trust_config.trust_config.id
#     client_validation_mode         = "ALLOW_INVALID_OR_MISSING_CLIENT_CERT"
#   }
# }

# resource "google_certificate_manager_trust_config" "trust_config" {
#   name        = "trust-config"
#   description = "sample description for the trust config"
#   location    = "us-central1"
#   project = var.project_id

#   trust_stores {
#     trust_anchors {
#       pem_certificate = file("root-ca.crt")
#     }
#   }

#   labels = {
#     foo = "bar"
#   }
# }

## Create a wildcard certificate in GCP with DNS authorization

# resource "google_certificate_manager_dns_authorization" "root_domain_auth" {
#   name        = "${local.name}-dnsauth-${random_id.tf_prefix.hex}"
#   description = "GCP DNS authorization"
#   domain      = local.domain 
#   project   = var.project_id
#   labels = {
#     "terraform" : true
#   }
# }

# ## Create a managed certificate from DNS authorization

# resource "google_certificate_manager_certificate" "root_cert" {
#   name        = "${local.name}-rootcert-${random_id.tf_prefix.hex}"
#   description = "Root and wildcard SSL certificate"
#   project   = var.project_id
#   managed {
#     domains = [
#       "*.${local.domain}",
#       local.domain
#     ]
#     dns_authorizations = [
#       google_certificate_manager_dns_authorization.root_domain_auth.id,
#     ]
#   }
#   labels = {
#     "terraform" : true
#   }
# }

# resource "google_certificate_manager_certificate_map" "certificate_map" {
#   name        = "${local.name}-certmap-${random_id.tf_prefix.hex}"
#   description = "${local.domain} certificate map"
#   project   = var.project_id

#   labels = {
#     "terraform" : true
#   }
# }

# resource "google_certificate_manager_certificate_map_entry" "first_entry" {
#   name        = "${local.name}-first-entry-${random_id.tf_prefix.hex}"
#   description = "${local.name} certificate map entry 1"
#   project   = var.project_id
#   map         = google_certificate_manager_certificate_map.certificate_map.name
#   labels = {
#     "terraform" : true
#   }
#   certificates = [google_certificate_manager_certificate.origin_certificate.id]
#   hostname     = "*.${local.domain}"
# }

# resource "google_certificate_manager_certificate_map_entry" "second_entry" {
#   name        = "${local.name}-second-entry-${random_id.tf_prefix.hex}"
#   description = "${local.name} certificate map entry 2"
#   project   = var.project_id
#   map         = google_certificate_manager_certificate_map.certificate_map.name
#   labels = {
#     "terraform" : true
#   }
#   certificates = [google_certificate_manager_certificate.origin_certificate.id]
#   matcher = "PRIMARY"
# }


# Create a CloudFlare origin certificate in GCP from CloudFlare

# resource "google_compute_ssl_certificate" "cloudflare_origin_wildcard" {
#   name_prefix = "${local.name}-cf-origin-cert"
#   private_key = tls_private_key.origin_private_key.private_key_pem
#   certificate = cloudflare_origin_ca_certificate.origin_certificate.certificate
#   project   = var.project_id
#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "google_privateca_certificate" "private_ca_origin_certificate" {
#   location = "us-central1"
#   pool = google_privateca_ca_pool.private_pool.name
#   certificate_authority = google_privateca_certificate_authority.private_ca.certificate_authority_id
#   lifetime = "86000s"
#   project   = var.project_id
#   name = "${local.name}-cloudflare-mtls-${random_id.tf_prefix.hex}"
#   config {
#     subject_config  {
#       subject {
#         common_name = "*.netrun.cloud"
#         organization = "NetRun"
#       } 

#     }
#     x509_config {
#       ca_options {
#         is_ca = true
#       }
#       key_usage {
#         base_key_usage {
#           cert_sign = true
#           crl_sign = true
#         }
#         extended_key_usage {
#           server_auth = false
#         }
#       }
#     }
#     public_key {
#       format = "PEM"
#       key = base64encode(tls_private_key.origin_private_key.public_key_pem)
#     }
#   }
# }
resource "random_id" "id" {
  byte_length = 2
}

resource "google_compute_global_address" "default" {
  project = var.project_id

  provider = google-beta
  name     = format("l7-glb-static-ip-%s", random_id.id.hex)
}

resource "google_compute_global_forwarding_rule" "gcr_echo_xlb_forwarding_80" {
  project = var.project_id

  name                  = format("l7-xlb-echo-forwarding-rule-http-%s", random_id.id.hex)
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.gcr_echo_http.id
  ip_address            = google_compute_global_address.default.id
}

resource "google_compute_target_http_proxy" "gcr_echo_http" {
  project = var.project_id

  name    = format("l7-xlb-echo-target-http-proxy-%s", random_id.id.hex)
  url_map = google_compute_url_map.gcr_echo_url_map.id
}

resource "google_compute_global_forwarding_rule" "gcr_echo_xlb_forwarding_443" {
  project = var.project_id

  name                  = format("l7-xlb-echo-forwarding-rule-https-%s", random_id.id.hex)
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.gcr_echo_https.id
  ip_address            = google_compute_global_address.default.id
}

resource "google_compute_target_https_proxy" "gcr_echo_https" {
  project          = var.project_id
  name             = format("l7-xlb-echo-target-https-proxy-%s", random_id.id.hex)
  quic_override    = "DISABLE"
  url_map          = google_compute_url_map.gcr_echo_url_map.id
  #certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.certificate_map.id}"
  ssl_certificates = [google_compute_ssl_certificate.mtls_certificate.id]
  #certificate_manager_certificates = ["//certificatemanager.googleapis.com/${google_certificate_manager_certificate.origin_certificate.id}"]
  server_tls_policy = google_network_security_server_tls_policy.mtls_server_policy.id
  #ssl_policy  = google_compute_ssl_policy.mtls_ssl_policy.name
}

resource "google_compute_ssl_policy" "mtls_ssl_policy" {
  project          = var.project_id
  name             = format("mtls-ssl-%s", random_id.id.hex)
  profile = "MODERN"

  min_tls_version = "TLS_1_2"

}

# Updates are not allowed for this resource due to API limitations so you will have to either re-create it or destroy and apply again

resource "google_network_security_server_tls_policy" "mtls_server_policy" {
  project     = var.project_id
  provider    = google-beta
  name        = format("server-mtls-%s", random_id.id.hex)
  location    = "global"
  description = "TLS Policy for mTLS"
  allow_open  = "false"
  #server_certificate = google_compute_ssl_certificate.default[0].self_link
  mtls_policy {
    #client_validation_trust_config = google_certificate_manager_trust_config.mtls_trust_config.id
    client_validation_trust_config = "projects/${data.google_project.project.number}/locations/global/trustConfigs/${google_certificate_manager_trust_config.mtls_trust_config.name}"
    #client_validation_mode         = "ALLOW_INVALID_OR_MISSING_CLIENT_CERT"
    client_validation_mode         = "REJECT_INVALID"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_certificate_manager_trust_config" "mtls_trust_config" {
  name        = format("mtls-trust-%s", random_id.id.hex)
  project     = var.project_id
  description = "mTLS Trust Config"
  location    = "global"

  trust_stores {
    trust_anchors { 
      pem_certificate = google_compute_ssl_certificate.mtls_certificate.certificate
    }
    # intermediate_cas { 
    #   pem_certificate = google_compute_ssl_certificate.mtls_certificate.certificate
    # }
  }

}

resource "google_compute_url_map" "gcr_echo_url_map" {
  project = var.project_id

  name            = format("l7-xlb-echo-url-map-%s", random_id.id.hex)
  default_service = google_compute_backend_service.gcr_echo_backend.id

    host_rule {
    hosts = ["alpha.netrun.cloud"]
    path_matcher = "alpha"

  }
  path_matcher {
   default_service = google_compute_backend_service.gcr_echo_backend.id
   name = "alpha"

   route_rules {
    priority = 1
    
    match_rules {
      ignore_case = true
      prefix_match = "/"
    }
      route_action {
          url_rewrite {
            # This re-writes the host header to alpha.netrun.cloud
            host_rewrite = "beta.netrun.cloud"
            path_prefix_rewrite = "/"
          }
          weighted_backend_services {
            backend_service = google_compute_backend_service.gcr_echo_backend.id
            weight = 100
        }
    }
   }
  }
}

output "glb_ip" {
  value = google_compute_global_address.default.address
}

# Fetch CloudFlare ip address list from their API

# data "http" "get_cloudflare_ips" {
#   url = var.cloudflare_api
# }

# locals {
#   cloudflare_ips = jsondecode(data.http.get_cloudflare_ips.response_body)
# }

# # output "show_cloudflare_ips" {
# #   value = local.cloudflare_ips.result.ipv4_cidrs
# # }

# # Create a Cloud Armor policy with CloudFlare ip address list

# resource "google_compute_security_policy" "cloudflare_addresses" {
#  # for_each = local.cloudflare_ips.result.ipv4_cidrs
#   name   = format("l7-glb-cf-policy-%s", random_id.id.hex)
#   project = var.project_id

#   rule {
#     action   = "allow"
#     priority = "100"
#     match {
#       versioned_expr = "SRC_IPS_V1"
#       config {
#         src_ip_ranges = flatten(slice("${local.cloudflare_ips.result.ipv4_cidrs}", 0, 10))
#       }
#     }
#     description = "Allow access from CloudFlare public ip ranges 1"
#   }

#     rule {
#     action   = "allow"
#     priority = "110"
#     match {
#       versioned_expr = "SRC_IPS_V1"
#       config {
#         src_ip_ranges = flatten(slice("${local.cloudflare_ips.result.ipv4_cidrs}", 10 , length(local.cloudflare_ips.result.ipv4_cidrs)))
#       }
#     }
#     description = "Allow access from CloudFlare public ip ranges 2"
#   }
#  rule {
#     action   = "deny(403)"
#     priority = "2147483647"
#     match {
#       versioned_expr = "SRC_IPS_V1"
#       config {
#         src_ip_ranges = ["*"]
#       }
#     }
#     description = "Default Deny"
#   }
# }
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
  url_map = google_compute_url_map.http_redirect.id
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
  ssl_certificates = [google_compute_ssl_certificate.glb_certificate.id]
  server_tls_policy = google_network_security_server_tls_policy.mtls_server_policy.id
  ssl_policy  = google_compute_ssl_policy.mtls_ssl_policy.name
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
  mtls_policy {
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
      pem_certificate =  file("${path.module}/secrets/authenticated_origin_pull_ca.pem")
    }
  }

}

resource "google_compute_url_map" "http_redirect" {
  name        = format("http-redirect-%s", random_id.id.hex)
  project     = var.project_id
  provider    = google-beta
  default_url_redirect {
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"  // 301 redirect
    strip_query            = false
    https_redirect         = true  // this is the magic
  }
}

resource "google_compute_url_map" "gcr_echo_url_map" {
  project = var.project_id

  name            = format("l7-xlb-echo-url-map-%s", random_id.id.hex)
  default_service = google_compute_backend_service.gcr_echo_backend.id
}

output "glb_ip" {
  value = google_compute_global_address.default.address
}


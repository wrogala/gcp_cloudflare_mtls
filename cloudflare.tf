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


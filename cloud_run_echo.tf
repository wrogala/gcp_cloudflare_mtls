module "gcp_utils" {
  source  = "terraform-google-modules/utils/google"
  version = "~> 0.3"
}

## https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_service

resource "google_cloud_run_service" "gcr_echo" {
  for_each = toset(var.regions)

  project  = var.project_id
  name     = format("gcr-echo-%s-%s", module.gcp_utils.region_short_name_map[lower(each.key)], random_id.id.hex)
  location = each.key

  template {
    spec {
      containers {
        image = "rteller/echo:latest"
        ports {
          container_port = 80
        }
      }
    }
  }
  metadata {
    annotations = {
      "run.googleapis.com/ingress" = "internal-and-cloud-load-balancing"
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
}

## https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_network_endpoint_group

resource "google_compute_region_network_endpoint_group" "gcr_echo_neg" {
  for_each = google_cloud_run_service.gcr_echo

  project = each.value.project

  name                  = format("gcr-echo-neg-%s-%s", module.gcp_utils.region_short_name_map[lower(each.key)], random_id.id.hex)
  network_endpoint_type = "SERVERLESS"
  region                = each.key
  cloud_run {
    service = each.value.name
  }
}
data "google_project" "project" {
  project_id  = var.project_id
}

# https://cloud.google.com/iap/docs/enabling-cloud-run
# Add IAM permissions to Cloud Run to allow access once IAP is turned on

data "google_iam_policy" "gcr_echo_noauth" {

  binding {
    role = "roles/run.invoker"
    members = [
      "serviceAccount:service-${data.google_project.project.number}@gcp-sa-iap.iam.gserviceaccount.com",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "gcr_echo_noauth" {
  for_each = google_cloud_run_service.gcr_echo

  location = each.value.location
  project  = each.value.project
  service  = each.value.name

  policy_data = data.google_iam_policy.gcr_echo_noauth.policy_data
}

# backend service with custom request and response headers
resource "google_compute_backend_service" "gcr_echo_backend" {
  project = var.project_id

  name = format("l7-xlb-echo-bs-%s", random_id.id.hex)

  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"
  enable_cdn            = false
  log_config {
    enable = true
    sample_rate = 1
  }
  #security_policy       = google_network_security_server_tls_policy.mtls_server_policy.name

  dynamic "backend" {
    for_each = google_compute_region_network_endpoint_group.gcr_echo_neg
    content {
      group = backend.value.id
    }
  }
  depends_on = [
   google_network_security_server_tls_policy.mtls_server_policy 
   ]
}

resource "google_iap_web_backend_service_iam_binding" "iap_iam_binding" {
  project = google_compute_backend_service.gcr_echo_backend.project
  web_backend_service = google_compute_backend_service.gcr_echo_backend.name
  role = "roles/iap.httpsResourceAccessor"
    members = [
    trimspace("user:${data.local_file.gcp_account_id.content}")
    ]
    depends_on = [ null_resource.get_gcloud_account_id ]
}

# Get account name from gcloud for IAP

resource "null_resource" "get_gcloud_account_id" {
  provisioner "local-exec" {
    when        = create
    command     = "gcloud info --format=value(config.account) > ${path.module}/account_id.txt"
    on_failure  = fail 
  }

}

data "local_file" "gcp_account_id" {
  filename = "${path.module}/account_id.txt"
  depends_on = [
    null_resource.get_gcloud_account_id
    ]
}
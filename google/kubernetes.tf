
terraform {
  required_version = "~> 0.12"
}

# a Kubernetes cluster 
resource "google_container_cluster" "dev-infra" {
  name     = "dev-infra"
  location = "europe-west3"
  remove_default_node_pool = true
  initial_node_count = 1
  logging_service = "none"
  min_master_version = "1.14.7-gke.14"

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

resource "google_container_node_pool" "dev-infra-nodes" {
  name       = "dev-infra-pool"
  location   = "europe-west3"
  cluster    = "${google_container_cluster.dev-infra.name}"
  node_count = 3
  version    = "1.14.7-gke.14"

  node_config {
    preemptible  = true
    machine_type = "n1-standard-4"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}
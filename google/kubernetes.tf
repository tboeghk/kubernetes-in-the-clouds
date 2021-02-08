
terraform {
  required_version = "~> 0.12"
}

# a Kubernetes cluster 
resource "google_container_cluster" "dev-infra" {
  name              = "dev-infra"
  location          = "europe-west3"
  network           = "default"
  remove_default_node_pool = true
  initial_node_count = 1
  min_master_version = "1.14.7-gke.14"
  logging_service   = "none"
  monitoring_service = "none"
}

resource "google_container_node_pool" "dev-infra-pool" {
  name       = "dev-infra-pool"
  location   = "europe-west3"
  cluster    = google_container_cluster.dev-infra.name
  node_count = 2

  node_config {
    preemptible  = true
    machine_type = "n1-standard-2"
    disk_size_gb = "10"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

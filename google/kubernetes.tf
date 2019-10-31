
terraform {
  required_version = "~> 0.12"
}

# a Kubernetes cluster 
resource "google_container_cluster" "dev-infra" {
  name              = "dev-infra"
  location          = "europe-west3-b"
  network           = "default"
  initial_node_count = 3
  min_master_version = "1.14.7-gke.14"
}

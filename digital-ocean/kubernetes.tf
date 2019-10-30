
terraform {
  required_version = "~> 0.12"
}

# a Kubernetes cluster 
resource "digitalocean_kubernetes_cluster" "dev-infra" {
  name    = "dev-infra"
  region  = "fra1"
  version = "1.15.5-do.0"
  tags    = ["dev"]

  node_pool {
    name       = "dev-infra-pool"
    size       = "s-4vcpu-8gb"
    node_count = 3
  }
}

terraform {
  required_version = "~> 0.12"
}

# Acquire cluster pet name

# The Kubernetes cluster 
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

# Save the Kubeconfig to disk

# Deploy Traefik as Ingress controller

# Retrieve Loadbalancer IP

# Configure DNS to point to new Loadbalancer

# Acquire Let's Encrypt certificates (wildcard)

# Deploy certificates as secrets

# Maybe deploy even more resources, fiddle around with
# user management
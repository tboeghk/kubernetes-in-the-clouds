
terraform {
  required_version = "~> 0.12"
}

# token taken from environment
# @see https://www.terraform.io/docs/providers/do/index.html#token
provider "digitalocean" {
  version = "~> 1.4"
}

# The Kubernetes cluster 
resource "digitalocean_kubernetes_cluster" "dev-infra" {
  name    = "dev-infra"
  region  = "fra1"
  version = "1.16.2-do.1"
  tags    = ["dev"]

  node_pool {
    name       = "dev-infra-pool"
    size       = "s-4vcpu-8gb"
    node_count = 3
  } 
}

# Write Kubeconfig
resource "local_file" "kubeconfig" {
    content   = digitalocean_kubernetes_cluster.dev-infra.kube_config.0.raw_config
    filename  = pathexpand("~/.kube/kube-config-dev-infra")
}   

# Deploy Traefik ingress controller

terraform {
  required_version = "~> 0.12"
}

# token taken from environment
# @see https://www.terraform.io/docs/providers/do/index.html#token
provider "digitalocean" {
  version = "~> 1.12"
}

# random cluster name
resource "random_pet" "cluster_name" {}

# The Kubernetes cluster 
resource "digitalocean_kubernetes_cluster" "this" {
  name    = "dev-infra"
  region  = "fra1"
  version = "1.16.2-do.1"
  tags    = [ random_pet.cluster_name.id ]

  node_pool {
    name       = "${random_pet.cluster_name.id}-pool"
    size       = "s-4vcpu-8gb"
    node_count = 1
    auto_scale = true
    min_nodes  = 1
    max_nodes  = 9
    tags    = [random_pet.cluster_name.id, "auto-scale"]
  } 
}

# Write Kubeconfig
resource "local_file" "kubeconfig" {
    content   = digitalocean_kubernetes_cluster.this.kube_config.0.raw_config
    filename  = pathexpand("~/.kube/kube-config-${random_pet.cluster_name.id}")
}

# Parse current domain into Traefik admin ui ingress
data "template_file" "traefik_admin_ui" {
  template = file("${path.root}/manifests/kube-system/traefik-2.1-admin-ui.yaml")
  vars = {
    domain = "${random_pet.cluster_name.id}.${digitalocean_kubernetes_cluster.this.region}.o11ystack.org"
  }
}

# Deploy Traefik ingress controller
resource "null_resource" "traefik" {
  triggers = {
    cluster = digitalocean_kubernetes_cluster.this.id
    always  = timestamp()
  }

  provisioner "local-exec" {
    command = "kubectl -n kube-system apply -f ${path.root}/manifests/kube-system/traefik-2.1.yaml"
    environment = {
      KUBECONFIG = pathexpand("~/.kube/kube-config-${random_pet.cluster_name.id}")
    }
  }
  provisioner "local-exec" {
    command = "kubectl -n kube-system apply -f ${path.root}/manifests/kube-system/echo.yaml"
    environment = {
      KUBECONFIG = pathexpand("~/.kube/kube-config-${random_pet.cluster_name.id}")
    }
  }
  provisioner "local-exec" {
    command = "echo '${data.template_file.traefik_admin_ui.rendered}' | kubectl -n kube-system apply -f -"
    environment = {
      KUBECONFIG = pathexpand("~/.kube/kube-config-${random_pet.cluster_name.id}")
    }
  }

  depends_on = [
    local_file.kubeconfig
  ]
}

# create wildcard acme certificate (as it's not supported by DO load balancer)
provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}
resource "tls_private_key" "certificate_key" {
  algorithm = "RSA"
}
resource "acme_registration" "registration" {
  account_key_pem = tls_private_key.certificate_key.private_key_pem
  email_address   = "nobody@o11ystack.org"
}
resource "acme_certificate" "certificate" {
  account_key_pem           = acme_registration.registration.account_key_pem
  common_name               = "${random_pet.cluster_name.id}.${digitalocean_kubernetes_cluster.this.region}.o11ystack.org"
  subject_alternative_names = ["*.${random_pet.cluster_name.id}.${digitalocean_kubernetes_cluster.this.region}.o11ystack.org"]

  dns_challenge {
    provider = "digitalocean"
  }
}

# create DO load balancer
resource "digitalocean_certificate" "this" {
  name    = "${random_pet.cluster_name.id}-certificate"
  type    = "custom"
  private_key       = acme_certificate.certificate.private_key_pem
  leaf_certificate  = acme_certificate.certificate.certificate_pem
  certificate_chain = "${acme_certificate.certificate.certificate_pem}${acme_certificate.certificate.issuer_pem}${acme_certificate.certificate.private_key_pem}"

  lifecycle {
    create_before_destroy = true
  }
}
resource "digitalocean_loadbalancer" "this" {
  name        = "${random_pet.cluster_name.id}-loadbalancer"
  region      = digitalocean_kubernetes_cluster.this.region
  droplet_tag = random_pet.cluster_name.id

  forwarding_rule {
    entry_port = 443
    entry_protocol = "tcp"
    target_port = 30443
    target_protocol = "tcp"
  }
  forwarding_rule {
    entry_port = 80
    entry_protocol = "tcp"
    target_port = 30080
    target_protocol = "tcp"
  }

  healthcheck {
    check_interval_seconds = 3
    healthy_threshold = 2
    port     = 30081
    protocol = "http"
    path     = "/ping"
  }
}

# Point DNS to load balancer ip
resource "digitalocean_record" "cluster" {
  domain = "${digitalocean_kubernetes_cluster.this.region}.o11ystack.org"
  type   = "A"
  name   = random_pet.cluster_name.id
  value  = digitalocean_loadbalancer.this.ip
  ttl    = 300
}
resource "digitalocean_record" "cluster_wildcard" {
  domain = "${digitalocean_kubernetes_cluster.this.region}.o11ystack.org"
  type   = "A"
  name   = "*.${random_pet.cluster_name.id}"
  value  = digitalocean_loadbalancer.this.ip
  ttl    = 300
}

# outpout
output "KUBECONFIG" {
  value = pathexpand("~/.kube/kube-config-${random_pet.cluster_name.id}")
}

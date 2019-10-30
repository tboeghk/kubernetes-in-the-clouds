provider "digitalocean" {
  version = "~> 1.4"
  token = "${var.do_token}"
}

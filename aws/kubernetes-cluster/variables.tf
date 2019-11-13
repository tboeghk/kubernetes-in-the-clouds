
# module input variables
variable "name" {
  type    = "string"
  default = "terraform-kubernetes-test"
}

variable "vpc_id" {
  type    = "string"
}

variable "nodes" {
  type = object({
    count = number
    instance_type = string
    spot_count = number
    spot_max_price = number
    spot_instance_types = list(string)
  })
}

# providers other than aws we are going to use
provider "http" {
  version = "~> 1.1"
}

provider "local" {
  version = "~> 1.4"
}

provider "kubernetes" {
    version     = "~> 1.10"
    config_path = ".kube/kube-config-${var.name}"
}
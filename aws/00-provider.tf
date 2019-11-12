# the AWS provider with out primary region
provider "aws" {
  version = "~> 2.35"
  region  = "eu-central-1"
}

provider "http" {
  version = "~> 1.1"
}

provider "local" {
  version = "~> 1.4"
}

variable "cluster-name" {
  default = "cloud-k8s-demo"
  type    = "string"
}

variable "cluster-az-span" {
  default = 2
}
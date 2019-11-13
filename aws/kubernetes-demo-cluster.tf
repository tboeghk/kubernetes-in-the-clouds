# The AWS region we want to use for our
# clusters. The clusters will span across
# all AZs in said region.
provider "aws" {
  version = "~> 2.35"
  region  = "eu-central-1"
}

# retrieve vpc data to place cluster in
data "aws_vpc" "selected" {
  id = "vpc-0a172f4b7e09126eb"
}

# create cluster
module "kubernetes" {
    source = "./kubernetes-cluster"
    providers = {
        aws = "aws"
    }
    vpc_id = "${data.aws_vpc.selected.id}"
    name = "ingress-test"
    nodes = {
        count = 3
        instance_type = "m5.2xlarge"
        spot_count = 5
        spot_max_price = 0.25
        spot_instance_types = [
            "m5.2xlarge",
            "m5.4xlarge",
        ]
    }
}
data "aws_region" "current" {
  name = "eu-central-1"
}

# Request availability zones currently available
data "aws_availability_zones" "available" {
    state = "available"
}

# create the vpc for the cluster
resource "aws_vpc" "cloud-k8s-demo-vpc" {
  cidr_block = "10.200.0.0/16"

  tags = "${
    map(
     "Name", "${var.cluster-name}-node",
     "kubernetes.io/cluster/${var.cluster-name}", "shared",
    )
  }"
}

# create a subnet in each az
resource "aws_subnet" "cloud-k8s-demo-subnet" {
  count = "${var.cluster-az-span}"

  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block        = "10.200.${count.index}.0/24"
  vpc_id            = "${aws_vpc.cloud-k8s-demo-vpc.id}"

  tags = "${
    map(
     "Name", "${var.cluster-name}-node",
     "kubernetes.io/cluster/${var.cluster-name}", "shared",
    )
  }"
}

# create a internet gateway for the vpc
resource "aws_internet_gateway" "internet-gw" {
  vpc_id = "${aws_vpc.cloud-k8s-demo-vpc.id}"

  tags = {
    Name = "${var.cluster-name}"
  }
}

# create a route table inside the vpc to route all 
# traffic (expect own subnet) through the internet-gw
resource "aws_route_table" "routing" {
  vpc_id = "${aws_vpc.cloud-k8s-demo-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.internet-gw.id}"
  }
}

# enable routing in subnets via the internet gateway
resource "aws_route_table_association" "cloud-k8s-demo" {
  count = "${var.cluster-az-span}"

  subnet_id      = "${aws_subnet.cloud-k8s-demo-subnet.*.id[count.index]}"
  route_table_id = "${aws_route_table.routing.id}"
}

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

# create master iam role
resource "aws_iam_role" "cloud-k8s-demo-iam" {
  name = "cloud-k8s-demo"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# policies to attach to above role
resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.cloud-k8s-demo-iam.name}"
}
resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.cloud-k8s-demo-iam.name}"
}

# security group for node communication inside
# the vpc
resource "aws_security_group" "k8s-cluster" {
  name        = "k8s-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = "${aws_vpc.cloud-k8s-demo-vpc.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster-name}"
  }
}

# retrieve current public ip and allow ingress traffic
# into above security role
data "http" "canihazip" {
  url = "https://canihazip.com/s"
}
resource "aws_security_group_rule" "demo-cluster-ingress-workstation-https" {
  cidr_blocks       = ["${data.http.canihazip.body}/32"]
  description       = "Allow my workstation to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.k8s-cluster.id}"
  to_port           = 443
  type              = "ingress"
}
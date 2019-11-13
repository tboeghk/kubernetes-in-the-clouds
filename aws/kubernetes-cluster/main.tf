# ---------------------------------------------------------------------
# (1) tag vpc and subnets for usage with current cluster
# ---------------------------------------------------------------------
data "aws_subnet_ids" "subnets" {
    vpc_id = "${var.vpc_id}"
}

resource "null_resource" "vpc" {
  triggers = {
    vpc_id  = "${var.vpc_id}"
    name    = "${var.name}"
    subnets = "${join(",", data.aws_subnet_ids.subnets.ids)}"
  }
  provisioner "local-exec" {
    command = "aws ec2 create-tags --resources ${var.vpc_id} ${join(" ", data.aws_subnet_ids.subnets.ids)} --tags Key=kubernetes.io/cluster/${var.name},Value=shared"
  }
}

# ---------------------------------------------------------------------
# (2) set up control plane
# ---------------------------------------------------------------------
# create master iam role
resource "aws_iam_role" "control-plane" {
  name = "${var.name}"

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
resource "aws_iam_role_policy_attachment" "control-plane-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.control-plane.name}"
}
resource "aws_iam_role_policy_attachment" "control-plane-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.control-plane.name}"
}

# security group for node communication inside
# the vpc
resource "aws_security_group" "control-plane" {
  name        = "${var.name}-control-plane"
  description = "Cluster communication with worker nodes"
  vpc_id      = "${var.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}"
  }
}

# retrieve current public ip and allow ingress traffic
# into above security role
data "http" "canihazip" {
  url = "https://canihazip.com/s"
}
resource "aws_security_group_rule" "control-plane-ingress-workstation" {
  cidr_blocks       = ["${data.http.canihazip.body}/32"]
  description       = "Allow my workstation to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.control-plane.id}"
  to_port           = 443
  type              = "ingress"
}

# the control plane
resource "aws_eks_cluster" "control-plane" {
  name            = "${var.name}"
  role_arn        = "${aws_iam_role.control-plane.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.control-plane.id}"]
    subnet_ids         = "${data.aws_subnet_ids.subnets.ids}"
  }

  depends_on = [
    "aws_iam_role_policy_attachment.control-plane-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.control-plane-AmazonEKSServicePolicy",
  ]
}

# ---------------------------------------------------------------------
# (3a) set up security for worker nodes
# ---------------------------------------------------------------------
# iam role for the nodes in the cluster
resource "aws_iam_role" "node" {
  name = "${var.name}-node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# the policies to attach to upper role
resource "aws_iam_role_policy_attachment" "node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.node.name}"
}
resource "aws_iam_role_policy_attachment" "node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.node.name}"
}
resource "aws_iam_role_policy_attachment" "node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.node.name}"
}

# prepare iam role to be attached to nodes
resource "aws_iam_instance_profile" "node" {
  name = "${var.name}"
  role = "${aws_iam_role.node.name}"
}

# The security group the worker nodes will use
resource "aws_security_group" "node" {
  name        = "${var.name}-node"
  description = "Security group for all nodes in the cluster"
  vpc_id      = "${var.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", "${var.name}-node",
     "kubernetes.io/cluster/${var.name}", "owned",
    )
  }"
}

# rules for said security group above. The first rule allowes traffic
# between the worker nodes, the second one covers communication between
# the worker nodes and the control plane (the third is vice versa)
resource "aws_security_group_rule" "node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.node.id}"
  source_security_group_id = "${aws_security_group.node.id}"
  to_port                  = 65535
  type                     = "ingress"
}
resource "aws_security_group_rule" "node-ingress-control-plane" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.node.id}"
  source_security_group_id = "${aws_security_group.control-plane.id}"
  to_port                  = 65535
  type                     = "ingress"
}
resource "aws_security_group_rule" "cluster-ingress-node" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.control-plane.id}"
  source_security_group_id = "${aws_security_group.node.id}"
  to_port                  = 443
  type                     = "ingress"
}

# ---------------------------------------------------------------------
# (3b) prepare launch of worker nodes
# ---------------------------------------------------------------------
# now we have the IAM hell in place. We retrieve the ami id for the Amazon
# pre baked Kuberentes image
data "aws_ami" "eks-worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${aws_eks_cluster.control-plane.version}-v*"]
  }
  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

# prepare a EKS compatible launch configuration to launch instances. This
# will use above pre-baked ami
locals {
  eks-node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.control-plane.endpoint}' --b64-cluster-ca '${aws_eks_cluster.control-plane.certificate_authority.0.data}' '${var.name}'
USERDATA
}

# this launch configuration is the base line to our cluster
# worker nodes.
resource "aws_launch_configuration" "node" {
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.node.name}"
  image_id                    = "${data.aws_ami.eks-worker.id}"
  instance_type               = "${var.nodes.instance_type}"
  name_prefix                 = "${var.name}-node"
  security_groups             = ["${aws_security_group.node.id}"]
  user_data_base64            = "${base64encode(local.eks-node-userdata)}"

  lifecycle {
    create_before_destroy = true
  }
}

# this launch configuration is the configuration to our cluster
# spot worker nodes. We will override instance_types and spot
# prices in autoscaling groups below.
resource "aws_launch_template" "spot-node" {
  name_prefix            = "${var.name}-spot"
  instance_type          = "${var.nodes.instance_type}"
  image_id               = "${data.aws_ami.eks-worker.id}"
  user_data              = "${base64encode(local.eks-node-userdata)}"
  iam_instance_profile {
    name                 = "${aws_iam_instance_profile.node.name}"
  }
  network_interfaces {
    associate_public_ip_address = true
    security_groups      = ["${aws_security_group.node.id}"]
  }
  lifecycle {
    create_before_destroy = "true"
  } 
}


# ---------------------------------------------------------------------
# (3c) launch worker nodes
# ---------------------------------------------------------------------
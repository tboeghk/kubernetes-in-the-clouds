# iam role for the nodes in the cluster
resource "aws_iam_role" "kubernetes-node" {
  name = "${var.cluster-name}-node"

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
  role       = "${aws_iam_role.kubernetes-node.name}"
}
resource "aws_iam_role_policy_attachment" "node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.kubernetes-node.name}"
}
resource "aws_iam_role_policy_attachment" "demo-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.kubernetes-node.name}"
}

# prepare iam role to be attached to nodes
resource "aws_iam_instance_profile" "kubernetes-node" {
  name = "${var.cluster-name}"
  role = "${aws_iam_role.kubernetes-node.name}"
}

# The security group the worker nodes will use
resource "aws_security_group" "kubernetes-node" {
  name        = "${var.cluster-name}"
  description = "Security group for all nodes in the cluster"
  vpc_id      = "${aws_vpc.cloud-k8s-demo-vpc.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", "${var.cluster-name}-node",
     "kubernetes.io/cluster/${var.cluster-name}", "owned",
    )
  }"
}

# rules for said security group above. The first rule allowes traffic
# between the worker nodes, the second one covers communication between
# the worker nodes and the control plane (the third is vice versa)
resource "aws_security_group_rule" "kubernetes-node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.kubernetes-node.id}"
  source_security_group_id = "${aws_security_group.kubernetes-node.id}"
  to_port                  = 65535
  type                     = "ingress"
}
resource "aws_security_group_rule" "kubernetes-node-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.kubernetes-node.id}"
  source_security_group_id = "${aws_security_group.k8s-cluster.id}"
  to_port                  = 65535
  type                     = "ingress"
}
resource "aws_security_group_rule" "kubernetes-cluster-ingress-node-https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.k8s-cluster.id}"
  source_security_group_id = "${aws_security_group.kubernetes-node.id}"
  to_port                  = 443
  type                     = "ingress"
}

# now we have the IAM hell in place. We retrieve the ami id for the Amazon
# pre baked Kuberentes image
data "aws_ami" "eks-worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${aws_eks_cluster.k8s-demo.version}-v*"]
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
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.k8s-demo.endpoint}' --b64-cluster-ca '${aws_eks_cluster.k8s-demo.certificate_authority.0.data}' '${var.cluster-name}'
USERDATA
}

resource "aws_launch_configuration" "kubernetes-node" {
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.kubernetes-node.name}"
  image_id                    = "${data.aws_ami.eks-worker.id}"
  instance_type               = "m4.large"
  name_prefix                 = "${var.cluster-name}-node"
  security_groups             = ["${aws_security_group.kubernetes-node.id}"]
  user_data_base64            = "${base64encode(local.eks-node-userdata)}"

  lifecycle {
    create_before_destroy = true
  }
}

# Build a autoscaling group and launch worker nodes
resource "aws_autoscaling_group" "kubernetes-nodes" {
  desired_capacity     = 2
  launch_configuration = "${aws_launch_configuration.kubernetes-node.id}"
  max_size             = 5
  min_size             = 2
  name                 = "${var.cluster-name}"
  vpc_zone_identifier  = "${aws_subnet.cloud-k8s-demo-subnet.*.id}"

  tag {
    key                 = "Name"
    value               = "${var.cluster-name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster-name}"
    value               = "owned"
    propagate_at_launch = true
  }
}

# the nodes need aws authentication information to actually
# join the cluster. We use the kube config we wrote when
# creating the control plane to connect to the cluster
provider "kubernetes" {
    version     = "~> 1.10"
    config_path = ".kube/aws-kube-config"
}

resource "kubernetes_config_map" "aws-auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = <<ROLES
- rolearn: ${aws_iam_role.kubernetes-node.arn}
  username: system:node:{{EC2PrivateDNSName}}
  groups:
    - system:bootstrappers
    - system:nodes
ROLES
}
}


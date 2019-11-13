
# create master iam role
resource "aws_iam_role" "cloud-k8s-demo-iam" {
  name = "${var.cluster-name}"

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

# the control plane
resource "aws_eks_cluster" "k8s-demo" {
  name            = "${var.cluster-name}"
  role_arn        = "${aws_iam_role.cloud-k8s-demo-iam.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.k8s-cluster.id}"]
    subnet_ids         = "${aws_subnet.cloud-k8s-demo-subnet.*.id}"
  }

  depends_on = [
    "aws_iam_role_policy_attachment.cluster-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.cluster-AmazonEKSServicePolicy",
  ]
}

# write the kube config into a file. Use this with:
#   export KUBECONFIG=.kube/aws-kube-config
locals {
  kubeconfig = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.k8s-demo.endpoint}
    certificate-authority-data: ${aws_eks_cluster.k8s-demo.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${var.cluster-name}"
KUBECONFIG
}

resource "local_file" "kubeconfig" {
    content     = "${local.kubeconfig}"
    filename = ".kube/aws-kube-config"
}

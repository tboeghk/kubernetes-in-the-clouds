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

resource "local_file" "foo" {
    content     = "${local.kubeconfig}"
    filename = "~/.kube/aws-kube-config"
}

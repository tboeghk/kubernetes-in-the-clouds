
# write the kube config into a file. Use this with:
#   export KUBECONFIG=.kube/kube-config-CLUSTERNAME
locals {
  kubeconfig = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.control-plane.endpoint}
    certificate-authority-data: ${aws_eks_cluster.control-plane.certificate_authority.0.data}
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
        - "${var.name}"
KUBECONFIG
}

resource "local_file" "kubeconfig" {
    content   = "${local.kubeconfig}"
    filename  = ".kube/kube-config-${var.name}"
}

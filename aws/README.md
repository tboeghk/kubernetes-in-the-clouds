# Amazon Web Services EKS

> _Kubernetes Cloud Provider experiments using Terraform_

The AWS setup is (by far) the most complex setup in this repo. Not only
is Terraform lacking any high level resources, also the control plane
creation takes staggering 8+ minutes.

```
[...]
aws_eks_cluster.k8s-demo: Still creating... [8m40s elapsed]
aws_eks_cluster.k8s-demo: Still creating... [8m50s elapsed]
aws_eks_cluster.k8s-demo: Creation complete after 8m54s [id=cloud-k8s-demo]
local_file.foo: Creating...
local_file.foo: Creation complete after 0s [id=375391936860fbf22e56fbcbf4becbcaba05b0f4]

Apply complete! Resources: 14 added, 0 changed, 0 destroyed.
```

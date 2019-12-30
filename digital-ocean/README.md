# Kubernetes ❤️ Digital Ocean (DO)

> _Kubernetes in the clouds: experiments using Terraform_

This example will create a Kubernetes cluster with a recent version,
three worker nodes and expose it via a Traefik ingress controller to
the internet.

## Setting up Digital Ocean as provider

[Digital Ocean](https://m.do.co/c/cc570ae1a34b) ships it's own 
command line tool `doctl` to interact with the API. 

```
brew install doctl
```

Before you can use it, you need to [generate an API token](https://cloud.digitalocean.com/account/api/tokens) 
and configure the command line tool:

```
doctl auth init
```

Then use it to explore the exact slugs for Kubernetes versions, regions 
and machine sizes:

```
$ doctl kubernetes options versions
Slug            Kubernetes Version
1.15.5-do.0     1.15.5
[...]

$ doctl compute region list        
Slug    Name               Available
[...]
ams3    Amsterdam 3        true
fra1    Frankfurt 1        true

$ doctl compute size list
Slug              Memory    VCPUs    Disk    Price Monthly    Price Hourly
[...]
s-4vcpu-8gb       8192      4        160     40.00            0.059520
g-2vcpu-8gb       8192      2        25      60.00            0.089286
gd-2vcpu-8gb      8192      2        50      65.00            0.096726 
[...]
```

## Creating the cluster

Then, spinning up the cluster is straight forward. But it still takes about
5 minutes to have control plane and worker up and running.

```
$ terraform init
$ terraform apply
[...]
digitalocean_kubernetes_cluster.dev-infra: Creation complete after 5m2s [id=56bc...]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

### Managing Ingress

The easiest way to create a ingress with an external public ip address is spinning up
a Kubernetes service type `LoadBalancer`. The service will be mapped to a Digital Ocean
Load Balancer that will remain unmanaged. 

In order to add it to Terraform lifecycle control, we'll explicity create it ourselves.
Then, we can use Digital Ocean to manage Let's Encrypt certificates.

### Connecting to the cluster

The cluster _Kubeconfig_ is written to `~/.kube/kube-config-dev-infra`. Point the 
`KUBECONFIG` environment to it and use it in your _kubectl_ and/or _k9s_ installation.
As an alternative you can use `doctl` to create a [_Kubeconfig_ pointing to the cluster](https://www.digitalocean.com/docs/kubernetes/how-to/connect-to-cluster/).

```
$ export KUBECONFIG=~/.kube/kube-config-dev-infra
$ kubectl get nodes
NAME                  STATUS   ROLES    AGE     VERSION
dev-infra-pool-gkzf   Ready    <none>   4m54s   v1.15.5
dev-infra-pool-gkzx   Ready    <none>   5m20s   v1.15.5
dev-infra-pool-gkzy   Ready    <none>   5m21s   v1.15.5
```

![DO Kubernetes cluster](do_cluster.png)




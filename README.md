# Kubernetes in the Clouds - _Terraform experiments_

Spinning up Kubernetes clusters with different cloud providers. How is it like? I tried them one by one:

* [Digital Ocean](digital-ocean/)
* AWS
* [Google](google/)
* Azure

## Running the examples

Each folder holds all source code to spin up a Kubernetes cluster with a
cloud provider. To apply the example, you need [Terraform](https://terraform.io)
installed.

To run the examples, you need an account with the cloud provider and it's 
secrets either as environment variable or configured in a `secretes.tf` file.

Some cloud providers have accompanying tools that easy spinning up or configuring
a cluster. We'll just use them outside the main Terraform code to comply with
the _infrastructure as code_ paradigm.

Cloud servers cost money!__. When you're done experimenting, remember to destroy 
all resources using a gentle

```
$ terraform destroy
```

## Secrets handling

When handling mulitple cloud accounts, I store a untracked `secrets.sh` in the project
root. I source it in the terminal window I'm working in and it unsets all cloud provider
credentials and configures the project specific ones:

```bash
#!/bin/bash

unset DO_AUTH_TOKEN
unset DO_SPACES_ACCESS_KEY
unset DO_SPACES_SECRET_KEY
unset DIGITALOCEAN_TOKEN
unset HCLOUD_TOKEN
unset KUBECONFIG
unset AWS_ACCESS_KEY_ID
unset AWS_CA_BUNDLE
unset AWS_PROFILE
unset AWS_SECRET_ACCESS_KEY

# Configure secrets to use
export DO_AUTH_TOKEN="..."
export DIGITALOCEAN_TOKEN="${DO_AUTH_TOKEN}"
export DIGITALOCEAN_ACCESS_TOKEN="${DO_AUTH_TOKEN}"

echo "-----------------------------------------------------------------"
echo " Configuring secrets in this Terminal ..."
echo "-----------------------------------------------------------------"
doctl auth init
```
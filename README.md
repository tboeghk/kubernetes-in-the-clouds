# Kubernetes Cloud Provider experiments using Terraform

Spinning up Kubernetes clusters with different cloud providers. How is it like? I tried them one by one:

* [Digital Ocean](digital-ocean/)

## Running the examples

To run the examples, each cloud provider directoy needs a `secrets.tf` with your
personal access token(s). For Digital Ocean this would look like:

```terraform
variable "do_token" {
    # my token name
    default = "91..."
}
```


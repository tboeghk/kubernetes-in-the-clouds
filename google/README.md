# Google Compute Platform

> _Kubernetes Cloud Provider experiments using Terraform_

```
$ brew cask install google-cloud-sdk

$ gcloud auth login

$ gcloud config set project cloud-test

$ gcloud container get-server-config --zone europe-west3
Fetching server config for europe-west3
defaultClusterVersion: 1.13.11-gke.9
defaultImageType: COS
validImageTypes:
- UBUNTU
- COS_CONTAINERD
- UBUNTU_CONTAINERD
- COS
validMasterVersions:
- 1.14.7-gke.14
- 1.14.7-gke.10
- 1.13.11-gke.9
- 1.13.11-gke.5
- 1.12.10-gke.15
validNodeVersions:
- 1.14.7-gke.14
- 1.14.7-gke.10
```

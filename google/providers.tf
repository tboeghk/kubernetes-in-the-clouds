provider "google" {
  version     = "~> 2.18"
  credentials = file("credentials/serviceaccount-terraform-cloud-test.json")
  project     = "cloud-test-257520"
  region      = "europe-west3"
}

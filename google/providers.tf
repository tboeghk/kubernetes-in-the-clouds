provider "google" {
  version     = "~> 2.18"
  credentials = "${file("terraform-cloud-test.json")}"
  project     = "cloud-test"
  region      = "europe-west3"
}
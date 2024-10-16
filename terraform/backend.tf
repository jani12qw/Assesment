terraform {
  backend "s3" {
    bucket = "vyom-terraform-backup"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

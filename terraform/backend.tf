terraform {
  backend "s3" {
    bucket = "my-github-oidc-bucket-eks"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

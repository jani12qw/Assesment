terraform {
  backend "s3" {
    bucket = "my-github-oidc-bucket-12qw"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

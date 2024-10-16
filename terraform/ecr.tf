resource "aws_ecr_repository" "my_ecr_repo" {
  name                 = "my-ecr-repo"
  image_tag_mutability = "MUTABLE"  # or "IMMUTABLE" based on your requiremen
  image_scanning_configuration {
    scan_on_push = true
  }
}



resource "aws_iam_policy" "image_pull_policy" {
  name        = "Image-pull-irsa-policy"
  description = "Allows lb controller to manage ALB and NLB"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "ecr:GetAuthorizationToken",
            "Resource": "*"
        }
    ]
})
}


module "irsa_addon" {
  source  = "./terraform-aws-irsa"
  create_kubernetes_namespace       = true
  create_kubernetes_service_account = true
  kubernetes_namespace              = "demo-app"
  kubernetes_service_account        = "demo-app-sa"
  eks_cluster_id                    = module.eks.cluster_name
  eks_oidc_provider_arn             =   replace(module.eks.cluster_oidc_issuer_url , "https://", "")
  irsa_iam_policies = [aws_iam_policy.image_pull_policy.arn]
}

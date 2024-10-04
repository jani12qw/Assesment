
locals {

aws_caller_identity_account_id = data.aws_caller_identity.current.account_id
aws_caller_identity_arn        = data.aws_caller_identity.current.arn
aws_eks_cluster_endpoint       = data.aws_eks_cluster.eks_cluster.endpoint
aws_partition_id               = data.aws_partition.current.partition
aws_region_name                = data.aws_region.current.name
eks_cluster_id                 = data.aws_eks_cluster.eks_cluster.id
eks_oidc_issuer_url            = replace(data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")
eks_oidc_provider_arn          = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}"

}


resource "aws_ecr_repository" "my_ecr_repo" {
  name                 = "my-ecr-repo"
  image_tag_mutability = "MUTABLE"  # or "IMMUTABLE" based on your requiremen
  image_scanning_configuration {
    scan_on_push = true
  }
}

module "irsa_application" {
  source  = "./terraform-aws-irsa"

  create_kubernetes_namespace       = true
  create_kubernetes_service_account = true
  kubernetes_namespace              = "demo-app"
  kubernetes_service_account        = "demo-app-sa"
  irsa_iam_role_path                = "/"
  eks_cluster_id                    = local.eks_cluster_id
  eks_oidc_provider_arn             = local.eks_oidc_provider_arn
  irsa_iam_policies = concat(
    ["arn:${local.aws_partition_id}:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"],
    try(var.addon_config.additional_iam_policies, [])
  )
}

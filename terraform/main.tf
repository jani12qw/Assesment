
locals {
  name               = "thecaptainhub-demo-1"
  region             = "us-east-1"
  cluster_version    = "1.29"
  vpc_cidr           = "10.0.0.0/16"
  secondary_vpc_cidr = "100.99.0.0/16"
  azs                = slice(data.aws_availability_zones.available.names, 0, 3)
  tags = {
    Blueprint = local.name
  }
}


################################################################################
# Cluster
################################################################################

#tfsec:ignore:aws-eks-enable-control-plane-loggings
module "eks" {
  depends_on = [ module.vpc ]
  source  = "./terraform-aws-eks"
  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true

  # EKS Addons
  cluster_addons = {
    coredns = {
      most_recent = true
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        env = {
          AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG = "true"
          ENI_CONFIG_LABEL_DEF               = "topology.kubernetes.io/zone"
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  vpc_id = module.vpc.vpc_id
  subnet_ids                = slice(module.vpc.private_subnets, 0, 3)
  control_plane_subnet_ids  = module.vpc.intra_subnets
  manage_aws_auth_configmap = true
  create_aws_auth_configmap = true

  eks_managed_node_groups = {
    default_node_group = {
      name            = "INFRA_NODE_GROUP"
      use_name_prefix = false

      subnet_ids = module.vpc.private_subnets

      min_size     = 1
      max_size     = 3
      desired_size = 1
      force_update_version = true
      instance_types = ["m5.large"]
      update_config = {
        max_unavailable_percentage = 33 # or set `max_unavailable`
      }
      ebs_optimized           = true
      disable_api_termination = false
      enable_monitoring       = true

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 30
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 150
            delete_on_termination = true
          }
        }
      }

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
        instance_metadata_tags      = "disabled"
      }

      create_iam_role          = true
      iam_role_name            = "eks-managed-node-group-role"
      iam_role_use_name_prefix = false
      iam_role_description     = "EKS managed node group  role"
      iam_role_tags = {
        Purpose = "Protector of the kubelet"
      }
      iam_role_additional_policies = {
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        additional                         = aws_iam_policy.node_additional.arn
      }
      # See issue https://github.com/awslabs/amazon-eks-ami/issues/844
      pre_bootstrap_user_data = <<-EOT
        #!/bin/bash
        set -ex
        # https://docs.aws.amazon.com/eks/latest/userguide/choosing-instance-type.html#determine-max-pods
        MAX_PODS=$(/etc/eks/max-pods-calculator.sh \
        --instance-type-from-imds \
        --cni-version ${trimprefix(data.aws_eks_addon_version.latest["vpc-cni"].version, "v")} \
        --cni-prefix-delegation-enabled \
        --cni-custom-networking-enabled \
        )
        # These settings opt out of the default behavior and use the maximum number of pods, with a cap of 110 due to
        # Kubernetes guidance https://kubernetes.io/docs/setup/best-practices/cluster-large/
        # See more info here https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
        cat <<-EOF > /etc/profile.d/bootstrap.sh
          export USE_MAX_PODS=false
          export KUBELET_EXTRA_ARGS="--max-pods=$${MAX_PODS}"
        EOF
        # Source extra environment variables in bootstrap script
        sed -i '/^set -o errexit/a\\nsource /etc/profile.d/bootstrap.sh' /etc/eks/bootstrap.sh
       EOT
    }
  }
  tags = local.tags
}


################################################################################
# VPC-CNI Custom Networking ENIConfig
################################################################################

resource "kubectl_manifest" "eni_config" {
  for_each = zipmap(local.azs, module.vpc.intra_subnets)

  yaml_body = yamlencode({
    apiVersion = "crd.k8s.amazonaws.com/v1alpha1"
    kind       = "ENIConfig"
    metadata = {
      name = each.key
    }
    spec = {
      securityGroups = [
        module.eks.cluster_primary_security_group_id,
        module.eks.node_security_group_id,
      ]
      subnet = each.value
    }
  })
}

################################################################################
# Supporting Resources
################################################################################
module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix      = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv6   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = local.tags
}
module "key_pair" {
  source  = "terraform-aws-modules/key-pair/aws"
  version = "~> 2.0"

  key_name_prefix    = local.name
  create_private_key = true

  tags = local.tags
}

resource "aws_security_group" "remote_access" {
  name_prefix = "${local.name}-remote-access"
  description = "Allow remote SSH access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.tags, { Name = "${local.name}-remote" })
}

resource "aws_iam_policy" "node_additional" {
  name        = "${local.name}-additional"
  description = "Example usage of node additional policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })

  tags = local.tags
}
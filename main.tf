terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.32.1"
    }
  }

  required_version = ">= 1.6.6"
}

provider "aws" {
  region  = "us-east-1"
  default_tags {
    tags = {
      owner     = "daniil.storozhenko@nixs.com"
      duedate   = "24.01.2024"
      terraform = "true"
    }
  }
}
variable "r_prefix" {
  type = string
  default = "dstorozhenko-skillup"
}

data "aws_iam_policy_document" "user_policy" {
  statement {
    sid = "1"
    effect = "Allow"
    actions = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:DescribeImages",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
    ]

    resources = [
      "*"
    ]
  }
}
resource "aws_iam_user_policy" "policy_assignment" {
  name = "${var.r_prefix}-policy"
  user = aws_iam_user.user.name

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = data.aws_iam_policy_document.user_policy.json
}
resource "aws_iam_user" "user" {
  name = "dstorozhenko-skillup"

}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.5.1"
  name = "${var.r_prefix}-vpc"
  cidr = "10.0.0.0/16"

  database_subnet_group_name            = "${var.r_prefix}-subnets-grp"
  database_subnet_names                 = ["${var.r_prefix}-subnet-1", "${var.r_prefix}-subnet-2", "${var.r_prefix}-subnet-3"]
  
  

  elasticache_subnet_group_name         = "${var.r_prefix}-subnets-grp"
  elasticache_subnet_names              = ["${var.r_prefix}-subnet-1", "${var.r_prefix}-subnet-2", "${var.r_prefix}-subnet-3"] 


  create_elasticache_subnet_route_table = true

  azs                 = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets      = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets    = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  elasticache_subnets = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    terraform = "true"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.21.0"

  cluster_name    = "${var.r_prefix}-eks"
  cluster_version = "1.28"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true
  

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

  }

  eks_managed_node_groups = {
    one = {
      name = "dstorozhenko-node-grp"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 3
      desired_size = 3
      labels = {
        type = "app"
      }
    }
    

  }
}

resource "aws_acm_certificate" "cert" {
  domain_name       = "dstorozhenko-skillup.pp.ua"
  validation_method = "DNS"
}



module "ecr" {
  source = "terraform-aws-modules/ecr/aws"

  repository_name = "${var.r_prefix}-ecr"
  repository_read_write_access_arns = ["arn:aws:iam::253650698585:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_0d6051324c9ec686", aws_iam_user.user.arn]
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 30 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    Terraform   = "true"
  }
}

data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "4.7.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

resource "aws_eks_addon" "ebs-csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.26.1-eksbuild.1"
  service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
  tags = {
    "eks_addon" = "ebs-csi"
    "terraform" = "true"
  }
}
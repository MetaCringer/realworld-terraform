provider "helm" {
  kubernetes {
    
    host                    = module.eks.cluster_endpoint
    cluster_ca_certificate  = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version        = "client.authentication.k8s.io/v1beta1"
      args               = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command            = "aws"
    }
  }
}
resource "helm_release" "aws_load_balancer_controller" {
  name = "${var.r_prefix}-lb"
  repository = "https://aws.github.io/eks-charts"
  chart = "aws-load-balancer-controller"
  namespace = "kube-system"
  version = "1.4.1"
  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  set {
    name  = "image.tag"
    value = "v2.4.7"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name = "serviceAccount.annotation.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.lb_role.arn
  }
  depends_on = [ 
    module.eks,
    aws_iam_role_policy_attachment.alb-attach
  ]
}

# resource "helm_release" "kafka" {
#   name = "${var.r_prefix}-kafka"
#   namespace = "kafka"
#   repository = "oci://registry-1.docker.io/bitnamicharts"
#   chart = "kafka"
#   version = "26.8.0"
#   depends_on = [ 
#     module.eks
#   ]
# }
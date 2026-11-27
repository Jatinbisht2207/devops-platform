output "cluster_name" {
  value = module.eks.cluster_name
}

output "kubeconfig_cmd" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

output "velero_bucket" {
  value = aws_s3_bucket.velero.id
}

output "velero_role_arn" {
  value = module.velero_irsa.iam_role_arn
}

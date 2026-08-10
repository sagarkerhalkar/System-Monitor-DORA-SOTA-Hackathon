output "aws_account_id" {
  description = "AWS account hosting the hackathon stack."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region hosting the hackathon stack."
  value       = var.aws_region
}

output "cluster_name" {
  description = "Amazon EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Amazon EKS Kubernetes API endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "kubeconfig_command" {
  description = "Command to configure kubectl after terraform apply."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.this.name}"
}

output "private_subnet_ids" {
  description = "Private EKS worker subnet IDs."
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public load-balancer/NAT subnet IDs."
  value       = aws_subnet.public[*].id
}

output "nat_gateway_public_ip" {
  description = "Public IP used by private worker-node outbound traffic."
  value       = aws_eip.nat.public_ip
}

output "ecr_repository_urls" {
  description = "ECR repository URLs keyed by service."
  value       = { for key, repository in aws_ecr_repository.services : key => repository.repository_url }
}

output "github_actions_role_arn" {
  description = "AWS IAM role assumed by GitHub Actions through OIDC."
  value       = aws_iam_role.github_actions.arn
}

output "platform_kms_key_arn" {
  description = "Customer-managed KMS key used by the hackathon platform."
  value       = aws_kms_key.platform.arn
}

output "secrets_manager_arns" {
  description = "Secrets Manager metadata ARNs. Secret values are not managed by this Terraform stack."
  value       = { for key, secret in aws_secretsmanager_secret.platform : key => secret.arn }
}

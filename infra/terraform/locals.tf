locals {
  cluster_name = "${var.project_name}-${var.environment}"

  availability_zones = slice(
    data.aws_availability_zones.available.names,
    0,
    var.availability_zone_count
  )

  public_subnet_cidrs = [
    for index in range(var.availability_zone_count) : cidrsubnet(var.vpc_cidr, 4, index)
  ]

  private_subnet_cidrs = [
    for index in range(var.availability_zone_count) : cidrsubnet(var.vpc_cidr, 4, index + 8)
  ]

  ecr_repositories = {
    monitor = "${var.project_name}/monitor"
    ui      = "${var.project_name}/ui"
    ai_ops  = "${var.project_name}/ai-ops"
    dora    = "${var.project_name}/dora-collector"
  }

  github_repository_full_name = "${var.github_owner}/${var.github_repository}"

  github_oidc_subjects = [
    "repo:${local.github_repository_full_name}:ref:refs/heads/${var.github_deploy_branch}",
    "repo:${local.github_repository_full_name}:environment:${var.github_environment}",
  ]

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Repository  = local.github_repository_full_name
    Hackathon   = "TWS-Phase-3-DORA-SOTA"
    Owner       = var.github_owner
  }
}

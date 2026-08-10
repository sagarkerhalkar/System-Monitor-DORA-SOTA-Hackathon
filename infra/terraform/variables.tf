variable "aws_region" {
  description = "AWS Region for the hackathon infrastructure."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Short project identifier used in resource names and tags."
  type        = string
  default     = "sagar-system-monitor"
}

variable "environment" {
  description = "Environment identifier."
  type        = string
  default     = "hackathon"
}

variable "kubernetes_version" {
  description = "Amazon EKS Kubernetes minor version."
  type        = string
  default     = "1.36"
}

variable "vpc_cidr" {
  description = "CIDR block for the hackathon VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "availability_zone_count" {
  description = "Number of availability zones. This stack is designed for 2 or 3."
  type        = number
  default     = 2

  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 3
    error_message = "availability_zone_count must be 2 or 3."
  }
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group. Two t3.large nodes are the reliable demo default for the observability stack."
  type        = list(string)
  default     = ["t3.large"]
}

variable "node_capacity_type" {
  description = "EKS managed node group capacity type. ON_DEMAND is used for demo reliability."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_desired_size" {
  description = "Desired managed node count."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum managed node count."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum managed node count."
  type        = number
  default     = 3
}

variable "node_disk_size_gib" {
  description = "Root disk size per managed node in GiB."
  type        = number
  default     = 50
}

variable "github_owner" {
  description = "GitHub owner allowed to assume the AWS OIDC role."
  type        = string
  default     = "sagarkerhalkar"
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the AWS OIDC role."
  type        = string
  default     = "System-Monitor-DORA-SOTA-Hackathon"
}

variable "github_deploy_branch" {
  description = "GitHub branch allowed to assume the AWS OIDC role."
  type        = string
  default     = "main"
}

variable "github_environment" {
  description = "GitHub Environment also allowed to assume the AWS OIDC role."
  type        = string
  default     = "production"
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub Actions OIDC provider. Set false if the AWS account already has token.actions.githubusercontent.com configured."
  type        = bool
  default     = true
}

variable "existing_github_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN when create_github_oidc_provider is false."
  type        = string
  default     = ""
}

variable "ecr_image_retention_count" {
  description = "Maximum number of recent images retained per ECR repository before older images expire."
  type        = number
  default     = 40
}

variable "secret_recovery_window_days" {
  description = "Secrets Manager recovery window. Use 7 days for the short-lived hackathon stack."
  type        = number
  default     = 7

  validation {
    condition     = var.secret_recovery_window_days == 0 || (var.secret_recovery_window_days >= 7 && var.secret_recovery_window_days <= 30)
    error_message = "secret_recovery_window_days must be 0 or between 7 and 30."
  }
}

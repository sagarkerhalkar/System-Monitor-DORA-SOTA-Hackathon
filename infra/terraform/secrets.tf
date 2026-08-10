locals {
  secret_definitions = {
    monitor_admin = {
      name        = "/${var.project_name}/${var.environment}/monitor-admin-password"
      description = "System Monitor bootstrap/admin password. Value is populated out-of-band and never stored in Terraform source."
    }
    dora_webhook_hmac = {
      name        = "/${var.project_name}/${var.environment}/dora-webhook-hmac"
      description = "HMAC secret for authenticated DORA/incident webhook ingestion."
    }
    grafana_admin = {
      name        = "/${var.project_name}/${var.environment}/grafana-admin-password"
      description = "Grafana administrator password for the hackathon observability stack."
    }
  }
}

resource "aws_secretsmanager_secret" "platform" {
  for_each = local.secret_definitions

  name                    = each.value.name
  description             = each.value.description
  kms_key_id              = aws_kms_key.platform.arn
  recovery_window_in_days = var.secret_recovery_window_days

  tags = {
    Name             = each.value.name
    RotationRequired = "true"
    SecretKey        = each.key
  }
}

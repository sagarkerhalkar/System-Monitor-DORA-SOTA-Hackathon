resource "aws_kms_key" "platform" {
  description             = "Sagar System Monitor hackathon platform encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${local.cluster_name}-platform-kms"
  }
}

resource "aws_kms_alias" "platform" {
  name          = "alias/${local.cluster_name}-platform"
  target_key_id = aws_kms_key.platform.key_id
}

##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  encryption_enabled = var.cloudwatch.encryption.enabled
  # Module key ARN, or null when encryption is disabled. Resources without a
  # local encryption override inherit this value.
  encryption_key_arn = try(aws_kms_key.this[0].arn, null)

  # Decided from configuration rather than the key ARN so the plan shape stays
  # known before the key exists.
  transaction_search_spans_encrypted = (
    var.cloudwatch.transaction_search == null ? false :
    var.cloudwatch.transaction_search.spans_encryption == null ? local.encryption_enabled :
    var.cloudwatch.transaction_search.spans_encryption.type == "KMS"
  )
  transaction_search_spans_key_arn = (
    !local.transaction_search_spans_encrypted ? null :
    var.cloudwatch.transaction_search.spans_encryption == null ? local.encryption_key_arn :
    var.cloudwatch.transaction_search.spans_encryption.key_id
  )
}

# Symmetric key shared by module log groups, X-Ray traces and the Transaction
# Search aws/spans log group. The account root statement keeps IAM policies,
# including the attachable policy below, effective for this key. Rotation is
# always on; KMS keeps earlier key material to decrypt existing data.
resource "aws_kms_key" "this" {
  count = local.encryption_enabled ? 1 : 0

  description             = format("CloudWatch Logs and X-Ray encryption key for %s", local.system_name)
  deletion_window_in_days = var.cloudwatch.encryption.deletion_window_in_days
  enable_key_rotation     = true
  rotation_period_in_days = var.cloudwatch.encryption.rotation_period_in_days
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableIAMPolicies"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        # CloudWatch Logs encrypts with its Regional service principal; the
        # encryption context limits it to log groups in this account/Region.
        Sid    = "AllowCloudWatchLogsEncryption"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.region}.${data.aws_partition.current.dns_suffix}"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      }
    ]
  })
  tags = local.all_tags
}

resource "aws_kms_alias" "this" {
  count = local.encryption_enabled ? 1 : 0

  name          = format("alias/%s", coalesce(var.cloudwatch.encryption.alias_name, format("%s-observability", local.system_name)))
  target_key_id = aws_kms_key.this[0].key_id
}

# Attachable policy for roles that write to or read from data encrypted with
# the module key. CloudWatch Logs requires caller-side key access through
# kms:ViaService; X-Ray readers need kms:Decrypt. The description is static
# because changing it replaces the policy, which fails while it is attached.
resource "aws_iam_policy" "encryption" {
  count = local.encryption_enabled ? 1 : 0

  name        = coalesce(var.cloudwatch.encryption.iam_policy.name, format("%s-observability-encryption", local.system_name))
  path        = var.cloudwatch.encryption.iam_policy.path
  description = "Use of the observability KMS key through CloudWatch Logs and AWS X-Ray for encrypted log and trace delivery."
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "UseKeyThroughCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.this[0].arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "logs.${data.aws_region.current.region}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "UseKeyThroughXRay"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.this[0].arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "xray.${data.aws_region.current.region}.amazonaws.com"
          }
        }
      }
    ]
  })
  tags = local.all_tags
}

##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# AWSCC owns the Application Signals account discovery singleton.
resource "awscc_applicationsignals_discovery" "this" {
  count = var.cloudwatch.application_signals.enabled ? 1 : 0
}

resource "awscc_applicationsignals_grouping_configuration" "this" {
  count = length(var.cloudwatch.application_signals.grouping_attributes) > 0 ? 1 : 0

  grouping_attribute_definitions = [
    for group in var.cloudwatch.application_signals.grouping_attributes : {
      grouping_name          = group.grouping_name
      grouping_source_keys   = group.grouping_source_keys
      default_grouping_value = group.default_grouping_value
    }
  ]

  depends_on = [awscc_applicationsignals_discovery.this]
}

# X-Ray needs permission to write both service log groups before Transaction
# Search is enabled. AWSCC owns indexing/destination; do not also manage the
# overlapping aws_xray_indexing_rule or aws_xray_trace_segment_destination.
resource "aws_cloudwatch_log_resource_policy" "transaction_search" {
  count = var.cloudwatch.transaction_search == null ? 0 : 1

  policy_name = var.cloudwatch.transaction_search.policy_name
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowXRayToWriteTransactionSearchLogs"
      Effect = "Allow"
      Principal = {
        Service = "xray.amazonaws.com"
      }
      Action = "logs:PutLogEvents"
      Resource = [
        "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:aws/spans:*",
        "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/application-signals/data:*"
      ]
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:xray:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
        }
      }
    }]
  })
}

resource "awscc_xray_transaction_search_config" "this" {
  count = var.cloudwatch.transaction_search == null ? 0 : 1

  indexing_percentage = var.cloudwatch.transaction_search.indexing_percentage

  depends_on = [aws_cloudwatch_log_resource_policy.transaction_search]
}

# AWS manages separate X-Ray encryption, grouping and sampling controls.
resource "aws_xray_encryption_config" "this" {
  count = var.cloudwatch.xray.encryption == null ? 0 : 1

  type   = var.cloudwatch.xray.encryption.type
  key_id = var.cloudwatch.xray.encryption.key_id
}

resource "aws_xray_group" "this" {
  for_each = var.cloudwatch.xray.groups

  group_name        = each.key
  filter_expression = each.value.filter_expression
  tags              = local.all_tags

  insights_configuration {
    insights_enabled      = each.value.insights_enabled
    notifications_enabled = each.value.notifications_enabled
  }
}

resource "aws_xray_sampling_rule" "this" {
  for_each = var.cloudwatch.xray.sampling_rules

  rule_name      = each.key
  fixed_rate     = each.value.fixed_rate
  priority       = each.value.priority
  reservoir_size = each.value.reservoir_size
  host           = each.value.host
  http_method    = each.value.http_method
  resource_arn   = each.value.resource_arn
  service_name   = each.value.service_name
  service_type   = each.value.service_type
  url_path       = each.value.url_path
  attributes     = each.value.attributes
  version        = 1
  tags           = local.all_tags
}

# Account-level telemetry settings must not be enabled in an account already
# governed by an AWS Organizations telemetry-evaluation configuration.
resource "aws_observabilityadmin_telemetry_evaluation" "this" {
  count = var.cloudwatch.telemetry.evaluation == null ? 0 : 1

  all_regions = var.cloudwatch.telemetry.evaluation.all_regions
  regions     = var.cloudwatch.telemetry.evaluation.regions
}

resource "aws_observabilityadmin_telemetry_enrichment" "this" {
  count = var.cloudwatch.telemetry.enrichment ? 1 : 0
}

resource "aws_cloudwatch_log_account_policy" "this" {
  for_each = var.cloudwatch.log_account_policies

  policy_name        = each.key
  policy_document    = each.value.policy_document
  policy_type        = each.value.policy_type
  scope              = each.value.scope
  selection_criteria = each.value.selection_criteria
}


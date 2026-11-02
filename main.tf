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

locals {
  # Span ingestion (console "Ingest OpenTelemetry spans") is Transaction
  # Search. transaction_search.enabled wins, then ingest_otel_spans; a bare
  # transaction_search block still enables it as in v1.0.0.
  transaction_search_enabled = coalesce(var.cloudwatch.transaction_search == null ? null : var.cloudwatch.transaction_search.enabled, var.cloudwatch.application_signals.ingest_otel_spans, var.cloudwatch.transaction_search != null)
  transaction_search_indexing_percentage = coalesce(
    var.cloudwatch.transaction_search == null ? null : var.cloudwatch.transaction_search.indexing_percentage,
    var.cloudwatch.application_signals.trace_indexing_rate,
    1
  )
  transaction_search_policy_name = var.cloudwatch.transaction_search == null ? "CloudWatchTransactionSearch" : var.cloudwatch.transaction_search.policy_name
  # Enabling Transaction Search also starts Application Signals discovery in
  # AWS, so the module manages discovery whenever either setting is enabled.
  application_signals_enabled = var.cloudwatch.application_signals.enabled || local.transaction_search_enabled
  application_signals_import  = local.application_signals_enabled && var.cloudwatch.application_signals.import_existing
  transaction_search_import   = var.cloudwatch.transaction_search == null ? false : (local.transaction_search_enabled && var.cloudwatch.transaction_search.import_existing)
}

# AWSCC owns the Application Signals account discovery singleton. Creating it
# creates the AWSServiceRoleForCloudWatchApplicationSignals service-linked role.
resource "awscc_applicationsignals_discovery" "this" {
  count = local.application_signals_enabled ? 1 : 0
}

# Adopt singletons that already exist in the account, for example from the
# console, instead of failing to create them. Import blocks are valid only in a
# root module, which this module is when Terragrunt deploys it. Once imported,
# the block is a no-op, so the flag can stay set.
import {
  for_each = local.application_signals_import ? { discovery = 0 } : {}

  to = awscc_applicationsignals_discovery.this[each.value]
  id = data.aws_caller_identity.current.account_id
}

import {
  for_each = local.transaction_search_import ? { transaction_search = 0 } : {}

  to = awscc_xray_transaction_search_config.this[each.value]
  id = data.aws_caller_identity.current.account_id
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
  count = local.transaction_search_enabled ? 1 : 0

  policy_name = local.transaction_search_policy_name
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
  count = local.transaction_search_enabled ? 1 : 0

  indexing_percentage = local.transaction_search_indexing_percentage
  cloudwatch_logs_configuration = local.transaction_search_spans_encrypted ? {
    spans_log_group_kms_key_id = local.transaction_search_spans_key_arn
  } : null

  lifecycle {
    # X-Ray applies the spans key only when it first creates aws/spans, and
    # changing it replaces this resource, which fails while Transaction Search
    # is enabled. Re-key an existing aws/spans with AssociateKmsKey instead.
    ignore_changes = [cloudwatch_logs_configuration]
  }

  # Module log groups exist first, so a declared /aws/application-signals/data
  # is created with its key before Transaction Search would create it unkeyed.
  # Discovery is created first because this resource also starts discovery,
  # which would make a later discovery create fail as already existing.
  depends_on = [
    aws_cloudwatch_log_resource_policy.transaction_search,
    aws_cloudwatch_log_group.this,
    awscc_applicationsignals_discovery.this
  ]
}

# AWS manages separate X-Ray encryption, grouping and sampling controls. A
# local xray.encryption block wins; otherwise the module key applies.
resource "aws_xray_encryption_config" "this" {
  count = (var.cloudwatch.xray.encryption != null || local.encryption_enabled) ? 1 : 0

  type   = var.cloudwatch.xray.encryption == null ? "KMS" : var.cloudwatch.xray.encryption.type
  key_id = var.cloudwatch.xray.encryption == null ? local.encryption_key_arn : var.cloudwatch.xray.encryption.key_id
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

# A local encryption block wins; otherwise the module key applies (null keeps
# CloudWatch Logs default encryption when module encryption is disabled).
resource "aws_cloudwatch_log_group" "this" {
  for_each = var.cloudwatch.log_groups

  name                        = each.key
  retention_in_days           = each.value.retention_in_days
  log_group_class             = each.value.log_group_class
  deletion_protection_enabled = each.value.deletion_protection_enabled
  skip_destroy                = each.value.skip_destroy
  kms_key_id                  = each.value.encryption == null ? local.encryption_key_arn : each.value.encryption.key_id
  tags                        = merge(local.all_tags, each.value.tags)

  lifecycle {
    # The class is fixed at creation, so any diff forces a replacement that
    # deletes the log group and its data. AWS also starts returning ESSENTIALS
    # for INFREQUENT_ACCESS in December 2026, which this provider does not map.
    ignore_changes = [log_group_class]
  }
}


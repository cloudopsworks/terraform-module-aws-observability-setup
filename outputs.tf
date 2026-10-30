##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

output "application_signals_discovery_id" {
  description = "Application Signals account discovery ID, or null when discovery is disabled."
  value       = try(awscc_applicationsignals_discovery.this[0].id, null)
}

output "application_signals_grouping_id" {
  description = "Application Signals account grouping configuration ID, or null when no grouping is configured."
  value       = try(awscc_applicationsignals_grouping_configuration.this[0].id, null)
}

output "transaction_search_id" {
  description = "X-Ray Transaction Search account configuration ID, or null when disabled."
  value       = try(awscc_xray_transaction_search_config.this[0].id, null)
}

output "transaction_search_log_policy_id" {
  description = "CloudWatch Logs resource policy ID that permits X-Ray Transaction Search log writes, or null when disabled."
  value       = try(aws_cloudwatch_log_resource_policy.transaction_search[0].id, null)
}

output "xray_encryption_config_id" {
  description = "X-Ray encryption configuration ID, or null when unmanaged."
  value       = try(aws_xray_encryption_config.this[0].id, null)
}

output "xray_group_arns" {
  description = "ARNs of X-Ray groups created by this module, keyed by group name."
  value       = { for name, group in aws_xray_group.this : name => group.arn }
}

output "xray_sampling_rule_arns" {
  description = "ARNs of X-Ray sampling rules created by this module, keyed by rule name."
  value       = { for name, rule in aws_xray_sampling_rule.this : name => rule.arn }
}

output "telemetry_evaluation_id" {
  description = "Observability Admin account telemetry evaluation ID, or null when disabled."
  value       = try(aws_observabilityadmin_telemetry_evaluation.this[0].id, null)
}

output "telemetry_enrichment_id" {
  description = "Observability Admin resource-tag enrichment ID, or null when disabled."
  value       = try(aws_observabilityadmin_telemetry_enrichment.this[0].id, null)
}

output "log_account_policy_ids" {
  description = "CloudWatch Logs account policy IDs created by this module, keyed by policy name."
  value       = { for name, policy in aws_cloudwatch_log_account_policy.this : name => policy.id }
}

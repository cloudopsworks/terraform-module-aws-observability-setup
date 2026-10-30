## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.69.0, < 7.0.0 |
| <a name="requirement_awscc"></a> [awscc](#requirement\_awscc) | >= 1.58.0, < 2.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.71.0 |
| <a name="provider_awscc"></a> [awscc](#provider\_awscc) | 1.108.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_tags"></a> [tags](#module\_tags) | cloudopsworks/tags/local | 1.0.10 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_account_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_account_policy) | resource |
| [aws_cloudwatch_log_resource_policy.transaction_search](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_resource_policy) | resource |
| [aws_observabilityadmin_telemetry_enrichment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/observabilityadmin_telemetry_enrichment) | resource |
| [aws_observabilityadmin_telemetry_evaluation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/observabilityadmin_telemetry_evaluation) | resource |
| [aws_xray_encryption_config.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/xray_encryption_config) | resource |
| [aws_xray_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/xray_group) | resource |
| [aws_xray_sampling_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/xray_sampling_rule) | resource |
| [awscc_applicationsignals_discovery.this](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/applicationsignals_discovery) | resource |
| [awscc_applicationsignals_grouping_configuration.this](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/applicationsignals_grouping_configuration) | resource |
| [awscc_xray_transaction_search_config.this](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/xray_transaction_search_config) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cloudwatch"></a> [cloudwatch](#input\_cloudwatch) | Optional account/Region CloudWatch, Application Signals, X-Ray, and Observability Admin settings. All singleton settings are disabled unless explicitly configured. | <pre>object({<br/>    application_signals = optional(object({<br/>      enabled = optional(bool, false)<br/>      grouping_attributes = optional(list(object({<br/>        grouping_name          = string<br/>        grouping_source_keys   = list(string)<br/>        default_grouping_value = optional(string)<br/>      })), [])<br/>    }), {})<br/>    transaction_search = optional(object({<br/>      indexing_percentage = number<br/>      policy_name         = optional(string, "CloudWatchTransactionSearch")<br/>    }))<br/>    xray = optional(object({<br/>      encryption = optional(object({<br/>        type   = string<br/>        key_id = optional(string)<br/>      }))<br/>      groups = optional(map(object({<br/>        filter_expression     = string<br/>        insights_enabled      = optional(bool, false)<br/>        notifications_enabled = optional(bool, false)<br/>      })), {})<br/>      sampling_rules = optional(map(object({<br/>        fixed_rate     = number<br/>        priority       = number<br/>        reservoir_size = number<br/>        host           = optional(string, "*")<br/>        http_method    = optional(string, "*")<br/>        resource_arn   = optional(string, "*")<br/>        service_name   = optional(string, "*")<br/>        service_type   = optional(string, "*")<br/>        url_path       = optional(string, "*")<br/>        attributes     = optional(map(string), {})<br/>      })), {})<br/>    }), {})<br/>    telemetry = optional(object({<br/>      evaluation = optional(object({<br/>        all_regions = optional(bool)<br/>        regions     = optional(set(string))<br/>      }))<br/>      enrichment = optional(bool, false)<br/>    }), {})<br/>    log_account_policies = optional(map(object({<br/>      policy_document    = string<br/>      policy_type        = string<br/>      scope              = optional(string, "ALL")<br/>      selection_criteria = optional(string)<br/>    })), {})<br/>  })</pre> | `{}` | no |
| <a name="input_extra_tags"></a> [extra\_tags](#input\_extra\_tags) | Extra tags to add to the resources | `map(string)` | `{}` | no |
| <a name="input_is_hub"></a> [is\_hub](#input\_is\_hub) | Is this a hub or spoke configuration? | `bool` | `false` | no |
| <a name="input_org"></a> [org](#input\_org) | Organization details | <pre>object({<br/>    organization_name = string<br/>    organization_unit = string<br/>    environment_type  = string<br/>    environment_name  = string<br/>  })</pre> | n/a | yes |
| <a name="input_spoke_def"></a> [spoke\_def](#input\_spoke\_def) | Spoke ID Number, must be a 3 digit number | `string` | `"001"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_application_signals_discovery_id"></a> [application\_signals\_discovery\_id](#output\_application\_signals\_discovery\_id) | Application Signals account discovery ID, or null when discovery is disabled. |
| <a name="output_application_signals_grouping_id"></a> [application\_signals\_grouping\_id](#output\_application\_signals\_grouping\_id) | Application Signals account grouping configuration ID, or null when no grouping is configured. |
| <a name="output_log_account_policy_ids"></a> [log\_account\_policy\_ids](#output\_log\_account\_policy\_ids) | CloudWatch Logs account policy IDs created by this module, keyed by policy name. |
| <a name="output_telemetry_enrichment_id"></a> [telemetry\_enrichment\_id](#output\_telemetry\_enrichment\_id) | Observability Admin resource-tag enrichment ID, or null when disabled. |
| <a name="output_telemetry_evaluation_id"></a> [telemetry\_evaluation\_id](#output\_telemetry\_evaluation\_id) | Observability Admin account telemetry evaluation ID, or null when disabled. |
| <a name="output_transaction_search_id"></a> [transaction\_search\_id](#output\_transaction\_search\_id) | X-Ray Transaction Search account configuration ID, or null when disabled. |
| <a name="output_transaction_search_log_policy_id"></a> [transaction\_search\_log\_policy\_id](#output\_transaction\_search\_log\_policy\_id) | CloudWatch Logs resource policy ID that permits X-Ray Transaction Search log writes, or null when disabled. |
| <a name="output_xray_encryption_config_id"></a> [xray\_encryption\_config\_id](#output\_xray\_encryption\_config\_id) | X-Ray encryption configuration ID, or null when unmanaged. |
| <a name="output_xray_group_arns"></a> [xray\_group\_arns](#output\_xray\_group\_arns) | ARNs of X-Ray groups created by this module, keyed by group name. |
| <a name="output_xray_sampling_rule_arns"></a> [xray\_sampling\_rule\_arns](#output\_xray\_sampling\_rule\_arns) | ARNs of X-Ray sampling rules created by this module, keyed by rule name. |

##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

# Account/Region singleton settings are opt-in. Import any setting that already
# exists before enabling it here; two Terraform states must not own one setting.
variable "cloudwatch" {
  description = "Optional account/Region CloudWatch, Application Signals, X-Ray, and Observability Admin settings. All singleton settings are disabled unless explicitly configured."
  type = object({
    application_signals = optional(object({
      enabled = optional(bool, false)
      grouping_attributes = optional(list(object({
        grouping_name          = string
        grouping_source_keys   = list(string)
        default_grouping_value = optional(string)
      })), [])
    }), {})
    transaction_search = optional(object({
      indexing_percentage = number
      policy_name         = optional(string, "CloudWatchTransactionSearch")
    }))
    xray = optional(object({
      encryption = optional(object({
        type   = string
        key_id = optional(string)
      }))
      groups = optional(map(object({
        filter_expression     = string
        insights_enabled      = optional(bool, false)
        notifications_enabled = optional(bool, false)
      })), {})
      sampling_rules = optional(map(object({
        fixed_rate     = number
        priority       = number
        reservoir_size = number
        host           = optional(string, "*")
        http_method    = optional(string, "*")
        resource_arn   = optional(string, "*")
        service_name   = optional(string, "*")
        service_type   = optional(string, "*")
        url_path       = optional(string, "*")
        attributes     = optional(map(string), {})
      })), {})
    }), {})
    telemetry = optional(object({
      evaluation = optional(object({
        all_regions = optional(bool)
        regions     = optional(set(string))
      }))
      enrichment = optional(bool, false)
    }), {})
    log_account_policies = optional(map(object({
      policy_document    = string
      policy_type        = string
      scope              = optional(string, "ALL")
      selection_criteria = optional(string)
    })), {})
  })
  default  = {}
  nullable = false

  # cloudwatch: # (Optional) Account/Region settings; default {} manages nothing.
  #   application_signals: # (Optional) Application Signals settings; default {}.
  #     enabled: true # (Optional) Enable discovery; default false.
  #     grouping_attributes: # (Optional) Whole-account grouping configuration; default [].
  #       - grouping_name: "Environment" # (Required) Attribute display name, 1-128 characters.
  #         grouping_source_keys: ["deployment.environment"] # (Required) Nonempty source-key list.
  #         default_grouping_value: "unknown" # (Optional) Fallback, 1-128 characters.
  #   transaction_search: # (Optional) Enable X-Ray Transaction Search; default null.
  #     indexing_percentage: 1 # (Required) Percentage of traces indexed, 0-100; 1% is the included indexing tier.
  #     policy_name: "CloudWatchTransactionSearch" # (Optional) Account resource-policy name; default shown.
  #   xray: # (Optional) X-Ray settings; default {}.
  #     encryption: # (Optional) X-Ray trace encryption; default null.
  #       type: "NONE" # (Required) Valid values: NONE or KMS.
  #       key_id: "arn:aws:kms:region:account:key/key-id" # (Optional) CMK ARN; required when type is KMS.
  #     groups: # (Optional) Map keyed by X-Ray group name; default {}.
  #       checkout: # (Optional) Example group.
  #         filter_expression: "service(\"checkout\")" # (Required) X-Ray filter expression.
  #         insights_enabled: true # (Optional) Enable insights; default false.
  #         notifications_enabled: false # (Optional) Enable insights notifications; default false.
  #     sampling_rules: # (Optional) Map keyed by rule name; default {}.
  #       checkout: # (Optional) Example sampling rule.
  #         fixed_rate: 0.1 # (Required) Sampling fraction, 0-1.
  #         priority: 100 # (Required) Rule priority, 1-9999.
  #         reservoir_size: 1 # (Required) Requests sampled per second before fixed rate.
  #         host: "*" # (Optional) Host pattern; default "*".
  #         http_method: "*" # (Optional) HTTP method pattern; default "*".
  #         resource_arn: "*" # (Optional) Resource ARN pattern; default "*".
  #         service_name: "*" # (Optional) Service name pattern; default "*".
  #         service_type: "*" # (Optional) Service type pattern; default "*".
  #         url_path: "*" # (Optional) URL path pattern; default "*".
  #         attributes: {} # (Optional) Request-attribute match map; default {}.
  #   telemetry: # (Optional) Observability Admin account settings; default {}.
  #     evaluation: # (Optional) Account telemetry evaluation; default null.
  #       all_regions: true # (Optional) Evaluate all supported Regions; exclusive with regions.
  #       regions: ["us-east-1"] # (Optional) Selected Regions (current Region is implicit); exclusive with all_regions.
  #     enrichment: true # (Optional) Enable resource-tag enrichment; default false.
  #   log_account_policies: # (Optional) Map keyed by account policy name; default {}.
  #     example: # (Optional) Example policy; policy semantics depend on type.
  #       policy_document: '{"Fields":["requestId"]}' # (Required) Type-specific JSON document.
  #       policy_type: "FIELD_INDEX_POLICY" # (Required) AWS API types: DATA_PROTECTION_POLICY, SUBSCRIPTION_FILTER_POLICY, FIELD_INDEX_POLICY, TRANSFORMER_POLICY, METRIC_EXTRACTION_POLICY; verify provider support.
  #       scope: "ALL" # (Optional) Only valid value is ALL; default ALL.
  #       # selection_criteria: null # (Optional) Type-specific selector; default null; omit for this example.

  validation {
    condition = (
      length(var.cloudwatch.application_signals.grouping_attributes) == 0 ||
      var.cloudwatch.application_signals.enabled
    )
    error_message = "application_signals.enabled must be true when grouping_attributes are set."
  }

  validation {
    condition = alltrue([
      for group in var.cloudwatch.application_signals.grouping_attributes :
      length(group.grouping_name) >= 1 && length(group.grouping_name) <= 128 &&
      length(group.grouping_source_keys) > 0 &&
      (group.default_grouping_value == null ? true : (length(group.default_grouping_value) >= 1 && length(group.default_grouping_value) <= 128))
    ])
    error_message = "Application Signals grouping names and defaults must be 1-128 characters and source keys cannot be empty."
  }

  validation {
    condition = (
      var.cloudwatch.transaction_search == null ? true :
      (var.cloudwatch.transaction_search.indexing_percentage >= 0 &&
      var.cloudwatch.transaction_search.indexing_percentage <= 100)
    )
    error_message = "transaction_search.indexing_percentage must be between 0 and 100."
  }

  validation {
    condition = (
      var.cloudwatch.xray.encryption == null ? true :
      contains(["NONE", "KMS"], var.cloudwatch.xray.encryption.type)
    )
    error_message = "xray.encryption.type must be NONE or KMS."
  }

  validation {
    condition = (
      var.cloudwatch.xray.encryption == null ? true :
      (var.cloudwatch.xray.encryption.type == "KMS") == (var.cloudwatch.xray.encryption.key_id != null)
    )
    error_message = "xray.encryption.key_id must be supplied only when type is KMS."
  }

  validation {
    condition = alltrue([
      for rule in values(var.cloudwatch.xray.sampling_rules) :
      rule.fixed_rate >= 0 && rule.fixed_rate <= 1 &&
      rule.priority >= 1 && rule.priority <= 9999 &&
      rule.reservoir_size >= 0
    ])
    error_message = "X-Ray sampling rules require fixed_rate 0-1, priority 1-9999, and nonnegative reservoir_size."
  }

  validation {
    condition = (
      var.cloudwatch.telemetry.evaluation == null ? true :
      var.cloudwatch.telemetry.evaluation.all_regions == null ||
      var.cloudwatch.telemetry.evaluation.regions == null
    )
    error_message = "telemetry.evaluation.all_regions and regions are mutually exclusive."
  }

  validation {
    condition = alltrue([
      for policy in values(var.cloudwatch.log_account_policies) : policy.scope == "ALL"
    ])
    error_message = "log_account_policies scope must be ALL."
  }
}

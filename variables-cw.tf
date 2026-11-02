##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

# Account/Region singleton settings are opt-in. Import any setting that already
# exists (import_existing for discovery and Transaction Search) before enabling
# it here; two Terraform states must not own one setting.
variable "cloudwatch" {
  description = "(Optional) Account/Region CloudWatch, Application Signals, X-Ray, Observability Admin, log group, and KMS encryption settings. Everything is disabled unless explicitly configured. Default: {}."
  type = object({
    application_signals = optional(object({
      enabled             = optional(bool, false)
      import_existing     = optional(bool, false)
      ingest_otel_spans   = optional(bool)
      trace_indexing_rate = optional(number)
      grouping_attributes = optional(list(object({
        grouping_name          = string
        grouping_source_keys   = list(string)
        default_grouping_value = optional(string)
      })), [])
    }), {})
    transaction_search = optional(object({
      enabled             = optional(bool)
      indexing_percentage = optional(number)
      policy_name         = optional(string, "CloudWatchTransactionSearch")
      import_existing     = optional(bool, false)
      spans_encryption = optional(object({
        type   = string
        key_id = optional(string)
      }))
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
    log_groups = optional(map(object({
      retention_in_days           = optional(number)
      log_group_class             = optional(string, "STANDARD")
      deletion_protection_enabled = optional(bool)
      skip_destroy                = optional(bool, false)
      encryption = optional(object({
        type   = string
        key_id = optional(string)
      }))
      tags = optional(map(string), {})
    })), {})
    encryption = optional(object({
      enabled                 = optional(bool, false)
      alias_name              = optional(string)
      deletion_window_in_days = optional(number, 30)
      rotation_period_in_days = optional(number, 365)
      iam_policy = optional(object({
        name = optional(string)
        path = optional(string, "/")
      }), {})
    }), {})
  })
  default  = {}
  nullable = false

  # cloudwatch: # (Optional) Account/Region settings; default {} manages nothing.
  #   application_signals: # (Optional) Application Signals settings; default {}.
  #     enabled: true # (Optional) Enable discovery, which creates the AWSServiceRoleForCloudWatchApplicationSignals service-linked role; default false. Forced on while spans are ingested.
  #     ingest_otel_spans: true # (Optional) Console "Ingest OpenTelemetry spans": X-Ray sends spans to the CloudWatch Logs aws/spans log group (Transaction Search); default null (off unless a transaction_search block is set). Same setting as transaction_search.enabled; setting both to different values is rejected.
  #     trace_indexing_rate: 1 # (Optional) Console "Trace indexing rate": percentage of ingested spans indexed as trace summaries, 0-100; default null (1, the included tier). Exclusive with transaction_search.indexing_percentage; requires ingest_otel_spans or a transaction_search block.
  #     import_existing: false # (Optional) Import discovery already enabled in this account (for example from the console or by an earlier Transaction Search enablement) instead of creating it; default false. Fails when discovery does not exist; ignored while discovery is not managed, and can stay set because discovery cannot be stopped.
  #     grouping_attributes: # (Optional) Whole-account grouping configuration; default [].
  #       - grouping_name: "Environment" # (Required) Attribute display name, 1-128 characters.
  #         grouping_source_keys: ["deployment.environment"] # (Required) Nonempty source-key list.
  #         default_grouping_value: "unknown" # (Optional) Fallback, 1-128 characters.
  #   transaction_search: # (Optional) Advanced Transaction Search settings; setting the block alone also enables span ingestion (v1.0.0 behaviour); default null. Use {} to accept all defaults; an empty key is null.
  #     enabled: true # (Optional) Span ingestion switch, same setting as application_signals.ingest_otel_spans; default null (follows ingest_otel_spans, otherwise true when this block is set).
  #     indexing_percentage: 1 # (Optional) Same setting as application_signals.trace_indexing_rate (set only one), 0-100; default null (1).
  #     policy_name: "CloudWatchTransactionSearch" # (Optional) Account resource-policy name; default shown.
  #     import_existing: false # (Optional) Import Transaction Search already enabled in this account instead of creating it; default false. Fails when it is not enabled; clear it before turning ingestion off. Set the indexing rate to the current value or the import also changes it.
  #     spans_encryption: # (Optional) Local override of the aws/spans log group key; default null (module key when encryption.enabled). Applied only when Transaction Search is first enabled; later changes are ignored.
  #       type: "KMS" # (Required) NONE (no key at creation) or KMS.
  #       key_id: "arn:aws:kms:region:account:key/key-id" # (Optional) Key ARN (not a key ID or alias) in this account and Region; required when type is KMS.
  #   xray: # (Optional) X-Ray settings; default {}.
  #     encryption: # (Optional) Local override of trace encryption; default null (module key when encryption.enabled, otherwise unmanaged).
  #       type: "KMS" # (Required) Valid values: NONE or KMS.
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
  #   log_groups: # (Optional) Map keyed by log group name (1-512 of a-z A-Z 0-9 . - _ / #, not starting with aws/); default {}.
  #     /app/checkout: # (Optional) Example log group.
  #       retention_in_days: 30 # (Optional) 0 (never expire), 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288 or 3653; default null (never expire).
  #       log_group_class: "STANDARD" # (Optional) STANDARD, INFREQUENT_ACCESS or DELIVERY; default STANDARD; set at creation only, later changes are ignored.
  #       deletion_protection_enabled: true # (Optional) Block log group deletion until set to false; default null (keeps the current setting; new log groups are unprotected).
  #       skip_destroy: false # (Optional) Keep the log group and its data on destroy; default false.
  #       encryption: # (Optional) Local override of the module key; default null (module key when encryption.enabled).
  #         type: "KMS" # (Required) NONE (CloudWatch Logs default encryption) or KMS.
  #         key_id: "arn:aws:kms:region:account:key/key-id" # (Optional) Key ARN (not a key ID or alias); required when type is KMS.
  #       tags: {} # (Optional) Extra tags for this log group; default {}.
  #   encryption: # (Optional) Module KMS key for log groups, X-Ray and aws/spans; default {} (disabled).
  #     enabled: true # (Optional) Create the key, alias and attachable IAM policy, and apply the key wherever no local override is set; default false.
  #     alias_name: "observability" # (Optional) Alias without the alias/ prefix, must not start with aws/; default "<system_name>-observability".
  #     deletion_window_in_days: 30 # (Optional) Key deletion waiting period, 7-30 days; default 30.
  #     rotation_period_in_days: 365 # (Optional) Automatic key rotation period (rotation is always on), 90-2560 days; default 365.
  #     iam_policy: # (Optional) Attachable policy granting key use through CloudWatch Logs and X-Ray; default {}.
  #       name: "observability-encryption" # (Optional) Account-wide policy name, 1-128 of A-Z a-z 0-9 +=,.@_-; default "<org unit>-<env name>-<env type>-<spoke>-<region>-observability-encryption".
  #       path: "/" # (Optional) IAM path, up to 512 printable ASCII characters, beginning and ending with /; default "/".

  validation {
    condition = (
      length(var.cloudwatch.application_signals.grouping_attributes) == 0 ||
      var.cloudwatch.application_signals.enabled ||
      coalesce(var.cloudwatch.transaction_search == null ? null : var.cloudwatch.transaction_search.enabled, var.cloudwatch.application_signals.ingest_otel_spans, var.cloudwatch.transaction_search != null)
    )
    error_message = "application_signals.enabled or span ingestion must be on when grouping_attributes are set."
  }

  validation {
    condition = (
      var.cloudwatch.transaction_search == null ? true :
      var.cloudwatch.transaction_search.enabled == null || var.cloudwatch.application_signals.ingest_otel_spans == null ? true :
      var.cloudwatch.transaction_search.enabled == var.cloudwatch.application_signals.ingest_otel_spans
    )
    error_message = "transaction_search.enabled and application_signals.ingest_otel_spans control the same setting and must not disagree; set only one."
  }

  validation {
    condition = (
      var.cloudwatch.transaction_search == null ? true :
      var.cloudwatch.transaction_search.indexing_percentage == null || var.cloudwatch.application_signals.trace_indexing_rate == null
    )
    error_message = "Set the indexing rate in application_signals.trace_indexing_rate or transaction_search.indexing_percentage, not both."
  }

  validation {
    condition = (
      var.cloudwatch.transaction_search == null ? true :
      !var.cloudwatch.transaction_search.import_existing || coalesce(var.cloudwatch.transaction_search.enabled, var.cloudwatch.application_signals.ingest_otel_spans, true)
    )
    error_message = "transaction_search.import_existing requires span ingestion to be on."
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
      alltrue([for rate in [coalesce(var.cloudwatch.transaction_search == null ? null : var.cloudwatch.transaction_search.indexing_percentage, var.cloudwatch.application_signals.trace_indexing_rate, 1)] : rate >= 0 && rate <= 100])
    )
    error_message = "The indexing rate (trace_indexing_rate or indexing_percentage) must be between 0 and 100."
  }

  validation {
    condition = (
      var.cloudwatch.application_signals.trace_indexing_rate == null ||
      var.cloudwatch.application_signals.ingest_otel_spans != null ||
      var.cloudwatch.transaction_search != null
    )
    error_message = "application_signals.trace_indexing_rate has no effect unless span ingestion is configured; set application_signals.ingest_otel_spans."
  }

  validation {
    condition = (
      var.cloudwatch.transaction_search == null ? true :
      var.cloudwatch.transaction_search.spans_encryption == null ? true :
      (contains(["NONE", "KMS"], coalesce(var.cloudwatch.transaction_search.spans_encryption.type, "-")) &&
      (var.cloudwatch.transaction_search.spans_encryption.type == "KMS") == (var.cloudwatch.transaction_search.spans_encryption.key_id != null))
    )
    error_message = "transaction_search.spans_encryption.type must be NONE or KMS, and key_id must be supplied only when type is KMS."
  }

  validation {
    condition = (
      var.cloudwatch.transaction_search == null ? true :
      var.cloudwatch.transaction_search.spans_encryption == null ? true :
      var.cloudwatch.transaction_search.spans_encryption.key_id == null ? true :
      can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/[A-Za-z0-9-]+$", var.cloudwatch.transaction_search.spans_encryption.key_id))
    )
    error_message = "transaction_search.spans_encryption.key_id must be a KMS key ARN; X-Ray rejects key IDs and alias ARNs for aws/spans."
  }

  validation {
    condition = (
      var.cloudwatch.xray.encryption == null ? true :
      contains(["NONE", "KMS"], coalesce(var.cloudwatch.xray.encryption.type, "-"))
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

  validation {
    condition = alltrue([
      for name in keys(var.cloudwatch.log_groups) :
      can(regex("^[.#/_A-Za-z0-9-]{1,512}$", name)) && !startswith(name, "aws/")
    ])
    error_message = "log_groups keys must be 1-512 characters of a-z, A-Z, 0-9, '.', '-', '_', '/' or '#', and must not start with aws/."
  }

  validation {
    condition = alltrue([
      for group in values(var.cloudwatch.log_groups) :
      group.retention_in_days == null ? true : contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], group.retention_in_days)
    ])
    error_message = "log_groups retention_in_days must be 0 (never expire) or one of 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653."
  }

  validation {
    condition = alltrue([
      for group in values(var.cloudwatch.log_groups) :
      contains(["STANDARD", "INFREQUENT_ACCESS", "DELIVERY"], group.log_group_class)
    ])
    error_message = "log_groups log_group_class must be STANDARD, INFREQUENT_ACCESS, or DELIVERY."
  }

  validation {
    condition = alltrue([
      for group in values(var.cloudwatch.log_groups) :
      group.encryption == null ? true :
      (contains(["NONE", "KMS"], coalesce(group.encryption.type, "-")) &&
      (group.encryption.type == "KMS") == (group.encryption.key_id != null))
    ])
    error_message = "log_groups encryption.type must be NONE or KMS, and encryption.key_id must be supplied only when type is KMS."
  }

  validation {
    condition = alltrue([
      for group in values(var.cloudwatch.log_groups) :
      group.encryption == null ? true :
      group.encryption.key_id == null ? true :
      can(regex("^arn:[a-z-]+:kms:[a-z0-9-]+:[0-9]{12}:key/[A-Za-z0-9-]+$", group.encryption.key_id))
    ])
    error_message = "log_groups encryption.key_id must be a KMS key ARN; CloudWatch Logs does not accept key IDs or aliases."
  }

  validation {
    condition = (
      var.cloudwatch.encryption.deletion_window_in_days >= 7 &&
      var.cloudwatch.encryption.deletion_window_in_days <= 30 &&
      var.cloudwatch.encryption.rotation_period_in_days >= 90 &&
      var.cloudwatch.encryption.rotation_period_in_days <= 2560
    )
    error_message = "encryption.deletion_window_in_days must be 7-30 and encryption.rotation_period_in_days must be 90-2560."
  }

  validation {
    condition = (
      var.cloudwatch.encryption.alias_name == null ? true :
      (can(regex("^[A-Za-z0-9/_-]{1,250}$", var.cloudwatch.encryption.alias_name)) &&
        !startswith(var.cloudwatch.encryption.alias_name, "alias/") &&
      !startswith(var.cloudwatch.encryption.alias_name, "aws/"))
    )
    error_message = "encryption.alias_name must be 1-250 characters of A-Z, a-z, 0-9, '/', '_' or '-', given without the alias/ prefix, and must not start with aws/."
  }

  validation {
    condition = (
      (var.cloudwatch.encryption.iam_policy.name == null ? true :
      can(regex("^[A-Za-z0-9+=,.@_-]{1,128}$", var.cloudwatch.encryption.iam_policy.name))) &&
      can(regex("^/([!-~]{1,510}/)?$", var.cloudwatch.encryption.iam_policy.path))
    )
    error_message = "encryption.iam_policy.name must be 1-128 characters of A-Z, a-z, 0-9 or +=,.@_-, and encryption.iam_policy.path must be up to 512 printable ASCII characters without spaces, beginning and ending with '/'."
  }
}

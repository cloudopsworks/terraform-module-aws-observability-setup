locals {
  {{- if .hub_spoke }}
  local_vars  = yamldecode(file("./inputs.yaml"))
  spoke_vars  = yamldecode(file(find_in_parent_folders("spoke-inputs.yaml")))
  region_vars = yamldecode(file(find_in_parent_folders("region-inputs.yaml")))
  env_vars    = yamldecode(file(find_in_parent_folders("env-inputs.yaml")))
  global_vars = yamldecode(file(find_in_parent_folders("global-inputs.yaml")))

  local_tags  = jsondecode(file("./local-tags.json"))
  spoke_tags  = jsondecode(file(find_in_parent_folders("spoke-tags.json")))
  region_tags = jsondecode(file(find_in_parent_folders("region-tags.json")))
  env_tags    = jsondecode(file(find_in_parent_folders("env-tags.json")))
  global_tags = jsondecode(file(find_in_parent_folders("global-tags.json")))

  tags = merge(
    local.global_tags,
    local.env_tags,
    local.region_tags,
    local.spoke_tags,
    local.local_tags
  )
  {{- else }}
  local_vars  = yamldecode(file("./inputs.yaml"))
  env_vars    = yamldecode(file(find_in_parent_folders("env-inputs.yaml")))
  global_vars = yamldecode(file(find_in_parent_folders("global-inputs.yaml")))
  global_tags = jsondecode(file(find_in_parent_folders("global-tags.json")))
  local_tags  = jsondecode(file("./local-tags.json"))

  tags = merge(
    local.global_tags,
    local.local_tags
  )
  {{- end }}
}

include "root" {
  path = find_in_parent_folders("root.hcl")
  # Exposes the root config so the awscc provider below can reuse its region and role.
  # Terragrunt does not merge an included config's locals into the including config;
  # expose is the documented way to read them, as include.root.locals.<name>.
  expose = true
}

# root.hcl generates the aws provider only. This module also manages Application Signals
# discovery and X-Ray Transaction Search, which AWS exposes through Cloud Control, so it
# needs the awscc provider pointed at the same region and role. Left unconfigured, awscc
# falls back to its own default credential and region chain and acts on the wrong account
# or region -- which surfaces as "Cannot import non-existent remote object" on import, or
# as a spurious create that then fails with AlreadyExists.
#
# awscc is plugin-framework based: assume_role is a nested attribute assigned with "=", not
# a block as in the aws provider. Copying the aws block verbatim fails to parse. Remove
# assume_role when the root assumes the role itself (iam_role).
generate "provider_awscc" {
  path      = "provider-awscc.g.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "awscc" {
  region = "${include.root.locals.region}"
  assume_role = {
    role_arn     = "${include.root.locals.sts_role_arn}"
    session_name = "terragrunt"
  }
}
EOF
}

terraform {
  source = "{{ .sourceUrl }}"
}

inputs = {
  # org = {
  #   organization_name = local.env_vars.org.organization_name
  #   organization_unit = local.env_vars.org.organization_unit
  #   environment_name  = local.env_vars.org.environment_name
  #   environment_type  = local.env_vars.org.environment_type
  # }
  org = local.env_vars.org
  {{- if .hub_spoke }}
  is_hub = {{ .is_hub }}
  spoke_def = local.spoke_vars.spoke_def
  {{- end}}
  ## Required
  {{- range .requiredVariables }}
  {{- if ne .Name "org" }}
  {{ .Name }} = try(local.local_vars.{{ .Name }}, {{ .DefaultValue }})
  {{- end }}
  {{- end }}

  ## Optional
  {{- range .optionalVariables }}
  {{- if and (ne .Name "extra_tags") (ne .Name "is_hub") (ne .Name "spoke_def") (ne .Name "org") }}
  {{ .Name }} = try(local.local_vars.{{ .Name }}, {{ .DefaultValue }})
  {{- end }}
  {{- end }}
  extra_tags = local.tags
}

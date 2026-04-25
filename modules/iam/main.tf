resource "google_service_account" "this" {
  for_each = var.service_accounts

  account_id   = each.key
  display_name = each.value.display_name
  project      = var.project_id
}

# Flatten service accounts + roles into a unique set of bindings.
locals {
  role_bindings = flatten([
    for sa_key, sa in var.service_accounts : [
      for role in sa.roles : {
        key    = "${sa_key}__${role}"
        sa_key = sa_key
        role   = role
      }
    ]
  ])

  role_bindings_map = {
    for binding in local.role_bindings : binding.key => binding
  }
}

resource "google_project_iam_member" "this" {
  for_each = local.role_bindings_map

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.this[each.value.sa_key].email}"
}

output "service_account_emails" {
  description = "Map of service account ID to its email address."
  value = {
    for key, sa in google_service_account.this : key => sa.email
  }
}

output "service_account_ids" {
  description = "Map of service account ID to its unique ID."
  value = {
    for key, sa in google_service_account.this : key => sa.unique_id
  }
}

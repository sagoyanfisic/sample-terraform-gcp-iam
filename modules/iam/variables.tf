variable "project_id" {
  description = "The GCP project ID where resources will be created."
  type        = string
}

variable "service_accounts" {
  description = "Map of service accounts to create. Key is the account ID (e.g. sa-backend-dev)."
  type = map(object({
    display_name = string
    roles        = list(string)
  }))
  default = {}
}

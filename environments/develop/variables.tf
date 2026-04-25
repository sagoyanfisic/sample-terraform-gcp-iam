variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "region" {
  description = "The default GCP region."
  type        = string
  default     = "us-central1"
}

variable "service_accounts" {
  description = "Map of service accounts to create. Key is the account ID."
  type = map(object({
    display_name = string
    roles        = list(string)
  }))
  default = {}
}

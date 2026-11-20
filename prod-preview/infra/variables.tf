variable "project_id" {
  type        = string
  description = "Short-lived GCP project ID for the POC"
}

variable "region" {
  type        = string
  default     = "europe-west1"
  description = "Primary GCP region (e.g. europe-west1 for EU residency)"
}

variable "poc_id" {
  type        = string
  description = "Unique identifier for this POC review"
}

variable "app_image" {
  type        = string
  description = "Container image URI for the Cloud Run POC workload"
}

variable "billing_account_id" {
  type        = string
  description = "GCP Billing Account ID for budget cap enforcement"
}

variable "budget_cap_usd" {
  type        = number
  default     = 450
  description = "Hard monthly budget cap in USD"
}

variable "enable_ha_db" {
  type        = bool
  default     = false
  description = "Enable regional standby for Cloud SQL"
}

variable "teardown_days" {
  type        = number
  default     = 7
  description = "Number of days before scheduled teardown"
}

variable "teardown_cron" {
  type        = string
  default     = "0 2 * * *"
  description = "Cron schedule checked by teardown controller"
}

variable "teardown_webhook_url" {
  type        = string
  description = "Authenticated Cloud Run / Cloud Functions teardown webhook endpoint"
}

variable "scheduler_service_account" {
  type        = string
  description = "Service account used by Cloud Scheduler OIDC calls"
}

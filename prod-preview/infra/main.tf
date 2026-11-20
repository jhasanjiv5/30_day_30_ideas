terraform {
  required_version = ">= 1.7.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  common_labels = {
    managed_by    = "prod-preview"
    poc_id        = var.poc_id
    teardown_days = tostring(var.teardown_days)
  }
}

resource "google_cloud_run_v2_service" "poc_app" {
  name     = "${var.poc_id}-app"
  location = var.region
  labels   = local.common_labels

  template {
    scaling {
      min_instance_count = 0
      max_instance_count = 12
    }
    containers {
      image = var.app_image
      resources {
        limits = {
          cpu    = "1"
          memory = "2Gi"
        }
      }
      env {
        name  = "POC_ID"
        value = var.poc_id
      }
    }
  }
}

resource "google_sql_database_instance" "poc_db" {
  name             = "${var.poc_id}-db"
  database_version = "POSTGRES_16"
  region           = var.region

  settings {
    tier              = "db-custom-2-7680"
    availability_type = var.enable_ha_db ? "REGIONAL" : "ZONAL"
    user_labels       = local.common_labels
  }

  deletion_protection = false
}

resource "google_billing_budget" "poc_hard_cap" {
  billing_account = var.billing_account_id
  display_name    = "${var.poc_id}-hard-cap-budget"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.budget_cap_usd)
    }
  }

  threshold_rules {
    threshold_percent = 0.8
    spend_basis       = "CURRENT_SPEND"
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }
}

resource "google_cloud_scheduler_job" "poc_teardown" {
  name        = "${var.poc_id}-teardown"
  description = "Automated POC teardown after ${var.teardown_days} days"
  schedule    = var.teardown_cron
  time_zone   = "UTC"
  region      = var.region

  http_target {
    http_method = "POST"
    uri         = var.teardown_webhook_url
    body        = base64encode(jsonencode({ poc_id = var.poc_id, project_id = var.project_id }))
    oidc_token {
      service_account_email = var.scheduler_service_account
    }
  }
}

output "cloud_run_url" {
  value       = google_cloud_run_v2_service.poc_app.uri
  description = "Live HTTPS URL of the preview Cloud Run service"
}

output "cloud_sql_connection_name" {
  value       = google_sql_database_instance.poc_db.connection_name
  description = "Cloud SQL instance connection name"
}

output "teardown_scheduler_job" {
  value       = google_cloud_scheduler_job.poc_teardown.name
  description = "Cloud Scheduler job managing POC expiry teardown"
}

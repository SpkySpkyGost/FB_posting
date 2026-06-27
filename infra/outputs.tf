output "production_url" {
  description = "Live URL of the deployed microsite."
  value       = "https://${vercel_deployment.production.url}"
}

output "vercel_project_id" {
  description = "Vercel project ID."
  value       = vercel_project.app.id
}

output "neon_database_name" {
  description = "Name of the provisioned Neon database."
  value       = neon_project.db.database_name
}

output "neon_connection_uri_pooler" {
  description = "Pooled Neon connection string used as DATABASE_URL."
  value       = neon_project.db.connection_uri_pooler
  sensitive   = true
}

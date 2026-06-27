# ──────────────────────────────────────────────────────────────────────────
#  1. Neon — serverless Postgres
#     Creating a neon_project auto-provisions a default branch, role, and
#     database, and exposes a ready-to-use pooled connection string.
# ──────────────────────────────────────────────────────────────────────────

resource "neon_project" "db" {
  name      = var.project_name
  org_id    = var.neon_org_id
  region_id = var.neon_region

  history_retention_seconds = 21600   # 6h — Free plan maximum

  default_endpoint_settings {
    autoscaling_limit_min_cu = 0.25
    autoscaling_limit_max_cu = 1
  }
}

# ──────────────────────────────────────────────────────────────────────────
#  2. Vercel — project connected to the GitHub repository
#     The build/runtime behaviour (Python WSGI + build.sh) is defined by the
#     vercel.json already committed in the repo.
# ──────────────────────────────────────────────────────────────────────────

resource "vercel_project" "app" {
  name = var.project_name

  git_repository = {
    type              = "github"
    repo              = var.github_repo
    production_branch = var.git_branch
  }
}

# ──────────────────────────────────────────────────────────────────────────
#  3. Environment variables
#     DATABASE_URL is sourced directly from Neon's pooled connection URI, so
#     the database and the app are wired together with no manual copy/paste.
# ──────────────────────────────────────────────────────────────────────────

locals {
  env_target = ["production", "preview"]
}

resource "vercel_project_environment_variable" "database_url" {
  project_id = vercel_project.app.id
  key        = "DATABASE_URL"
  value      = neon_project.db.connection_uri_pooler
  target     = local.env_target
  sensitive  = true
}

resource "vercel_project_environment_variable" "secret_key" {
  project_id = vercel_project.app.id
  key        = "SECRET_KEY"
  value      = var.django_secret_key
  target     = local.env_target
  sensitive  = true
}

resource "vercel_project_environment_variable" "debug" {
  project_id = vercel_project.app.id
  key        = "DEBUG"
  value      = var.debug
  target     = local.env_target
  sensitive  = false
}

resource "vercel_project_environment_variable" "allowed_hosts" {
  project_id = vercel_project.app.id
  key        = "ALLOWED_HOSTS"
  value      = var.allowed_hosts
  target     = local.env_target
  sensitive  = false
}

resource "vercel_project_environment_variable" "fb_page_id" {
  project_id = vercel_project.app.id
  key        = "FB_PAGE_ID"
  value      = var.fb_page_id
  target     = local.env_target
  sensitive  = false
}

resource "vercel_project_environment_variable" "fb_page_access_token" {
  project_id = vercel_project.app.id
  key        = "FB_PAGE_ACCESS_TOKEN"
  value      = var.fb_page_access_token
  target     = local.env_target
  sensitive  = true
}

resource "vercel_project_environment_variable" "fb_graph_version" {
  project_id = vercel_project.app.id
  key        = "FB_GRAPH_VERSION"
  value      = var.fb_graph_version
  target     = local.env_target
  sensitive  = false
}

resource "vercel_project_environment_variable" "buffer_access_token" {
  project_id = vercel_project.app.id
  key        = "BUFFER_ACCESS_TOKEN"
  value      = var.buffer_access_token
  target     = local.env_target
  sensitive  = true
}

resource "vercel_project_environment_variable" "buffer_profile_id" {
  project_id = vercel_project.app.id
  key        = "BUFFER_PROFILE_ID"
  value      = var.buffer_profile_id
  target     = local.env_target
  sensitive  = false
}

# ──────────────────────────────────────────────────────────────────────────
#  4. Production deployment
#     Builds the connected repo at the chosen branch and promotes it to
#     production, so `terraform apply` results in a live URL.
# ──────────────────────────────────────────────────────────────────────────

resource "vercel_deployment" "production" {
  project_id = vercel_project.app.id
  ref        = var.git_branch
  production = true

  # Ensure env vars (especially DATABASE_URL) exist before the build runs.
  depends_on = [
    vercel_project_environment_variable.database_url,
    vercel_project_environment_variable.secret_key,
    vercel_project_environment_variable.debug,
    vercel_project_environment_variable.allowed_hosts,
    vercel_project_environment_variable.fb_page_id,
    vercel_project_environment_variable.fb_page_access_token,
    vercel_project_environment_variable.fb_graph_version,
    vercel_project_environment_variable.buffer_access_token,
    vercel_project_environment_variable.buffer_profile_id,
  ]
}

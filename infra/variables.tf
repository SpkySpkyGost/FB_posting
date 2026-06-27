# ──────────────────────────────────────────────────────────────────────────
#  Provider credentials (secret — supply via tfvars or TF_VAR_* env vars)
# ──────────────────────────────────────────────────────────────────────────

variable "vercel_api_token" {
  description = "Vercel API token with read/write access to projects."
  type        = string
  sensitive   = true
}

variable "vercel_team_id" {
  description = "Vercel team ID. Leave null for a personal account."
  type        = string
  default     = null
}

variable "neon_api_key" {
  description = "Neon API key (https://console.neon.tech -> Account -> API keys)."
  type        = string
  sensitive   = true
}

variable "neon_org_id" {
  description = "Neon organization ID. Recommended to avoid duplicate projects."
  type        = string
  default     = null
}

# ──────────────────────────────────────────────────────────────────────────
#  Project / infrastructure configuration
# ──────────────────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Name used for both the Vercel project and the Neon project."
  type        = string
  default     = "marketing-microsite"
}

variable "github_repo" {
  description = "GitHub repository in 'owner/repo' form to deploy from."
  type        = string
}

variable "git_branch" {
  description = "Git branch to deploy to production."
  type        = string
  default     = "main"
}

variable "neon_region" {
  description = "Neon deployment region (see https://neon.tech/docs/introduction/regions)."
  type        = string
  default     = "aws-eu-central-1"
}

# ──────────────────────────────────────────────────────────────────────────
#  Django application settings
# ──────────────────────────────────────────────────────────────────────────

variable "django_secret_key" {
  description = "Django SECRET_KEY."
  type        = string
  sensitive   = true
}

variable "debug" {
  description = "Django DEBUG flag. Keep 'False' in production."
  type        = string
  default     = "False"
}

variable "allowed_hosts" {
  description = "Comma-separated Django ALLOWED_HOSTS."
  type        = string
  default     = ".vercel.app,localhost,127.0.0.1"
}

# ──────────────────────────────────────────────────────────────────────────
#  Marketing integrations
# ──────────────────────────────────────────────────────────────────────────

variable "fb_page_id" {
  description = "Facebook page ID (Direct mode)."
  type        = string
  default     = ""
}

variable "fb_page_access_token" {
  description = "Facebook page access token (Direct mode)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "fb_graph_version" {
  description = "Facebook Graph API version."
  type        = string
  default     = "v25.0"
}

variable "buffer_access_token" {
  description = "Buffer OAuth access token (Orchestrated mode)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "buffer_profile_id" {
  description = "Buffer channel ID (passed as channelId)."
  type        = string
  default     = ""
}

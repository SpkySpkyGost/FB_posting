# Credentials are passed as variables so nothing secret lives in the code.
# You can supply them either via a gitignored terraform.tfvars file or via
# environment variables (TF_VAR_vercel_api_token, TF_VAR_neon_api_key).

provider "vercel" {
  api_token = var.vercel_api_token
  # team_id is only required when the project lives under a Vercel team
  # rather than a personal account. Leave null for a personal account.
  team      = var.vercel_team_id
}

provider "neon" {
  api_key = var.neon_api_key
}

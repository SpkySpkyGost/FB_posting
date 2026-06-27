terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # Deploys the Vercel project, environment variables, and production build.
    vercel = {
      source  = "vercel/vercel"
      version = ">= 1.13"
    }

    # Provisions the Neon serverless Postgres project + database.
    neon = {
      source  = "kislerdm/neon"
      version = ">= 0.6"
    }
  }
}

# Marketing Microsite

This service acts as a marketing gateway capable of publishing content and tracking analytics via two distinct execution flows: **Direct API Access** (Facebook Graph API) and **Orchestrated Integration** (Buffer GraphQL API).

## 1. System Architecture & Tech Stack

The application is engineered as a serverless monolithic Django application optimized for high scalability and zero-maintenance infrastructure.

* **Framework:** Django 4.2.30 running on Python 3.13
* **Database:** Neon Serverless PostgreSQL (fully managed, autoscaling)
* **Hosting Platform:** Vercel Serverless Functions (`@vercel/python` runtime)
* **Static Assets Handling:** WhiteNoise 6.11.0

## 2. Infrastructure Setup & Requirements

### Neon Database Provisioning
1. Create a serverless PostgreSQL instance on [Neon](https://neon.tech).
2. Retrieve your connection string (Connection Pooling connection mode is highly recommended).
3. The string format should align with:
   `postgresql://[user]:[password]@[host]/[dbname]?sslmode=require&channel_binding=require`

### Vercel Serverless Architecture
Vercel hosts the application via two main blocks declared in `vercel.json`:
* **WSGI (Web Server Gateway Interface):** Handles live routing and processes incoming HTTP requests.
* **Static Build Lifecycle:** Triggers `build.sh` at compile time to prepare the deployment container environment, run migrations, and collect static files.

> For deployment, the Neon database and the Vercel project (including all environment variables) are provisioned automatically via Terraform — see **Section 7: Deployment (Infrastructure as Code)**. The manual steps above are only needed if you prefer to set things up by hand for local development.

## 3. Local Development

1. Clone the repository.
2. Create a virtual environment: `python3 -m venv venv` and activate it.
3. Install dependencies: `pip install -r requirements.txt`.
4. Copy `.env.example` to `.env` and fill in your secrets (see Environment Variables).
5. Run migrations: `python manage.py migrate`.
6. Start the local server: `python manage.py runserver`.

## 4. Environment Variables Reference

These keys must be added directly into the **Vercel Project Settings > Environment Variables** panel for deployment, and in your local `.env` file for development. Never commit raw values to version control.

| Variable Name | Description | Example / Format |
| :--- | :--- | :--- |
| `SECRET_KEY` | Django framework cryptographic signature key | `your-secret-key` |
| `DEBUG` | Operational visibility toggle (Set to `False` in Prod) | `True` / `False` |
| `ALLOWED_HOSTS` | Authorized request routing headers | `.vercel.app,localhost,127.0.0.1` |
| `DATABASE_URL` | Neon PostgreSQL pooled connection string | `postgresql://neondb_owner:...` |
| `FB_PAGE_ID` | Facebook business page node targeting identifier | `123456789012345` |
| `FB_PAGE_ACCESS_TOKEN` | Direct API authentication bearer token | `EAAb...` |
| `FB_GRAPH_VERSION` | Targeted Facebook Graph API version | `v25.0` |
| `BUFFER_ACCESS_TOKEN` | Authenticated OAuth credential for Orchestrated mode | `b100...` |
| `BUFFER_PROFILE_ID` | Buffer channel ID (passed as `channelId` in the GraphQL mutation) | `66a0...` |

## 5. Core Operational Workflows

The platform isolates marketing workflows into decoupled service routines inside `services.py`, selected at runtime by the `get_marketing_service(mode)` factory.

### Workflow A: Direct Execution Mode (Facebook Graph API)
`[User Action: Post] ──> [Django View] ──> [FacebookMarketingService] ──> [Direct Graph API HTTP Post]`
* **Publishing Target:** Direct submission to the specified `{FB_PAGE_ID}/feed` edge.
* **Metrics Extraction:** Performs a `GET` on the post node, requesting the `reactions`, `comments`, and `shares` summary fields, then normalizes the counts.

### Workflow B: Orchestrated Execution Mode (Buffer GraphQL API)
`[User Action: Post] ──> [Django View] ──> [BufferMarketingService] ──> [Buffer GraphQL API]`
* **Publishing Target:** Submits a `createPost` GraphQL mutation (in `shareNow` mode) to the channel mapped via `BUFFER_PROFILE_ID`.
* **Metrics Extraction:** Runs a GraphQL `post(input: { id })` query against a single Buffer post ID, then normalizes the returned per-post `metrics` array (reactions, comments, shares) along with the `metricsUpdatedAt` timestamp.

> **Note:** The two flows are fully isolated — the Buffer service does not bridge to or fall back on the Facebook Graph API.

## 6. System Design Exceptions & Fail-safes

* **PEP 668 Environment Overrides:** Due to Vercel's modern, externally-managed Python build environment, dependencies are explicitly provisioned using the `--break-system-packages` flag in `build.sh` to bypass system package-isolation blocks on ephemeral build systems.
* **Network Request Latency Protection:** External calls are bounded by per-service timeouts (`TIMEOUT_VAL_BUFFER` and `TIMEOUT_VAL_META`, both 10s) to prevent remote task starvation.
* **Database Scalability Limits:** The application disables server-side cursors (`DISABLE_SERVER_SIDE_CURSORS: True`) in the database configuration. This prevents serverless container spin-ups from generating hanging memory pools on your Neon connection nodes.

## 7. Deployment (Infrastructure as Code)

The entire deployment is reproducible from the repository using **Terraform** (or OpenTofu). The configuration in `infra/` provisions everything with a single apply:

* **Neon** — creates the serverless Postgres project, branch, role, and database (`neon_project`).
* **Vercel** — creates the project connected to this GitHub repo, injects every environment variable (including `DATABASE_URL`, sourced directly from Neon's pooled connection string), and promotes a production deployment.

No dashboard clicking is required, and no secret values are committed: credentials are supplied as Terraform variables via a gitignored `terraform.tfvars` (or `TF_VAR_*` environment variables).

### Prerequisites
* Terraform `>= 1.5`.
* A **Vercel API token** and, if applicable, your **team ID**.
* A **Neon API key** (and recommended **organization ID**).
* The **Vercel for GitHub** app installed on the target repository (one-time, account-level — this is what lets Vercel build on push).
* NOTE: you can setup your own projects but this code works when Vercel and Neon don't have initiated projects yet.

### Steps
```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # then fill in your values
terraform init
terraform plan
terraform apply
```
On success, Terraform prints the live `production_url`. Re-running `terraform apply` after pushing code redeploys; `terraform destroy` tears down the database and project.

### Files
| File | Purpose |
| :--- | :--- |
| `infra/versions.tf` | Required Terraform + provider versions (`vercel/vercel`, `kislerdm/neon`) |
| `infra/providers.tf` | Provider auth (tokens passed as variables) |
| `infra/variables.tf` | All inputs; secrets marked `sensitive` |
| `infra/main.tf` | Neon project, Vercel project, env vars, production deployment |
| `infra/outputs.tf` | Live URL, project ID, DB connection details |
| `infra/terraform.tfvars.example` | Template for your (gitignored) `terraform.tfvars` |
| `infra/.gitignore` | Keeps state files and real secrets out of version control |

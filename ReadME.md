# Marketing Microsite

This service acts as a marketing gateway capable of publishing content and tracking analytics via two distinct execution flows: **Direct API Access** (Facebook Graph API) and **Orchestrated Integration** (Buffer API).

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
| `FB_GRAPH_VERSION` | Targeted Facebook backend API engine schema | `v25.0` |
| `BUFFER_ACCESS_TOKEN` | Authenticated OAuth credential for Orchestrated mode | `b100...` |
| `BUFFER_PROFILE_ID` | Specific social profile endpoint mapped in Buffer | `66a0...` |

## 5. Core Operational Workflows

The platform isolates marketing workflows into decoupled service routines inside `services.py`, controlled by the core interactive schema layer.

### Workflow A: Direct Execution Mode (Facebook Graph API)
`[User Action: Post] ──> [Django View] ──> [FacebookMarketingService] ──> [Direct Graph API HTTP Post]`
* **Publishing Target:** Direct entry submission to the specified `{FB_PAGE_ID}/feed`.
* **Metrics Extraction:** Polls individual node edges directly from Facebook's metadata servers.

### Workflow B: Orchestrated Execution Mode (Buffer API)
`[User Action: Post] ──> [Django View] ──> [BufferMarketingService] ──> [Buffer Queue API]`
* **Publishing Target:** Dispatches payloads into the Buffer platform pipeline mapped via `BUFFER_PROFILE_ID`.
* **Metrics Extraction:** Pulls aggregated and normalized channel profile performance directly via Buffer's analytics endpoints.

## 6. System Design Exceptions & Fail-safes

* **PEP 668 Environment Overrides:** Due to Vercel's use of modern distribution patterns (`uv`), dependencies are explicitly provisioned utilizing the `--break-system-packages` pipeline flag to force system block bypasses on ephemeral build systems.
* **Network Request Latency Protection:** External connection targets to the Buffer API are configured with safety buffers (`TIMEOUT_VAL_BUFFER`) to prevent remote task starvation. 
* **Database Scalability Limits:** The application disables server-side cursors (`DISABLE_SERVER_SIDE_CURSORS: True`) within the database configurations. This prevents serverless container spin-ups from generating hanging memory pools on your Neon connection nodes.
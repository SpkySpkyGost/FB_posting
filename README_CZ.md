# Marketingový mikroweb

Tato služba funguje jako marketingová brána schopná publikovat obsah a sledovat analytická data prostřednictvím dvou odlišných exekučních toků: **Přímý přístup k API** (Facebook Graph API) a **Orchestrovaná integrace** (Buffer GraphQL API).

## 1. Architektura systému a technologie

Aplikace je navržena jako bezserverová monolitická Django aplikace optimalizovaná pro vysokou škálovatelnost a bezúdržbovou infrastrukturu.

* **Framework:** Django 4.2.30 běžící na Pythonu 3.13
* **Databáze:** Neon Serverless PostgreSQL (plně spravovaná, automaticky škálovaná)
* **Hostingová platforma:** Vercel Serverless Functions (běhové prostředí `@vercel/python`)
* **Správa statických souborů:** WhiteNoise 6.11.0

## 2. Nastavení infrastruktury a požadavky

### Zřízení databáze Neon
1. Vytvořte bezserverovou instanci PostgreSQL na [Neon](https://neon.tech).
2. Získejte svůj připojovací řetězec (důrazně doporučujeme režim Connection Pooling).
3. Formát řetězce by měl odpovídat:
   `postgresql://[user]:[password]@[host]/[dbname]?sslmode=require&channel_binding=require`

### Bezserverová architektura Vercel
Vercel hostuje aplikaci pomocí dvou hlavních bloků deklarovaných v `vercel.json`:
* **WSGI (Web Server Gateway Interface):** Obstarává živé směrování a zpracovává příchozí HTTP požadavky.
* **Životní cyklus statického buildu:** Spouští `build.sh` v době kompilace, aby připravil prostředí nasazovacího kontejneru, provedl migrace a shromáždil statické soubory.

> Pro nasazení jsou databáze Neon a projekt Vercel (včetně všech proměnných prostředí) zřizovány automaticky pomocí Terraformu — viz **Sekce 7: Nasazení (Infrastruktura jako kód)**. Výše uvedené manuální kroky jsou potřeba pouze tehdy, pokud dáváte přednost ručnímu nastavení pro lokální vývoj.

## 3. Lokální vývoj

1. Naklonujte repozitář.
2. Vytvořte virtuální prostředí: `python3 -m venv venv` a aktivujte ho.
3. Nainstalujte závislosti: `pip install -r requirements.txt`.
4. Zkopírujte `.env.example` do `.env` a vyplňte své tajné údaje (viz Proměnné prostředí).
5. Proveďte migrace: `python manage.py migrate`.
6. Spusťte lokální server: `python manage.py runserver`.

## 4. Přehled proměnných prostředí

Tyto klíče musí být přidány přímo do panelu **Vercel Project Settings > Environment Variables** pro nasazení a do vašeho lokálního souboru `.env` pro vývoj. Nikdy nevkládejte skutečné hodnoty do verzovacího systému.

| Název proměnné | Popis | Příklad / Formát |
| :--- | :--- | :--- |
| `SECRET_KEY` | Kryptografický podpisový klíč frameworku Django | `your-secret-key` |
| `DEBUG` | Přepínač provozní viditelnosti (v produkci nastavte na `False`) | `True` / `False` |
| `ALLOWED_HOSTS` | Autorizované hlavičky pro směrování požadavků | `.vercel.app,localhost,127.0.0.1` |
| `DATABASE_URL` | Sdružený (pooled) připojovací řetězec Neon PostgreSQL | `postgresql://neondb_owner:...` |
| `FB_PAGE_ID` | Identifikátor cílové firemní stránky na Facebooku | `123456789012345` |
| `FB_PAGE_ACCESS_TOKEN` | Autentizační bearer token pro přímé API | `EAAb...` |
| `FB_GRAPH_VERSION` | Cílová verze Facebook Graph API | `v25.0` |
| `BUFFER_ACCESS_TOKEN` | Ověřený OAuth údaj pro orchestrovaný režim | `b100...` |
| `BUFFER_PROFILE_ID` | ID kanálu Buffer (předáváno jako `channelId` v GraphQL mutaci) | `66a0...` |

## 5. Hlavní provozní toky

Platforma odděluje marketingové toky do samostatných servisních rutin uvnitř `services.py`, které jsou za běhu vybírány továrnou (factory) `get_marketing_service(mode)`.

### Tok A: Režim přímé exekuce (Facebook Graph API)
`[Akce uživatele: Příspěvek] ──> [Django View] ──> [FacebookMarketingService] ──> [Přímé HTTP odeslání na Graph API]`
* **Cíl publikování:** Přímé odeslání na zadanou hranu (edge) `{FB_PAGE_ID}/feed`.
* **Získávání metrik:** Provede `GET` na uzel příspěvku, vyžádá si souhrnná pole `reactions`, `comments` a `shares` a následně počty normalizuje.

### Tok B: Režim orchestrované exekuce (Buffer GraphQL API)
`[Akce uživatele: Příspěvek] ──> [Django View] ──> [BufferMarketingService] ──> [Buffer GraphQL API]`
* **Cíl publikování:** Odešle GraphQL mutaci `createPost` (v režimu `shareNow`) do kanálu namapovaného přes `BUFFER_PROFILE_ID`.
* **Získávání metrik:** Spustí GraphQL dotaz `post(input: { id })` proti konkrétnímu ID příspěvku Buffer a poté normalizuje vrácené pole `metrics` daného příspěvku (reactions, comments, shares) společně s časovou značkou `metricsUpdatedAt`.

> **Poznámka:** Oba toky jsou plně oddělené — služba Buffer se nepropojuje s Facebook Graph API ani na ně nepřechází jako záloha.

## 6. Výjimky v návrhu systému a pojistky

* **Obejití prostředí dle PEP 668:** Kvůli modernímu, externě spravovanému buildovému prostředí Pythonu na Vercelu jsou závislosti explicitně instalovány pomocí příznaku `--break-system-packages` v `build.sh`, aby se obešly bloky izolace systémových balíčků na efemérních buildovacích systémech.
* **Ochrana před latencí síťových požadavků:** Externí volání jsou omezena časovými limity jednotlivých služeb (`TIMEOUT_VAL_BUFFER` a `TIMEOUT_VAL_META`, oba 10 s), aby se zabránilo vyhladovění (starvation) vzdálených úloh.
* **Limity škálovatelnosti databáze:** Aplikace zakazuje kurzory na straně serveru (`DISABLE_SERVER_SIDE_CURSORS: True`) v konfiguraci databáze. To zabraňuje tomu, aby spouštění bezserverových kontejnerů vytvářelo visící paměťové fondy (memory pools) na vašich připojovacích uzlech Neon.

## 7. Nasazení (Infrastruktura jako kód)

Celé nasazení je reprodukovatelné z repozitáře pomocí **Terraformu** (nebo OpenTofu). Konfigurace v `infra/` zřídí vše jediným příkazem apply:

* **Neon** — vytvoří bezserverový projekt Postgres, větev (branch), roli a databázi (`neon_project`).
* **Vercel** — vytvoří projekt propojený s tímto GitHub repozitářem, vloží každou proměnnou prostředí (včetně `DATABASE_URL`, získané přímo ze sdruženého připojovacího řetězce Neon) a povýší produkční nasazení.

Není nutné nic klikat v žádném dashboardu a žádné tajné hodnoty nejsou ve verzovacím systému: údaje se předávají jako proměnné Terraformu přes gitem ignorovaný soubor `terraform.tfvars` (nebo proměnné prostředí `TF_VAR_*`).

### Předpoklady
* Terraform `>= 1.5`.
* **Vercel API token** a případně vaše **team ID**.
* **Neon API klíč** (a doporučené **ID organizace**).
* Aplikace **Vercel for GitHub** nainstalovaná na cílovém repozitáři (jednorázově, na úrovni účtu — to je to, co umožňuje Vercelu buildovat při push).
* POZNÁMKA: můžete si nastavit vlastní projekty, ale tento kód funguje, když Vercel a Neon ještě nemají žádné inicializované projekty.

### Kroky
```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # poté vyplňte své hodnoty
terraform init
terraform plan
terraform apply
```
Při úspěchu Terraform vypíše živou adresu `production_url`. Opětovné spuštění `terraform apply` po pushnutí kódu znovu nasadí; `terraform destroy` zruší databázi i projekt.

### Soubory
| Soubor | Účel |
| :--- | :--- |
| `infra/versions.tf` | Požadované verze Terraformu a poskytovatelů (`vercel/vercel`, `kislerdm/neon`) |
| `infra/providers.tf` | Autentizace poskytovatelů (tokeny předávané jako proměnné) |
| `infra/variables.tf` | Všechny vstupy; tajné údaje označené jako `sensitive` |
| `infra/main.tf` | Projekt Neon, projekt Vercel, proměnné prostředí, produkční nasazení |
| `infra/outputs.tf` | Živá adresa URL, ID projektu, údaje o připojení k databázi |
| `infra/terraform.tfvars.example` | Šablona pro váš (gitem ignorovaný) `terraform.tfvars` |
| `infra/.gitignore` | Drží stavové soubory a skutečné tajné údaje mimo verzovací systém |
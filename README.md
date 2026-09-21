# Workforce AI - Baseline Policy (Terraform)

Policy baseline per il tenant Check Point **Workforce AI**, gestita tramite il
provider [`CheckPointSW/checkpoint-workforce-ai`](https://registry.terraform.io/providers/CheckPointSW/checkpoint-workforce-ai/latest/docs).

Obiettivo: **Claude** e **Google Gemini** sono i tool GenAI approvati; qualunque
altro tool della categoria "Generative AI" richiede conferma esplicita
dell'utente (nessun blocco secco, per un rollout graduale). In aggiunta,
copre alcuni scenari pericolosi comuni (leakage dati/PII, leakage di
secrets/codice sorgente, abuso di agenti/MCP) tramite regole DLP e Agents.

## File

| File | Contenuto |
|------|-----------|
| `provider.tf` | Configurazione del provider `cpwai` |
| `variables.tf` | Variabili di input (credenziali, ID app, ID data type) |
| `terraform.tfvars.example` | Template da copiare in `terraform.tfvars` |
| `access-policy.tf` | Allow Claude/Gemini + "ask" su tutto il resto |
| `dlp-policy.tf` | Regole DLP sugli scenari pericolosi (carte di credito, secrets) |
| `agents-policy.tf` | Regole su agenti/MCP (server whitelist, blocco DELETE non supervisionate) |

## Prerequisiti

- Terraform >= 1.0
- Un account Infinity Portal con licenza **Workforce AI**
- Una API key con servizio **Workforce AI Security** (Settings -> API Keys -> New -> New Account API Key)

## Passi da fare PRIMA del primo `apply`

Alcuni valori non sono pubblicati staticamente dal provider e vanno recuperati
dal tuo tenant. Non sono stati inventati: sono lasciati come variabili da
valorizzare.

### 1. ID applicazione di Claude e Gemini

Il campo `genai_application.id` fa riferimento al catalogo AI del tuo tenant.
Recuperalo con l'[Apps Catalog API](https://app.swaggerhub.com/apis/Check-Point/checkpoint-ai-security/1.0.0#/Apps%20Catalog):

```
POST /apps/search
{ "query": "Claude" }

POST /apps/search
{ "query": "Gemini" }
```

Riporta gli ID trovati in `claude_app_id` e `gemini_app_id` (in `terraform.tfvars`).

### 2. Data type DLP "Secrets / API Keys / Source Code"

Il data type "Credit Card Number" e' predefinito e il suo UUID
(`cf0523c1-537e-4a4b-8bb8-084b7b9e0b45`) e' gia' impostato di default.

Per secrets/codice sorgente non esiste un data type predefinito: va creato
come tipo `CUSTOM` a livello di tenant tramite la
[DLP Datatypes API](https://app.swaggerhub.com/apis/Check-Point/checkpoint-ai-security/1.0.0#/DLP%20Datatypes),
poi il suo UUID va inserito in `secrets_data_type_id`.

### 3. Dominio MCP interno

Imposta `internal_mcp_domain` con il dominio (o suffisso) usato dai tuoi
server MCP aziendali autorizzati.

## Uso

```bash
cp terraform.tfvars.example terraform.tfvars
# valorizza terraform.tfvars con i tuoi dati (vedi sopra)

export TF_VAR_checkpoint_client_id="..."
export TF_VAR_checkpoint_access_key="..."
# oppure lasciali in terraform.tfvars - NON committarlo

terraform init
terraform plan
terraform apply
```

Dopo il primo `apply`, verifica nel portale Infinity che l'ordine di
valutazione delle regole (`order`, first-match) produca il comportamento
atteso: le regole di allow/block piu' specifiche (Claude, Gemini, blocco
DELETE) devono precedere i catch-all generici.

## Scenari pericolosi coperti

| Regola | Scenario | Mitigazione |
|--------|----------|-------------|
| `block_credit_card_prompt` / `_upload` | Un dipendente incolla o carica dati di pagamento di un cliente in un'AI tool | Blocco (`prevent`) su qualunque servizio |
| `redact_secrets_prompt` | Uno sviluppatore incolla in un prompt codice con una chiave API/credenziale hardcoded | Redazione automatica (`redact`) |
| `block_generic_paste_example` (disattivata) | Un utente incolla un intero documento riservato senza pattern DLP riconosciuto | Blocco totale del paste - aggressivo, da valutare prima di attivare |
| `block_destructive_operations` | Un agente AI invoca un tool MCP con operazione `DELETE` senza supervisione | Blocco delle operazioni `DELETE` su tutti i server MCP |
| `block_unlisted_mcp_servers` | Un dipendente collega un MCP server di terze parti non verificato (tool poisoning / supply chain) | Blocco di ogni server MCP non whitelistato |
| `ask_other_genai` | Uso di shadow AI (tool GenAI non Claude/Gemini) | Richiesta di conferma esplicita all'utente |

## Estendere la policy

- Per bloccare/permettere altre AI tool: aggiungi altre `cpwai_workforce_ai_access_rule`
  con `order` inferiore al catch-all (`ask_other_genai`, attualmente `order = 2`).
- Per altri data type DLP (SSN, IBAN, ecc.): cercali con la DLP Datatypes API e
  aggiungi nuove regole in `dlp-policy.tf` seguendo lo stesso schema.
- Per la sicurezza del browser (non solo Workforce AI chat/agent), vedi le
  risorse `cpwai_browse_*` del provider (non incluse in questa baseline).

# Katasticho MCP Server

Run the books from **Claude Desktop** (or any [MCP](https://modelcontextprotocol.io) client / agent).
This server wraps the Katasticho REST API as a small, safe set of tools.

> **Safety model:** the server authenticates with an **org-scoped API key**, so
> every call is tenant-scoped exactly like a logged-in user. It can *draft*
> transactions, but **posting only happens when you explicitly approve** a draft
> (`approve_bill_draft`). Nothing is posted silently. This is the same
> "AI drafts → human approves" rule the app enforces.

## Tools

| Tool | What it does |
|------|--------------|
| `ask` | Natural-language question about the books → answer + rows (P&L, cash, sales, outstanding, GST, low stock…). |
| `list_bills` | List purchase (vendor) bills, filter by status/search. |
| `list_invoices` | List customer (sales) invoices, filter by status/search. |
| `list_ai_inbox` | List AI Inbox suggestions awaiting review (incl. drafted bills). |
| `draft_bill` | Draft a purchase bill from structured data → creates a **DRAFT** + inbox suggestion (does **not** post). |
| `approve_bill_draft` | Approve a drafted bill → **posts** it (journal + stock) via the normal path. |
| `reject_bill_draft` | Delete a drafted bill without posting. |
| `gst_compliance_calendar` | What's due: GSTR-1/3B, TDS deposit, 2B reconciliation, pending e-way bills. |
| `get_gstr3b` | Pre-built GSTR-3B for a month — output tax, ITC, net payable. |
| `gstr2b_recon_summary` | 2B reconciliation result — matches, mismatches, missing ITC, ITC at risk. |

## Setup

### 1. Create an API key

In the Katasticho app: **Settings → API Keys → Create** (Owner/Admin), then copy
the key — it's shown **once**. It looks like `kat_xxxxxxxxxxxx…`.

Or via the API:

```bash
curl -X POST http://localhost:8080/api/v1/api-keys \
  -H "Authorization: Bearer <your-user-jwt>" \
  -H "Content-Type: application/json" \
  -d '{"name":"Claude Desktop"}'
# → { "data": { "key": "kat_…", "keyPrefix": "kat_…", ... } }
```

### 2. Build the server

```bash
cd mcp
npm install
npm run build
```

### 3. Point Claude Desktop at it

Edit your Claude Desktop config:

- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

```jsonc
{
  "mcpServers": {
    "katasticho": {
      "command": "node",
      "args": ["/absolute/path/to/katasticho/mcp/build/index.js"],
      "env": {
        "KATASTICHO_BASE_URL": "http://localhost:8080",
        "KATASTICHO_API_KEY": "kat_your_key_here"
      }
    }
  }
}
```

Restart Claude Desktop. You should see the **katasticho** tools available.

### Local dev (no build step)

```bash
cd mcp
KATASTICHO_API_KEY=kat_… KATASTICHO_BASE_URL=http://localhost:8080 npm run dev
```

## Try it

In Claude Desktop:

- *"What's my profit this month?"* → `ask`
- *"Show my unpaid vendor bills."* → `list_bills` (status OPEN)
- *"Draft a bill: ABC Pharma, GSTIN 27AABCT1234A1Z5, 50 Crocin 500mg at ₹95, 12% GST."*
  → `draft_bill` → returns a `suggestionId`
- *"Looks right — approve it."* → `approve_bill_draft`

## Configuration

| Env var | Default | Notes |
|---------|---------|-------|
| `KATASTICHO_BASE_URL` | `http://localhost:8080` | Base URL of the Katasticho backend. |
| `KATASTICHO_API_KEY` | _(required)_ | Org API key (`kat_…`). Sent as `X-API-Key`. |

## Notes

- Transport is **stdio** (the standard for Claude Desktop). The server never
  writes to stdout except MCP protocol frames; logs go to stderr.
- The API key carries your org + role. Revoke it any time in **Settings → API Keys**.
- This server is intentionally small. New tools map 1:1 to REST endpoints — add
  them in `src/index.ts` as the API grows (e.g. GST returns, bank reconciliation).

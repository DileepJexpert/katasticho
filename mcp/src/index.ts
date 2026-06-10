#!/usr/bin/env node
/**
 * Katasticho MCP server — run the books from Claude Desktop / any MCP client.
 *
 * Exposes a small, safe toolset over the Katasticho REST API:
 *   • read   — ask (natural language), list_bills, list_invoices, list_ai_inbox
 *   • draft  — draft_bill  (creates a DRAFT bill + AI Inbox suggestion)
 *   • act    — approve_bill_draft / reject_bill_draft (human-in-the-loop)
 *
 * Safety: the server authenticates with an org-scoped API key, so every call
 * is tenant-scoped exactly like a logged-in user. It can DRAFT transactions but
 * posting only happens when `approve_bill_draft` is called — i.e. a human (or
 * an explicit approval step) decides. Nothing is posted silently.
 *
 * Transport is stdio, so never write to stdout — logs go to stderr.
 */
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { KatastichoClient, unwrap } from "./client.js";

const baseUrl = process.env.KATASTICHO_BASE_URL ?? "http://localhost:8080";
const apiKey = process.env.KATASTICHO_API_KEY;

if (!apiKey) {
  console.error(
    "[katasticho-mcp] KATASTICHO_API_KEY is not set. Create an API key in " +
      "Settings → API Keys and set it in the MCP server config.",
  );
  process.exit(1);
}

const client = new KatastichoClient({ baseUrl, apiKey });

const server = new McpServer({ name: "katasticho", version: "0.1.0" });

function ok(data: unknown) {
  return { content: [{ type: "text" as const, text: stringify(data) }] };
}

function fail(message: string) {
  return { content: [{ type: "text" as const, text: message }], isError: true };
}

function stringify(data: unknown): string {
  if (typeof data === "string") return data;
  try {
    return JSON.stringify(data, null, 2);
  } catch {
    return String(data);
  }
}

// ── Read ────────────────────────────────────────────────────────────────────

server.tool(
  "ask",
  "Ask a natural-language question about the books and get an answer plus the " +
    "underlying rows. Use for P&L, cash position, sales, top customers, " +
    "outstanding receivables/payables, GST summaries, low stock, etc. " +
    "Example: \"What is my profit this month?\" or \"Who owes me the most?\"",
  { question: z.string().min(3).describe("A plain-English question about the business finances.") },
  async ({ question }) => {
    try {
      const body = await client.post("/api/v1/ai/query", { message: question });
      const data = unwrap(body) as {
        answer?: string;
        results?: unknown[];
        generatedSql?: string;
      };
      return ok({
        answer: data?.answer ?? "(no answer)",
        rows: data?.results ?? [],
        sql: data?.generatedSql,
      });
    } catch (e) {
      return fail(`ask failed: ${(e as Error).message}`);
    }
  },
);

server.tool(
  "list_bills",
  "List purchase (vendor) bills, newest first. Optionally filter by status " +
    "(DRAFT, OPEN, PAID, PARTIALLY_PAID, OVERDUE, VOID) or a search term.",
  {
    status: z.string().optional().describe("Bill status filter, e.g. DRAFT or OPEN."),
    search: z.string().optional().describe("Search vendor name / bill number."),
    limit: z.number().int().min(1).max(100).optional().describe("Max rows (default 20)."),
  },
  async ({ status, search, limit }) => {
    try {
      const body = await client.get("/api/v1/bills", {
        page: 0,
        size: limit ?? 20,
        status,
        search,
      });
      return ok(unwrap(body));
    } catch (e) {
      return fail(`list_bills failed: ${(e as Error).message}`);
    }
  },
);

server.tool(
  "list_invoices",
  "List customer (sales) invoices, newest first. Optionally filter by status or search term.",
  {
    status: z.string().optional().describe("Invoice status filter."),
    search: z.string().optional().describe("Search customer name / invoice number."),
    limit: z.number().int().min(1).max(100).optional().describe("Max rows (default 20)."),
  },
  async ({ status, search, limit }) => {
    try {
      const body = await client.get("/api/v1/invoices", {
        page: 0,
        size: limit ?? 20,
        status,
        search,
      });
      return ok(unwrap(body));
    } catch (e) {
      return fail(`list_invoices failed: ${(e as Error).message}`);
    }
  },
);

server.tool(
  "list_ai_inbox",
  "List AI Inbox suggestions awaiting human review — including DRAFT_BILL " +
    "drafts created by draft_bill. Use this to find a suggestionId to approve or reject.",
  {
    status: z
      .string()
      .optional()
      .describe("Suggestion status (PENDING, ACCEPTED, REJECTED, DEFERRED). Default PENDING."),
  },
  async ({ status }) => {
    try {
      const body = await client.get("/api/v1/ai/suggestions", {
        page: 0,
        size: 30,
        status: status ?? "PENDING",
      });
      return ok(unwrap(body));
    } catch (e) {
      return fail(`list_ai_inbox failed: ${(e as Error).message}`);
    }
  },
);

// ── Draft (safe writes — creates a DRAFT, never posts) ───────────────────────

const billLineShape = z.object({
  description: z.string().describe("Item / line description as it appears on the bill."),
  hsnCode: z.string().optional().describe("HSN/SAC code; used to infer GST when rate is omitted."),
  quantity: z.number().describe("Quantity."),
  unitPrice: z.number().describe("Unit price (rate) before tax."),
  gstRate: z.number().optional().describe("GST percent (e.g. 5, 12, 18). Inferred from HSN if omitted."),
  discountPercent: z.number().optional().describe("Line discount percent."),
});

server.tool(
  "draft_bill",
  "Draft a purchase (vendor) bill from structured data. Creates a DRAFT bill " +
    "and an AI Inbox suggestion — it does NOT post. The vendor is matched by " +
    "GSTIN/name (or created), each line is matched to an item or booked as " +
    "expense, and GST is taken from the line or inferred from the HSN. " +
    "Returns a suggestionId; call approve_bill_draft to post it.",
  {
    vendorName: z.string().describe("Supplier / vendor name."),
    vendorGstin: z.string().optional().describe("Vendor GSTIN (15 chars) if known."),
    vendorStateCode: z
      .string()
      .optional()
      .describe("GST state code / place of supply (e.g. 27). Inferred from GSTIN if omitted."),
    invoiceNumber: z.string().optional().describe("Vendor's invoice number."),
    billDate: z.string().optional().describe("Bill date as YYYY-MM-DD (defaults to today)."),
    dueDate: z.string().optional().describe("Payment due date as YYYY-MM-DD."),
    notes: z.string().optional(),
    lines: z.array(billLineShape).min(1).describe("Bill line items."),
  },
  async (args) => {
    try {
      const body = await client.post("/api/v1/ai/bill-drafts", args);
      const data = unwrap(body);
      return ok({
        drafted: true,
        ...(data as object),
        next: "Review, then call approve_bill_draft with the suggestionId to post.",
      });
    } catch (e) {
      return fail(`draft_bill failed: ${(e as Error).message}`);
    }
  },
);

server.tool(
  "approve_bill_draft",
  "Approve a drafted bill (from draft_bill) — this POSTS it: journal entry and " +
    "stock movements are created through the normal accounting path. Irreversible " +
    "without a void, so confirm the draft looks right first (list_ai_inbox).",
  { suggestionId: z.string().uuid().describe("The DRAFT_BILL suggestion id from draft_bill / list_ai_inbox.") },
  async ({ suggestionId }) => {
    try {
      const body = await client.post(`/api/v1/ai/bill-drafts/${suggestionId}/approve`);
      return ok({ posted: true, ...(unwrap(body) as object) });
    } catch (e) {
      return fail(`approve_bill_draft failed: ${(e as Error).message}`);
    }
  },
);

server.tool(
  "reject_bill_draft",
  "Reject a drafted bill — deletes the DRAFT without posting.",
  {
    suggestionId: z.string().uuid().describe("The DRAFT_BILL suggestion id."),
    reason: z.string().optional().describe("Optional reason for rejection."),
  },
  async ({ suggestionId, reason }) => {
    try {
      await client.post(
        `/api/v1/ai/bill-drafts/${suggestionId}/reject`,
        reason ? { reason } : undefined,
      );
      return ok({ rejected: true, suggestionId });
    } catch (e) {
      return fail(`reject_bill_draft failed: ${(e as Error).message}`);
    }
  },
);

// ── GST compliance (India) ───────────────────────────────────────────────────

server.tool(
  "gst_compliance_calendar",
  "What GST/TDS filings are due, when, and their status (UPCOMING / DUE_SOON / " +
    "OVERDUE) — GSTR-1, GSTR-3B, TDS deposit, GSTR-2B reconciliation, and any " +
    "pending e-way bills. Use this to answer \"what's due?\" questions.",
  {},
  async () => {
    try {
      const body = await client.get("/api/v1/gst/compliance-calendar");
      return ok(unwrap(body));
    } catch (e) {
      return fail(`gst_compliance_calendar failed: ${(e as Error).message}`);
    }
  },
);

server.tool(
  "get_gstr3b",
  "Pre-built GSTR-3B for a month: outward taxable supplies, output tax " +
    "(IGST/CGST/SGST), input tax credit from purchase bills, and net tax payable.",
  {
    year: z.number().int().min(2017).describe("Return year, e.g. 2026."),
    month: z.number().int().min(1).max(12).describe("Return month 1-12."),
  },
  async ({ year, month }) => {
    try {
      const body = await client.get("/api/v1/gst/gstr3b", { year, month });
      return ok(unwrap(body));
    } catch (e) {
      return fail(`get_gstr3b failed: ${(e as Error).message}`);
    }
  },
);

server.tool(
  "gstr2b_recon_summary",
  "GSTR-2B reconciliation result for a period (YYYY-MM): matched bills, value " +
    "mismatches, supplier invoices missing from books (unclaimed ITC), and " +
    "suppliers who did not file (ITC at risk).",
  {
    period: z
      .string()
      .regex(/^\d{4}-\d{2}$/)
      .describe("Return period as YYYY-MM, e.g. 2026-05."),
  },
  async ({ period }) => {
    try {
      const body = await client.get("/api/v1/gst/gstr2b/summary", { period });
      return ok(unwrap(body));
    } catch (e) {
      return fail(`gstr2b_recon_summary failed: ${(e as Error).message}`);
    }
  },
);

// ── Boot ─────────────────────────────────────────────────────────────────────

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error(`[katasticho-mcp] connected — API ${baseUrl}`);
}

main().catch((e) => {
  console.error("[katasticho-mcp] fatal:", e);
  process.exit(1);
});

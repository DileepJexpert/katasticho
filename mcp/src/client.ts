/**
 * Thin REST client for the Katasticho API.
 *
 * Authenticates with an org-scoped API key via the X-API-Key header:
 *   X-API-Key: kat_...
 *
 * The key carries the org + role, so every call is tenant-scoped server-side —
 * exactly like a logged-in user. The MCP server never sees raw credentials
 * beyond this key, and write operations only ever create *drafts* that a human
 * approves in the app.
 */

export interface KatastichoClientOptions {
  baseUrl: string;
  apiKey: string;
}

export type QueryParams = Record<string, string | number | boolean | undefined>;

export class KatastichoClient {
  private readonly baseUrl: string;
  private readonly apiKey: string;

  constructor(opts: KatastichoClientOptions) {
    this.baseUrl = opts.baseUrl.replace(/\/+$/, "");
    this.apiKey = opts.apiKey;
  }

  async get(path: string, query?: QueryParams): Promise<unknown> {
    return this.request("GET", path, undefined, query);
  }

  async post(path: string, body?: unknown): Promise<unknown> {
    return this.request("POST", path, body);
  }

  private async request(
    method: string,
    path: string,
    body?: unknown,
    query?: QueryParams,
  ): Promise<unknown> {
    const url = new URL(this.baseUrl + path);
    if (query) {
      for (const [key, value] of Object.entries(query)) {
        if (value !== undefined && value !== "") {
          url.searchParams.set(key, String(value));
        }
      }
    }

    let res: Response;
    try {
      res = await fetch(url, {
        method,
        headers: {
          "X-API-Key": this.apiKey,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: body !== undefined ? JSON.stringify(body) : undefined,
      });
    } catch (e) {
      throw new Error(
        `Could not reach Katasticho at ${this.baseUrl} — is the server running? (${(e as Error).message})`,
      );
    }

    const text = await res.text();
    let data: unknown = undefined;
    if (text) {
      try {
        data = JSON.parse(text);
      } catch {
        data = text;
      }
    }

    if (!res.ok) {
      const message = extractMessage(data) ?? res.statusText;
      throw new Error(`HTTP ${res.status} on ${method} ${path}: ${message}`);
    }
    return data;
  }
}

/** Katasticho wraps responses as { success, data, message }. Unwrap `data`. */
export function unwrap(body: unknown): unknown {
  if (body && typeof body === "object" && "data" in (body as Record<string, unknown>)) {
    return (body as Record<string, unknown>).data;
  }
  return body;
}

function extractMessage(data: unknown): string | undefined {
  if (data && typeof data === "object") {
    const obj = data as Record<string, unknown>;
    if (typeof obj.message === "string") return obj.message;
    if (typeof obj.error === "string") return obj.error;
  }
  return undefined;
}

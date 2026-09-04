import { apiFetchRawJson } from '@/api/client/api-client'

const NAV_DISABLED_SETTING = 'nav.disabled'

/** Reads the organisation's stable navigation IDs from the existing settings API. */
export async function getDisabledNavigationIds(): Promise<string[]> {
  const settings = await apiFetchRawJson<Record<string, string>>(`/api/v1/settings/${NAV_DISABLED_SETTING}`)
  return parseDisabledNavigationIds(settings[NAV_DISABLED_SETTING])
}

/**
 * The settings screen stores JSON. The comma-separated fallback preserves the
 * existing Flutter behaviour for organisations that entered the older format.
 */
export function parseDisabledNavigationIds(raw: string | null | undefined): string[] {
  const value = raw?.trim()
  if (!value) return []

  try {
    const parsed: unknown = JSON.parse(value)
    if (Array.isArray(parsed)) {
      return uniqueStableIds(parsed)
    }
  } catch {
    // Fall through to the legacy comma-separated representation.
  }

  return uniqueStableIds(value.split(','))
}

function uniqueStableIds(values: unknown[]): string[] {
  return [...new Set(values
    .filter((value): value is string => typeof value === 'string')
    .map((value) => value.trim())
    .filter((value) => /^[a-z0-9]+(?:[._-][a-z0-9]+)*$/i.test(value)))]
}

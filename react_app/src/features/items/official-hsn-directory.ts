export type OfficialHsnEntry = {
  hsnCode: string
  description: string
}

type OfficialHsnDirectory = {
  source: string
  retrievedOn: string
  records: OfficialHsnEntry[]
}

let directoryPromise: Promise<OfficialHsnDirectory> | null = null

function loadDirectory(): Promise<OfficialHsnDirectory> {
  directoryPromise ??= fetch(`${import.meta.env.BASE_URL}data/india-hsn-directory.json`, {
    cache: 'force-cache',
  }).then(async (response) => {
    if (!response.ok) {
      throw new Error(`Unable to load the official HSN directory (${response.status})`)
    }
    return response.json() as Promise<OfficialHsnDirectory>
  })
  return directoryPromise
}

function matchRank(entry: OfficialHsnEntry, query: string): number {
  const code = entry.hsnCode.toLowerCase()
  const description = entry.description.toLowerCase()
  const terms = query.split(/\s+/).filter(Boolean)

  if (code === query) return 0
  if (code.startsWith(query)) return 1
  if (description.startsWith(query)) return 2
  if (terms.every((term) => description.includes(term))) return 3
  if (description.includes(query)) return 4
  return -1
}

export function searchOfficialHsnEntries(
  records: OfficialHsnEntry[],
  rawQuery: string,
  limit = 25,
): OfficialHsnEntry[] {
  const query = rawQuery.trim().toLowerCase()
  if (query.length < 2 || limit < 1) return []

  return records
    .map((entry) => ({ entry, rank: matchRank(entry, query) }))
    .filter((candidate) => candidate.rank >= 0)
    .sort((left, right) => (
      left.rank - right.rank
      || left.entry.hsnCode.length - right.entry.hsnCode.length
      || left.entry.hsnCode.localeCompare(right.entry.hsnCode)
    ))
    .slice(0, limit)
    .map((candidate) => candidate.entry)
}

export async function searchOfficialHsnDirectory(
  query: string,
  limit = 25,
): Promise<OfficialHsnEntry[]> {
  if (query.trim().length < 2) return []
  const directory = await loadDirectory()
  return searchOfficialHsnEntries(directory.records, query, limit)
}

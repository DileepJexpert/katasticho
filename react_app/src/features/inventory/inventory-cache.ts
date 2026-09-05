import type { QueryClient } from '@tanstack/react-query'

/** Invalidate read projections after an actual inventory movement. */
export function invalidateInventoryQueries(client: QueryClient) {
  return Promise.all(['inventory', 'items', 'available-batches', 'batches', 'batch-trace', 'shortbook'].map((key) => client.invalidateQueries({ queryKey: [key] })))
}

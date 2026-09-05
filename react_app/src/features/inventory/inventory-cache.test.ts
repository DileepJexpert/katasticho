import { QueryClient } from '@tanstack/react-query'
import { expect, it } from 'vitest'
import { invalidateInventoryQueries } from './inventory-cache'

it('marks all stock-dependent views stale without touching unrelated directories', async () => {
  const client = new QueryClient()
  const stockKeys = ['inventory', 'items', 'available-batches', 'batches', 'batch-trace', 'shortbook']
  for (const key of [...stockKeys, 'contacts']) client.setQueryData([key, 'test'], [])
  await invalidateInventoryQueries(client)
  for (const key of stockKeys) expect(client.getQueryState([key, 'test'])?.isInvalidated).toBe(true)
  expect(client.getQueryState(['contacts', 'test'])?.isInvalidated).toBe(false)
  client.clear()
})

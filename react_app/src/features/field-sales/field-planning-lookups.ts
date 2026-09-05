import { listRoutes, listVans, type PageResponse } from './field-sales-api'

async function allPages<T>(read: (page: number, size: number) => Promise<PageResponse<T>>) {
  const first = await read(0, 100)
  const rows = [...first.content]
  for (let page = 1; page < first.totalPages; page++) rows.push(...(await read(page, 100)).content)
  return rows
}
export const planningRoutes = () => allPages(listRoutes)
export const planningVans = () => allPages(listVans)

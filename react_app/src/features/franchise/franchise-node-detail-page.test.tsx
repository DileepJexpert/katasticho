import { render, screen } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { expect, it, vi } from 'vitest'
import { FranchiseNodeDetailPage } from './franchise-node-detail-page'
import * as api from './franchise-api'
vi.mock('./franchise-api', async (original) => ({ ...await original<typeof api>(), listFranchiseNodes: vi.fn() }))
it('renders actual node fields without calling the unavailable price override integration', async () => {
  vi.mocked(api.listFranchiseNodes).mockResolvedValue([{ id: 'node-1', nodeCode: 'FR-01', nodeName: 'Gonda Store', nodeType: 'FOFO', city: 'Gonda', royaltyRatePercent: 7, fixedMonthlyFee: 150, active: true }])
  render(<QueryClientProvider client={new QueryClient()}><MemoryRouter initialEntries={['/franchise/node-1']}><Routes><Route path="/franchise/:nodeId" element={<FranchiseNodeDetailPage />} /></Routes></MemoryRouter></QueryClientProvider>)
  expect(await screen.findByRole('heading', { name: 'Gonda Store' })).toBeInTheDocument()
  expect(screen.getByText('7%')).toBeInTheDocument()
  expect(screen.getByRole('note')).toHaveTextContent('unavailable in the current backend')
  expect(screen.queryByRole('button', { name: /Override/ })).not.toBeInTheDocument()
})

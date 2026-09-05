import { cleanup, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { useSessionStore } from '@/shared/session/session-store'
import { enterpriseUser } from '@/features/accounting/enterprise-test-fixtures'
import * as api from './franchise-api'
import { FranchisePage } from './franchise-page'
vi.mock('./franchise-api', async (original) => ({ ...await original<typeof api>(), listFranchiseNodes: vi.fn(), createFranchiseNode: vi.fn(), updateFranchiseNode: vi.fn(), deleteFranchiseNode: vi.fn(), listRoyaltySettlements: vi.fn(), getFranchisePolicy: vi.fn(), saveFranchisePolicy: vi.fn() }))
const node: api.FranchiseNode = { id: 'node-1', nodeCode: 'FR-01', nodeName: 'Main Market Store', nodeType: 'FOFO', branchId: 'branch-1', royaltyRatePercent: 5, fixedMonthlyFee: 200, active: true }
beforeEach(() => { vi.resetAllMocks(); useSessionStore.setState({ user: enterpriseUser, status: 'authenticated' }); vi.mocked(api.listFranchiseNodes).mockResolvedValue([node]); vi.mocked(api.createFranchiseNode).mockResolvedValue(node); vi.mocked(api.updateFranchiseNode).mockResolvedValue(node); vi.mocked(api.listRoyaltySettlements).mockResolvedValue([]) })
afterEach(cleanup)
function view() { render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}><MemoryRouter><FranchisePage /></MemoryRouter></QueryClientProvider>) }
it('searches the real nodeName response without crashing', async () => { const user = userEvent.setup(); view(); await screen.findByText('Main Market Store'); await user.type(screen.getByLabelText('Search stores'), 'Market'); expect(screen.getByText('Main Market Store')).toBeInTheDocument() })
it('creates a node using the backend names and ownership model', async () => {
  const user = userEvent.setup(); view(); await user.click(screen.getByRole('button', { name: 'Add Franchise Store' }))
  await user.type(screen.getByLabelText('Store code'), 'FR-02'); await user.type(screen.getByLabelText('Store name'), 'New Store'); await user.click(screen.getByRole('button', { name: 'Create Store' }))
  await waitFor(() => expect(api.createFranchiseNode).toHaveBeenCalledWith(expect.objectContaining({ nodeCode: 'FR-02', nodeName: 'New Store', nodeType: 'FOFO', royaltyRatePercent: 5, fixedMonthlyFee: 0 })))
})
it('edits and deactivates a store while retaining its branch link', async () => {
  const user = userEvent.setup(); view(); await user.click(await screen.findByRole('button', { name: 'Edit FR-01' })); await user.click(screen.getByLabelText('Active')); await user.click(screen.getByRole('button', { name: 'Save store' }))
  await waitFor(() => expect(api.updateFranchiseNode).toHaveBeenCalledWith('node-1', expect.objectContaining({ branchId: 'branch-1', active: false })))
})
it('keeps unsupported royalties read-only and hides admin edits from viewers', async () => {
  useSessionStore.setState({ user: { ...enterpriseUser, role: 'VIEWER' } }); const user = userEvent.setup(); view()
  expect(screen.queryByRole('button', { name: 'Add Franchise Store' })).not.toBeInTheDocument()
  await user.click(screen.getByRole('tab', { name: 'Royalty Settlements' })); expect(screen.getByText(/Creation and invoice generation await/)).toBeInTheDocument(); expect(screen.queryByRole('button', { name: /Calculate|Post|Push/i })).not.toBeInTheDocument()
})

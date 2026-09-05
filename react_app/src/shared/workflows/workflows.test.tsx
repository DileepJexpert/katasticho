import { useState } from 'react'
import { act, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { beforeEach, expect, it, vi } from 'vitest'
import { enterpriseUser } from '@/features/accounting/enterprise-test-fixtures'
import { useSessionStore } from '@/shared/session/session-store'
import { LocalDirectory } from './local-directory'
import { WorkspaceBoundary } from './workspace-boundary'
import { ConfirmedAction } from './confirmed-action'
import { QueryFeedback } from './query-feedback'

beforeEach(() => useSessionStore.setState({ status: 'authenticated', user: enterpriseUser }))

it('bounds large unpaged results and resets paging after search or data shrink', async () => {
  const rows = Array.from({ length: 60 }, (_, index) => ({ id: String(index), name: `Record ${index}` }))
  const props = { caption: 'Results', searchText: (row: typeof rows[number]) => row.name, header: <tr><th>Name</th></tr>, renderRow: (row: typeof rows[number]) => <tr key={row.id}><td>{row.name}</td></tr> }
  const { rerender } = render(<LocalDirectory {...props} rows={rows} />)
  expect(screen.getAllByRole('row')).toHaveLength(26)
  await userEvent.click(screen.getByRole('button', { name: 'Next page' }))
  expect(screen.getByText('Record 25')).toBeInTheDocument()
  expect(screen.queryByText('Record 0')).not.toBeInTheDocument()
  await userEvent.type(screen.getByRole('searchbox', { name: 'Search Results' }), 'Record 59')
  expect(screen.getByText('Page 1 of 1')).toBeInTheDocument()
  expect(screen.getByText('Record 59')).toBeInTheDocument()
  await userEvent.clear(screen.getByRole('searchbox', { name: 'Search Results' }))
  await userEvent.click(screen.getByRole('button', { name: 'Next page' }))
  rerender(<LocalDirectory {...props} rows={rows.slice(0, 1)} />)
  expect(screen.getByText('Record 0')).toBeInTheDocument()
  expect(screen.getByText('Page 1 of 1')).toBeInTheDocument()
})

it('does not mount restricted content even for a platform role not authorised by the controller', () => {
  const mounted = vi.fn()
  function Content() { mounted(); return <p>Restricted records</p> }
  useSessionStore.setState({ user: { ...enterpriseUser, role: 'PLATFORM_ADMIN' } })
  render(<WorkspaceBoundary roles={['OWNER', 'ADMIN']}><Content /></WorkspaceBoundary>)
  expect(mounted).not.toHaveBeenCalled()
  expect(screen.getByText(/cannot access this workspace/)).toBeInTheDocument()
})

it('discards form state when the organisation or acting user changes', async () => {
  function Draft() { const [value, setValue] = useState(''); return <input aria-label="Draft" value={value} onChange={(e) => setValue(e.target.value)} /> }
  render(<WorkspaceBoundary roles={['ADMIN']}><Draft /></WorkspaceBoundary>)
  await userEvent.type(screen.getByLabelText('Draft'), 'Private draft')
  act(() => useSessionStore.setState({ user: { ...enterpriseUser, orgId: 'org-2' } }))
  expect(screen.getByLabelText('Draft')).toHaveValue('')
  await userEvent.type(screen.getByLabelText('Draft'), 'Another draft')
  act(() => useSessionStore.setState({ user: { ...enterpriseUser, orgId: 'org-2', id: 'another-user' } }))
  expect(screen.getByLabelText('Draft')).toHaveValue('')
})

it('requires confirmation, blocks duplicate submissions and keeps failures visible', async () => {
  let reject!: (error: Error) => void
  const run = vi.fn(() => new Promise<void>((_resolve, rejectPromise) => { reject = rejectPromise }))
  const onClose = vi.fn(), onDone = vi.fn()
  const client = new QueryClient({ defaultOptions: { mutations: { retry: false } } })
  render(<QueryClientProvider client={client}><ConfirmedAction title="Confirm tracking" description="No stock movement" run={run} onClose={onClose} onDone={onDone} /></QueryClientProvider>)
  expect(run).not.toHaveBeenCalled()
  await userEvent.click(screen.getByRole('button', { name: 'Confirm' }))
  expect(screen.getByRole('button', { name: 'Working...' })).toBeDisabled()
  expect(screen.getByRole('button', { name: 'Cancel' })).toBeDisabled()
  await userEvent.keyboard('{Escape}')
  expect(onClose).not.toHaveBeenCalled()
  await act(async () => reject(new Error('Server rejected action')))
  expect(await screen.findByText('Server rejected action')).toBeInTheDocument()
  expect(onDone).not.toHaveBeenCalled()
  expect(run).toHaveBeenCalledTimes(1)
})

it('offers retry on query failure instead of showing an empty successful directory', async () => {
  const refetch = vi.fn()
  render(<QueryFeedback query={{ isPending: false, isError: true, error: new Error('Forbidden'), refetch }}><p>No records</p></QueryFeedback>)
  expect(screen.queryByText('No records')).not.toBeInTheDocument()
  await userEvent.click(screen.getByRole('button', { name: 'Retry' }))
  await waitFor(() => expect(refetch).toHaveBeenCalledOnce())
})

import { cleanup, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { afterEach, expect, it, vi } from 'vitest'
import { MonthlyPostingDialog } from './monthly-posting-dialog'
afterEach(cleanup)
function view(run = vi.fn().mockResolvedValue({ count: 2, total: 1000, journalEntryId: 'journal-1' })) {
  render(<QueryClientProvider client={new QueryClient()}><MonthlyPostingDialog title="Monthly posting" scope="fixed assets" run={run} onClose={vi.fn()} /></QueryClientProvider>); return run
}
it('requires explicit organisation-wide confirmation and displays the actual run result', async () => {
  const user = userEvent.setup(); const run = view()
  expect(screen.getByText(/not just the record being viewed/)).toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Post organisation month' })).toBeDisabled()
  await user.click(screen.getByRole('checkbox')); await user.click(screen.getByRole('button', { name: 'Post organisation month' }))
  expect(await screen.findByText('2 records processed.')).toBeInTheDocument(); expect(run).toHaveBeenCalledTimes(1)
})
it('retains the dialog and server error when posting fails', async () => {
  const user = userEvent.setup(); const run = view(vi.fn().mockRejectedValue(new Error('Period is locked')))
  await user.click(screen.getByRole('checkbox')); await user.click(screen.getByRole('button', { name: 'Post organisation month' }))
  expect(await screen.findByRole('alert')).toHaveTextContent('Period is locked'); await waitFor(() => expect(run).toHaveBeenCalledTimes(1))
})
it('does not report a journal when the month was already posted', async () => {
  const user = userEvent.setup(); view(vi.fn().mockResolvedValue({ count: 0, total: 0, journalEntryId: null }))
  await user.click(screen.getByRole('checkbox')); await user.click(screen.getByRole('button', { name: 'Post organisation month' }))
  expect(await screen.findByText('No new journal was needed.')).toBeInTheDocument()
})

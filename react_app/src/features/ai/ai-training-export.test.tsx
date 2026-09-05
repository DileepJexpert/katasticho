import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { beforeEach, expect, it, vi } from 'vitest'
import { useSessionStore } from '@/shared/session/session-store'
import { enterpriseUser } from '@/features/accounting/enterprise-test-fixtures'
import { AiCommandCenterPage } from './ai-command-center-page'
import * as api from './ai-api'

vi.mock('./ai-api', async (original) => ({ ...await original<typeof api>(), getTrainingSummary: vi.fn(), getSuggestionSummary: vi.fn(), listSuggestions: vi.fn(), exportTrainingJsonl: vi.fn() }))
beforeEach(() => {
  vi.resetAllMocks()
  useSessionStore.setState({ user: enterpriseUser, status: 'authenticated' })
  vi.mocked(api.getTrainingSummary).mockResolvedValue({ totalExamples: 25 })
  vi.mocked(api.listSuggestions).mockResolvedValue({ content: [], totalElements: 0 })
  vi.mocked(api.getSuggestionSummary).mockResolvedValue({ pendingCount: 0, highPriorityCount: 0, categorizationCount: 0, riskAnomalyCount: 0, actionableDraftsCount: 0 })
})
function view() { render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}><AiCommandCenterPage /></QueryClientProvider>) }
it('shows failed downloads instead of an unhandled promise or fake success', async () => {
  vi.mocked(api.exportTrainingJsonl).mockRejectedValue(new Error('Export unavailable'))
  const user = userEvent.setup(); view()
  await user.click(screen.getByRole('button', { name: 'Model Training & Fine-Tuning' }))
  await user.click(screen.getByRole('button', { name: /Export LoRA/ }))
  expect(await screen.findByRole('alert')).toHaveTextContent('Export unavailable')
  expect(screen.queryByText('High Quality Corrections')).not.toBeInTheDocument()
})
it('does not request protected training data for non-admin roles', async () => {
  useSessionStore.setState({ user: { ...enterpriseUser, role: 'OPERATOR' } })
  const user = userEvent.setup(); view()
  await user.click(screen.getByRole('button', { name: 'Model Training & Fine-Tuning' }))
  expect(screen.getByRole('alert')).toHaveTextContent('Owner or Admin')
  expect(api.getTrainingSummary).not.toHaveBeenCalled()
  expect(screen.queryByRole('button', { name: /Export LoRA/ })).not.toBeInTheDocument()
})

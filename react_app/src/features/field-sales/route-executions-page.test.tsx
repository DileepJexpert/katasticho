import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { RouteExecutionsPage } from './route-executions-page'
import * as fieldSalesApi from '@/features/field-sales/field-sales-api'
import * as payrollApi from '@/features/payroll/payroll-api'

vi.mock('@/features/field-sales/field-sales-api', () => ({
  listExecutions: vi.fn(),
  listRoutes: vi.fn(),
  listVans: vi.fn(),
  startExecution: vi.fn(),
}))

vi.mock('@/features/payroll/payroll-api', () => ({
  listEmployees: vi.fn(),
}))

const mockExecutions = {
  content: [
    {
      id: 'exec-1',
      routeId: 'route-1',
      routeName: 'North Ring Route',
      salespersonId: 'emp-101',
      salespersonName: 'Vikram Patel',
      vanCode: 'VAN-01',
      executionDate: '2026-09-05',
      completedVisits: 8,
      totalVisits: 12,
      totalOrderValue: 45000,
      totalCollections: 32000,
      status: 'IN_PROGRESS',
    },
  ],
  totalElements: 1,
}

const mockRoutes = {
  content: [
    {
      id: 'route-1',
      code: 'NR-01',
      name: 'North Ring Route',
      dayOfWeek: 'MONDAY',
    },
  ],
}

const mockVans = {
  content: [
    {
      id: 'van-1',
      code: 'VAN-01',
      vehicleNumber: 'KA-05-AB-9876',
      name: 'South Express Van',
    },
  ],
}

const mockEmployees = {
  content: [
    {
      id: 'emp-101',
      fullName: 'Vikram Patel',
      employeeCode: 'EMP-0101',
      designation: 'Field Representative',
      department: 'Sales',
    },
  ],
}

function renderWithClient(ui: React.ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
    },
  })
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>{ui}</MemoryRouter>
    </QueryClientProvider>,
  )
}

describe('RouteExecutionsPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(fieldSalesApi.listExecutions).mockResolvedValue(mockExecutions as unknown as Awaited<ReturnType<typeof fieldSalesApi.listExecutions>>)
    vi.mocked(fieldSalesApi.listRoutes).mockResolvedValue(mockRoutes as unknown as Awaited<ReturnType<typeof fieldSalesApi.listRoutes>>)
    vi.mocked(fieldSalesApi.listVans).mockResolvedValue(mockVans as unknown as Awaited<ReturnType<typeof fieldSalesApi.listVans>>)
    vi.mocked(payrollApi.listEmployees).mockResolvedValue(mockEmployees as unknown as Awaited<ReturnType<typeof payrollApi.listEmployees>>)
  })

  it('renders executions directory with metrics and executions log table', async () => {
    renderWithClient(<RouteExecutionsPage />)

    expect(screen.getByRole('heading', { name: 'Route Executions' })).toBeInTheDocument()
    expect(await screen.findByText('North Ring Route')).toBeInTheDocument()
    expect(screen.getByText('Vikram Patel')).toBeInTheDocument()
    expect(screen.getByText('VAN-01')).toBeInTheDocument()
    expect(screen.getByText('8 / 12')).toBeInTheDocument()
  })

  it('opens start run modal, selects route and salesperson via EntityPicker, and dispatches', async () => {
    vi.mocked(fieldSalesApi.startExecution).mockResolvedValue({ id: 'exec-2' } as unknown as Awaited<ReturnType<typeof fieldSalesApi.startExecution>>)

    renderWithClient(<RouteExecutionsPage />)

    const startBtn = await screen.findByRole('button', { name: /Start Route Run/i })
    fireEvent.click(startBtn)

    expect(await screen.findByRole('heading', { name: 'Start Route Execution' })).toBeInTheDocument()

    // Pick Route
    const routePicker = screen.getByPlaceholderText('Search scheduled route by name...')
    fireEvent.focus(routePicker)
    const routeOption = await screen.findByRole('option', { name: /North Ring Route/i })
    fireEvent.click(routeOption)

    // Pick Salesperson (EntityPicker<Employee>)
    const spPicker = screen.getByPlaceholderText('Search salesperson by name or code...')
    fireEvent.focus(spPicker)
    const spOption = await screen.findByRole('option', { name: /Vikram Patel/i })
    fireEvent.click(spOption)

    const submitBtn = screen.getByRole('button', { name: 'Start Execution Run' })
    expect(submitBtn).not.toBeDisabled()
    fireEvent.click(submitBtn)

    await waitFor(() => {
      expect(fieldSalesApi.startExecution).toHaveBeenCalledWith(
        expect.objectContaining({
          routeId: 'route-1',
          salespersonId: 'emp-101',
        }),
      )
    })
  })
})

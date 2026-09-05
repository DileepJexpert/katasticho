import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { EmployeesPage } from './employees-page'
import * as payrollApi from '@/features/payroll/payroll-api'

vi.mock('@/features/payroll/payroll-api', () => ({
  listEmployees: vi.fn(),
  createEmployee: vi.fn(),
}))

const mockEmployeesPage = {
  content: [
    {
      id: 'emp-1',
      orgId: 'org-1',
      employeeCode: 'EMP-001',
      fullName: 'Aarav Sharma',
      designation: 'Senior Formulation Chemist',
      department: 'R&D',
      email: 'aarav.sharma@example.com',
      phone: '+91 98765 43210',
      dateOfJoining: '2024-01-15',
      status: 'ACTIVE',
      employmentType: 'FULL_TIME',
      pan: 'ABCDE1234F',
      uan: '100123456789',
    },
    {
      id: 'emp-2',
      orgId: 'org-1',
      employeeCode: 'EMP-002',
      fullName: 'Pooja Reddy',
      designation: 'QC Analyst',
      department: 'Quality Control',
      email: 'pooja.reddy@example.com',
      phone: '+91 98765 43211',
      dateOfJoining: '2024-03-01',
      status: 'ON_NOTICE',
      employmentType: 'FULL_TIME',
      pan: 'FGHIJ5678K',
      uan: '100987654321',
    },
  ],
  totalElements: 2,
  totalPages: 1,
  size: 50,
  page: 0,
  last: true,
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

describe('EmployeesPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(payrollApi.listEmployees).mockResolvedValue(mockEmployeesPage as unknown as Awaited<ReturnType<typeof payrollApi.listEmployees>>)
  })

  it('renders employee directory with summary cards, table columns, and employee data', async () => {
    renderWithClient(<EmployeesPage />)

    expect(screen.getByRole('heading', { name: 'Employee Directory' })).toBeInTheDocument()
    expect(screen.getByText('Total Staff')).toBeInTheDocument()
    expect(screen.getByText('Active Workforce')).toBeInTheDocument()

    expect(await screen.findByText('Aarav Sharma')).toBeInTheDocument()
    expect(screen.getByText('EMP-001')).toBeInTheDocument()
    expect(screen.getByText('Senior Formulation Chemist')).toBeInTheDocument()
    expect(screen.getByText('Pooja Reddy')).toBeInTheDocument()
    expect(screen.getByText('EMP-002')).toBeInTheDocument()
    expect(screen.getByText('QC Analyst')).toBeInTheDocument()
  })

  it('filters employees by search input and status tabs', async () => {
    renderWithClient(<EmployeesPage />)

    expect(await screen.findByText('Aarav Sharma')).toBeInTheDocument()
    expect(screen.getByText('Pooja Reddy')).toBeInTheDocument()

    const searchInput = screen.getByPlaceholderText(/Search by code, name, designation/i)
    fireEvent.change(searchInput, { target: { value: 'Pooja' } })

    expect(screen.queryByText('Aarav Sharma')).not.toBeInTheDocument()
    expect(screen.getByText('Pooja Reddy')).toBeInTheDocument()

    // Clear search
    fireEvent.change(searchInput, { target: { value: '' } })
    expect(screen.getByText('Aarav Sharma')).toBeInTheDocument()

    // Filter by ON_NOTICE tab
    const onNoticeTab = screen.getByRole('tab', { name: 'On Notice' })
    fireEvent.click(onNoticeTab)

    expect(screen.queryByText('Aarav Sharma')).not.toBeInTheDocument()
    expect(screen.getByText('Pooja Reddy')).toBeInTheDocument()
  })

  it('opens add employee modal and submits new employee record', async () => {
    vi.mocked(payrollApi.createEmployee).mockResolvedValue({ id: 'emp-3' } as unknown as Awaited<ReturnType<typeof payrollApi.createEmployee>>)

    renderWithClient(<EmployeesPage />)

    const addBtn = await screen.findByRole('button', { name: /Add Employee/i })
    fireEvent.click(addBtn)

    expect(await screen.findByRole('heading', { name: 'Add New Employee' })).toBeInTheDocument()

    // Fill in required fields
    const nameInput = screen.getByLabelText(/Full Name/i)
    fireEvent.change(nameInput, { target: { value: 'Meera Nair' } })

    const codeInput = screen.getByLabelText(/Employee Code/i)
    fireEvent.change(codeInput, { target: { value: 'EMP-003' } })

    const desigInput = screen.getByLabelText(/Designation/i)
    fireEvent.change(desigInput, { target: { value: 'Production Supervisor' } })

    const submitBtn = screen.getByRole('button', { name: /Create Employee Profile/i })
    fireEvent.click(submitBtn)

    await waitFor(() => {
      expect(payrollApi.createEmployee).toHaveBeenCalledWith(
        expect.objectContaining({
          fullName: 'Meera Nair',
          employeeCode: 'EMP-003',
          designation: 'Production Supervisor',
        }),
      )
    })
  })
})

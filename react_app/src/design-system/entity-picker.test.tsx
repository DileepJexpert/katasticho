import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { EntityPicker } from './entity-picker'

type Customer = {
  id: string
  name: string
  phone: string
  city: string
}

const mockCustomers: Customer[] = [
  { id: 'cust-1', name: 'Apollo Pharmacy', phone: '9876543210', city: 'Mumbai' },
  { id: 'cust-2', name: 'MedPlus Chemist', phone: '9876543211', city: 'Pune' },
  { id: 'cust-3', name: 'Wellness Forever', phone: '9876543212', city: 'Thane' },
]

describe('EntityPicker primitive', () => {
  it('renders search input when no entity is selected', () => {
    render(
      <EntityPicker
        value={null}
        onChange={vi.fn()}
        options={mockCustomers}
        getOptionId={(c) => c.id}
        getOptionLabel={(c) => c.name}
        placeholder="Select customer..."
      />
    )

    expect(screen.getByPlaceholderText('Select customer...')).toBeInTheDocument()
    expect(screen.getByRole('combobox')).toHaveAttribute('aria-expanded', 'false')
  })

  it('shows options on focus and selects an option via click', async () => {
    const user = userEvent.setup()
    const handleChange = vi.fn()

    render(
      <EntityPicker
        value={null}
        onChange={handleChange}
        options={mockCustomers}
        getOptionId={(c) => c.id}
        getOptionLabel={(c) => c.name}
        getOptionDescription={(c) => `${c.phone} • ${c.city}`}
      />
    )

    const input = screen.getByRole('combobox')
    await user.click(input)

    expect(screen.getByRole('listbox')).toBeInTheDocument()
    expect(screen.getByText('Apollo Pharmacy')).toBeInTheDocument()
    expect(screen.getByText('9876543210 • Mumbai')).toBeInTheDocument()

    await user.click(screen.getByText('Apollo Pharmacy'))
    expect(handleChange).toHaveBeenCalledWith('cust-1', mockCustomers[0])
  })

  it('filters options according to search query', async () => {
    const user = userEvent.setup()

    render(
      <EntityPicker
        value={null}
        onChange={vi.fn()}
        options={mockCustomers}
        getOptionId={(c) => c.id}
        getOptionLabel={(c) => c.name}
      />
    )

    const input = screen.getByRole('combobox')
    await user.type(input, 'MedPlus')

    expect(screen.getByText('MedPlus Chemist')).toBeInTheDocument()
    expect(screen.queryByText('Apollo Pharmacy')).not.toBeInTheDocument()
  })

  it('renders selected token when value is provided', async () => {
    const user = userEvent.setup()
    const handleChange = vi.fn()

    render(
      <EntityPicker
        value="cust-1"
        selectedEntity={mockCustomers[0]}
        onChange={handleChange}
        options={mockCustomers}
        getOptionId={(c) => c.id}
        getOptionLabel={(c) => c.name}
        getOptionDescription={(c) => c.city}
      />
    )

    expect(screen.getByText('Apollo Pharmacy')).toBeInTheDocument()
    expect(screen.getByText('Mumbai')).toBeInTheDocument()
    expect(screen.queryByRole('combobox')).not.toBeInTheDocument()

    const clearBtn = screen.getByRole('button', { name: /clear selection/i })
    await user.click(clearBtn)
    expect(handleChange).toHaveBeenCalledWith(null, null)
  })

  it('supports keyboard arrow navigation and Enter to select', async () => {
    const handleChange = vi.fn()

    render(
      <EntityPicker
        value={null}
        onChange={handleChange}
        options={mockCustomers}
        getOptionId={(c) => c.id}
        getOptionLabel={(c) => c.name}
      />
    )

    const input = screen.getByRole('combobox')
    fireEvent.focus(input)
    fireEvent.keyDown(input, { key: 'ArrowDown' })
    fireEvent.keyDown(input, { key: 'Enter' })

    expect(handleChange).toHaveBeenCalledWith('cust-1', mockCustomers[0])
  })
})

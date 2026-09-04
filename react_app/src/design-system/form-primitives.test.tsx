import { describe, expect, it, vi } from 'vitest'
import { fireEvent, render, screen } from '@testing-library/react'
import { createRef } from 'react'
import { Search } from 'lucide-react'
import { FormField } from './form-field'
import { TextInput } from './text-input'
import { NumberInput } from './number-input'
import { CheckboxInput } from './checkbox-input'
import { DocumentError } from './document-error'

describe('Form Primitives', () => {
  it('renders FormField with auto-generated id linking label and child', () => {
    render(
      <FormField label="Customer Name" required tooltip="Legal customer name">
        <TextInput placeholder="Enter customer" />
      </FormField>
    )

    const input = screen.getByPlaceholderText('Enter customer')
    const label = screen.getByText('Customer Name')
    expect(label.closest('label')).toHaveAttribute('for', input.getAttribute('id'))
    expect(screen.getByText('*')).toHaveClass('field-required-mark')
    expect(screen.getByTitle('Legal customer name')).toBeInTheDocument()
  })

  it('renders FormField with error alert and optional tag', () => {
    render(
      <FormField label="Credit Limit" optional error="Limit exceeds ceiling">
        <input />
      </FormField>
    )

    expect(screen.getByText('(optional)')).toHaveClass('field-optional-tag')
    const errorAlert = screen.getByRole('alert')
    expect(errorAlert).toHaveTextContent('Limit exceeds ceiling')
    expect(errorAlert).toHaveClass('field-error')
  })

  it('renders TextInput with prefix/suffix icons and forwards ref', () => {
    const inputRef = createRef<HTMLInputElement>()
    const handleChange = vi.fn()

    render(
      <TextInput
        ref={inputRef}
        placeholder="Search accounts"
        leftIcon={<Search aria-hidden="true" size={16} />}
        rightIcon={<span>CR</span>}
        onChange={handleChange}
        isInvalid
      />
    )

    const input = screen.getByPlaceholderText('Search accounts')
    expect(inputRef.current).toBe(input)
    expect(input).toHaveClass('input-with-icons__input--left')
    expect(input).toHaveClass('input-with-icons__input--right')
    expect(input).toHaveClass('field-input--error')

    fireEvent.change(input, { target: { value: 'Cash' } })
    expect(handleChange).toHaveBeenCalledTimes(1)
  })

  it('renders NumberInput with currency prefix and unit suffix', () => {
    const inputRef = createRef<HTMLInputElement>()

    render(
      <NumberInput
        ref={inputRef}
        currencyPrefix="₹"
        unitSuffix="kg"
        placeholder="0.00"
        defaultValue={25}
      />
    )

    const input = screen.getByPlaceholderText('0.00')
    expect(inputRef.current).toBe(input)
    expect(input).toHaveClass('number-input--prefix')
    expect(input).toHaveClass('number-input--suffix')
    expect(screen.getByText('₹')).toHaveClass('number-input-prefix')
    expect(screen.getByText('kg')).toHaveClass('number-input-suffix')
  })

  it('renders CheckboxInput with label, description, and handles change', () => {
    const handleChange = vi.fn()

    render(
      <CheckboxInput
        label="Enable auto-numbering"
        description="Automatically assigns sequence numbers to new vouchers"
        onChange={handleChange}
      />
    )

    const checkbox = screen.getByRole('checkbox', { name: /Enable auto-numbering/i })
    expect(checkbox).not.toBeChecked()
    expect(screen.getByText('Automatically assigns sequence numbers to new vouchers')).toHaveClass('form-checkbox-description')

    fireEvent.click(checkbox)
    expect(handleChange).toHaveBeenCalledTimes(1)
  })

  it('renders DocumentError and triggers back action', () => {
    const handleBack = vi.fn()

    render(
      <DocumentError
        onBack={handleBack}
        backLabel="Back to accounts"
        title="Account not found"
        message="The requested chart of account entry could not be retrieved."
      />
    )

    expect(screen.getByRole('alert')).toBeInTheDocument()
    expect(screen.getByText('Account not found')).toBeInTheDocument()
    expect(screen.getByText('The requested chart of account entry could not be retrieved.')).toBeInTheDocument()

    const backButton = screen.getByRole('button', { name: /Back to accounts/i })
    fireEvent.click(backButton)
    expect(handleBack).toHaveBeenCalledTimes(1)
  })
})

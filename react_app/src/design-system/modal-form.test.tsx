import { fireEvent, render, screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { FormField } from '@/design-system/form-field'
import { Modal } from '@/design-system/modal'
import { TextInput } from '@/design-system/text-input'

describe('Modal Primitive', () => {
  it('renders accessibility attributes and closes on Escape key', () => {
    const onClose = vi.fn()

    render(
      <Modal
        description="Verify ledger allocation"
        isOpen
        onClose={onClose}
        title="Journal Voucher"
      >
        <p>Modal body content</p>
      </Modal>
    )

    const dialog = screen.getByRole('dialog')
    expect(dialog).toBeInTheDocument()
    expect(dialog).toHaveAttribute('aria-modal', 'true')
    expect(dialog).toHaveAttribute('aria-labelledby')
    expect(dialog).toHaveAttribute('aria-describedby')

    const title = screen.getByRole('heading', { level: 3, name: 'Journal Voucher' })
    expect(title).toBeInTheDocument()
    expect(title.id).toBe(dialog.getAttribute('aria-labelledby'))

    fireEvent.keyDown(document, { key: 'Escape' })
    expect(onClose).toHaveBeenCalledTimes(1)
  })

  it('renders inline error banner when error prop is provided', () => {
    render(
      <Modal
        error="Duplicate warehouse code 'WH-BOM'"
        isOpen
        onClose={vi.fn()}
        title="Create Facility"
      >
        <p>Form fields</p>
      </Modal>
    )

    const errorAlert = screen.getByRole('alert')
    expect(errorAlert).toBeInTheDocument()
    expect(errorAlert).toHaveTextContent("Duplicate warehouse code 'WH-BOM'")
  })

  it('does not render when isOpen is false', () => {
    render(
      <Modal
        isOpen={false}
        onClose={vi.fn()}
        title="Hidden Dialog"
      >
        <p>Should not exist</p>
      </Modal>
    )

    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })

  it('traps keyboard focus and restores the invoking control when closed', () => {
    const onClose = vi.fn()
    const { rerender } = render(
      <>
        <button type="button">Open journal voucher</button>
        <Modal isOpen={false} onClose={onClose} title="Journal Voucher">
          <button type="button">Review entries</button>
        </Modal>
      </>
    )

    const trigger = screen.getByRole('button', { name: 'Open journal voucher' })
    trigger.focus()

    rerender(
      <>
        <button type="button">Open journal voucher</button>
        <Modal isOpen onClose={onClose} title="Journal Voucher">
          <button type="button">Review entries</button>
        </Modal>
      </>
    )

    const closeButton = screen.getByRole('button', { name: 'Close dialog' })
    const reviewButton = screen.getByRole('button', { name: 'Review entries' })
    expect(closeButton).toHaveFocus()

    reviewButton.focus()
    fireEvent.keyDown(document, { key: 'Tab' })
    expect(closeButton).toHaveFocus()

    fireEvent.keyDown(document, { key: 'Tab', shiftKey: true })
    expect(reviewButton).toHaveFocus()

    rerender(
      <>
        <button type="button">Open journal voucher</button>
        <Modal isOpen={false} onClose={onClose} title="Journal Voucher">
          <button type="button">Review entries</button>
        </Modal>
      </>
    )

    expect(trigger).toHaveFocus()
  })
})

describe('FormField Primitive', () => {
  it('automatically connects label htmlFor to child input id', () => {
    render(
      <FormField label="Account Code" required>
        <TextInput placeholder="e.g. 1010" />
      </FormField>
    )

    const label = screen.getByText('Account Code')
    const input = screen.getByPlaceholderText('e.g. 1010')

    const labelElement = label.closest('label')
    expect(labelElement).toHaveAttribute('for')
    expect(input.id).toBe(labelElement?.getAttribute('for'))
  })
})

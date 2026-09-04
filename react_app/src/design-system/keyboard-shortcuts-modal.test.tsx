import { fireEvent, render, screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { KeyboardShortcutsModal } from './keyboard-shortcuts-modal'

describe('KeyboardShortcutsModal', () => {
  it('renders modal content when open', () => {
    const handleClose = vi.fn()
    render(<KeyboardShortcutsModal isOpen={true} onClose={handleClose} />)

    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(screen.getByText('Keyboard shortcuts')).toBeInTheDocument()
    expect(screen.getByText('Navigation & Search')).toBeInTheDocument()
    expect(screen.getByText('Forms & Dialogs')).toBeInTheDocument()
    expect(screen.getByText('Tables & Registers')).toBeInTheDocument()
    expect(screen.getByText('Open command palette / quick jump')).toBeInTheDocument()
  })

  it('calls onClose when close button is clicked', () => {
    const handleClose = vi.fn()
    render(<KeyboardShortcutsModal isOpen={true} onClose={handleClose} />)

    const closeBtn = screen.getByRole('button', { name: 'Close' })
    fireEvent.click(closeBtn)

    expect(handleClose).toHaveBeenCalledTimes(1)
  })

  it('triggers onOpen when pressing ? outside an input', () => {
    const handleOpen = vi.fn()
    const handleClose = vi.fn()
    render(<KeyboardShortcutsModal isOpen={false} onClose={handleClose} onOpen={handleOpen} />)

    fireEvent.keyDown(window, { key: '?' })
    expect(handleOpen).toHaveBeenCalledTimes(1)
  })

  it('triggers onOpen when pressing F1 outside an input', () => {
    const handleOpen = vi.fn()
    const handleClose = vi.fn()
    render(<KeyboardShortcutsModal isOpen={false} onClose={handleClose} onOpen={handleOpen} />)

    fireEvent.keyDown(window, { key: 'F1' })
    expect(handleOpen).toHaveBeenCalledTimes(1)
  })

  it('does not trigger onOpen when typing ? in an input or textarea', () => {
    const handleOpen = vi.fn()
    const handleClose = vi.fn()
    render(
      <div>
        <input data-testid="test-input" type="text" />
        <KeyboardShortcutsModal isOpen={false} onClose={handleClose} onOpen={handleOpen} />
      </div>
    )

    const input = screen.getByTestId('test-input')
    fireEvent.keyDown(input, { key: '?' })
    expect(handleOpen).not.toHaveBeenCalled()
  })

  it('triggers onClose when ? is pressed while modal is already open', () => {
    const handleClose = vi.fn()
    render(<KeyboardShortcutsModal isOpen={true} onClose={handleClose} />)

    fireEvent.keyDown(window, { key: '?' })
    expect(handleClose).toHaveBeenCalledTimes(1)
  })
})

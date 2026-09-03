import { fireEvent, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { appRoutes, getVisibleNavigation } from '@/app/navigation'
import { CommandPalette } from '@/design-system/command-palette'

const navigation = getVisibleNavigation({ role: 'ADMIN', industry: null, country: null })

describe('CommandPalette', () => {
  it('filters commands and navigates through a real route', async () => {
    const user = userEvent.setup()
    const onNavigate = vi.fn()
    const onOpenChange = vi.fn()

    render(
      <CommandPalette
        isOpen
        navigation={navigation}
        onNavigate={onNavigate}
        onOpenChange={onOpenChange}
        onSignOut={vi.fn()}
      />,
    )

    await user.type(screen.getByRole('combobox', { name: 'Search commands' }), 'contacts')
    await user.click(screen.getByRole('option', { name: 'Contacts: Customers, vendors, and suppliers' }))

    expect(onNavigate).toHaveBeenCalledWith(appRoutes.contacts)
    expect(onOpenChange).toHaveBeenCalledWith(false)
  })

  it('opens from the Ctrl+K shortcut and closes with Escape', async () => {
    const onOpenChange = vi.fn()

    render(
      <CommandPalette
        isOpen
        navigation={navigation}
        onNavigate={vi.fn()}
        onOpenChange={onOpenChange}
        onSignOut={vi.fn()}
      />,
    )

    fireEvent.keyDown(window, { ctrlKey: true, key: 'k' })
    await userEvent.setup().keyboard('{Escape}')

    expect(onOpenChange).toHaveBeenNthCalledWith(1, true)
    expect(onOpenChange).toHaveBeenLastCalledWith(false)
  })
})

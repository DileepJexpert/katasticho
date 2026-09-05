import { useState } from 'react'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, it } from 'vitest'
import { Modal } from './modal'
import { TextInput } from './text-input'

it('keeps focus in a later field while its parent rerenders', async () => {
  function Example() {
    const [second, setSecond] = useState('')
    const [open, setOpen] = useState(true)
    return <Modal isOpen={open} title="Edit pricing" onClose={() => setOpen(false)}><TextInput aria-label="Name" /><TextInput aria-label="Currency" value={second} onChange={(event) => setSecond(event.target.value)} /></Modal>
  }
  const user = userEvent.setup()
  render(<Example />)
  const currency = screen.getByLabelText('Currency')
  await user.type(currency, 'INR')
  expect(currency).toHaveValue('INR')
  expect(currency).toHaveFocus()
  await user.keyboard('{Escape}')
  expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
})

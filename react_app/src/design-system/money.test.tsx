import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { Money } from './money'

describe('Money', () => {
  it('retains INR formatting by default', () => {
    render(<Money amount={123456.7} />)
    expect(screen.getByText('₹1,23,456.70')).toBeInTheDocument()
  })

  it('can omit an unknown currency without inventing an INR symbol', () => {
    render(<Money amount={123456.7} showCurrency={false} />)
    expect(screen.getByText('1,23,456.70')).toBeInTheDocument()
    expect(screen.queryByText(/₹/)).not.toBeInTheDocument()
  })
})

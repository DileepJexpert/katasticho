import { Suspense } from 'react'
import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { lazyNamed, resolveNamedComponent } from '@/app/lazy-named'

describe('lazyNamed', () => {
  it('loads a named component export', async () => {
    const ExamplePage = lazyNamed(
      async () => ({ ExamplePage: () => <h1>Lazy route ready</h1> }),
      'ExamplePage',
    )

    render(
      <Suspense fallback={<p>Loading route</p>}>
        <ExamplePage />
      </Suspense>,
    )

    expect(screen.getByText('Loading route')).toBeInTheDocument()
    expect(await screen.findByRole('heading', { name: 'Lazy route ready' })).toBeInTheDocument()
  })

  it('rejects a missing named component export', () => {
    expect(() => resolveNamedComponent({}, 'MissingPage')).toThrow(
      'Lazy route export "MissingPage" is not a React component.',
    )
  })
})

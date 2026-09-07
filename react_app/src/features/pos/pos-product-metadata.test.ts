import { describe, expect, it } from 'vitest'
import { formatPosProductMetadata } from './pos-product-metadata'

describe('formatPosProductMetadata', () => {
  it('keeps an existing HSN code visible in POS search metadata', () => {
    expect(formatPosProductMetadata({
      sku: 'MASALA-100G',
      hsnCode: '0910',
      rackLocationCode: 'A-01',
      batchNumber: 'B-42',
    })).toBe('MASALA-100G / HSN 0910 / Rack A-01 / Batch B-42')
  })

  it('does not render an empty statutory marker when the item has no HSN code', () => {
    expect(formatPosProductMetadata({ sku: 'SERV-1', hsnCode: null, rackLocationCode: null, batchNumber: null }))
      .toBe('SERV-1')
  })
})

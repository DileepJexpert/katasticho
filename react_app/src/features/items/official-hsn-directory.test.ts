import { describe, expect, it } from 'vitest'
import { searchOfficialHsnEntries, type OfficialHsnEntry } from './official-hsn-directory'

const records: OfficialHsnEntry[] = [
  { hsnCode: '09', description: 'Coffee, tea, mate and spices' },
  { hsnCode: '0910', description: 'Ginger, saffron, turmeric and other spices' },
  { hsnCode: '09103030', description: 'Turmeric powder' },
  { hsnCode: '1006', description: 'Rice' },
]

describe('official HSN directory search', () => {
  it('prioritises an exact code and then its more detailed descendants', () => {
    expect(searchOfficialHsnEntries(records, '0910')).toEqual([
      records[1],
      records[2],
    ])
  })

  it('matches common product descriptions', () => {
    expect(searchOfficialHsnEntries(records, 'turmeric powder')).toEqual([
      records[2],
    ])
  })

  it('does not scan the large directory for a one-character query', () => {
    expect(searchOfficialHsnEntries(records, '0')).toEqual([])
  })
})

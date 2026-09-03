import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Calculator, Plus, Tag, Trash2 } from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  listFreightRateCards,
  createFreightRateCard,
  deleteFreightRateCard,
  quoteFreightRate,
  type FreightRateCardRequest,
  type RateQuoteResponse,
} from '@/features/transport/transport-api'
import { listContacts } from '@/features/contacts/contacts-api'

export function FreightRateCardsPage() {
  const [selectedTransporter, setSelectedTransporter] = useState('')
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [feedback, setFeedback] = useState<string | null>(null)
  const queryClient = useQueryClient()

  const contactsQuery = useQuery({
    queryKey: ['transporters-rate-cards'],
    queryFn: () => listContacts({ filter: 'ALL', page: 0 }),
  })

  const rateCardsQuery = useQuery({
    queryKey: ['freight-rate-cards', selectedTransporter],
    queryFn: () => listFreightRateCards(selectedTransporter || undefined),
  })

  const createMutation = useMutation({
    mutationFn: (data: FreightRateCardRequest) => createFreightRateCard(data),
    onSuccess: () => {
      setIsModalOpen(false)
      setFeedback('Freight rate card added.')
      queryClient.invalidateQueries({ queryKey: ['freight-rate-cards'] })
    },
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => deleteFreightRateCard(id),
    onSuccess: () => {
      setFeedback('Rate card removed.')
      queryClient.invalidateQueries({ queryKey: ['freight-rate-cards'] })
    },
  })

  const rateCards = rateCardsQuery.data ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Logistics & Transport / Rate Matrix"
        title="Freight Rate Cards"
        description="Transporter lane pricing matrix, weight slab tariffs, minimum charges, and dynamic freight quote engine."
        actions={
          <Button onClick={() => setIsModalOpen(true)} variant="primary">
            <Plus aria-hidden="true" size={16} />
            New Rate Card
          </Button>
        }
      />

      {feedback ? (
        <div className="notification-banner notification-banner--success" role="status">
          <p>{feedback}</p>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">×</button>
        </div>
      ) : null}

      <div className="grid-2-cols" style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '1.5rem' }}>
        <main>
          <div className="list-toolbar">
            <div className="form-group" style={{ maxWidth: '300px' }}>
              <label htmlFor="filter-transporter">Filter by Transporter</label>
              <select
                id="filter-transporter"
                value={selectedTransporter}
                onChange={(e) => setSelectedTransporter(e.target.value)}
              >
                <option value="">All Transporters</option>
                {contactsQuery.data?.content.map((c) => (
                  <option key={c.id} value={c.id}>{c.displayName}</option>
                ))}
              </select>
            </div>
          </div>

          {rateCardsQuery.isError ? (
            <div className="directory-state directory-state--error" role="alert">
              <strong>Rate cards could not be loaded.</strong>
            </div>
          ) : rateCardsQuery.isLoading ? (
            <div className="directory-state">Loading rate cards...</div>
          ) : rateCards.length ? (
            <DataTable caption="Freight rate cards">
              <thead>
                <tr>
                  <th scope="col">Lane (Route)</th>
                  <th scope="col">Mode</th>
                  <th scope="col">Weight Slab</th>
                  <th scope="col">Rate Type</th>
                  <th scope="col">Tariff Rate</th>
                  <th scope="col">Min Charge</th>
                  <th scope="col">Validity</th>
                  <th scope="col">Status</th>
                  <th scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {rateCards.map((rc) => (
                  <tr key={rc.id}>
                    <td>
                      <strong>{rc.origin || 'Any'} â†’ {rc.destination || 'Any'}</strong>
                    </td>
                    <td>{rc.mode || 'ROAD'}</td>
                    <td>
                      {rc.weightSlabMinKg || rc.weightSlabMaxKg
                        ? `${rc.weightSlabMinKg ?? 0} - ${rc.weightSlabMaxKg ?? 'âˆž'} kg`
                        : 'All weights'}
                    </td>
                    <td><StatusChip status={formatStatusLabel(rc.rateType || 'PER_KG')} /></td>
                    <td>
                      <strong><Money amount={rc.rate} /></strong>
                      <small className="cell-muted">/{rc.rateType === 'FLAT' ? 'trip' : rc.rateType === 'PER_UNIT' ? 'unit' : 'kg'}</small>
                    </td>
                    <td><Money amount={rc.minCharge} /></td>
                    <td>
                      <small>{formatDate(rc.effectiveFrom)} to {formatDate(rc.effectiveTo)}</small>
                    </td>
                    <td><StatusChip status={rc.active ? 'Active' : 'Inactive'} /></td>
                    <td>
                      <Button
                        onClick={() => {
                          if (confirm('Delete this rate card?')) deleteMutation.mutate(rc.id)
                        }}
                        type="button"
                        variant="ghost"
                      >
                        <Trash2 size={14} />
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="directory-state directory-state--empty">
              <Tag aria-hidden="true" size={32} />
              <strong>No rate cards found.</strong>
              <p>Add lane rates for your primary transporters.</p>
            </div>
          )}
        </main>

        <aside>
          <LiveRateQuoteCalculator
            contacts={contactsQuery.data?.content ?? []}
          />
        </aside>
      </div>

      {isModalOpen ? (
        <CreateRateCardModal
          contacts={contactsQuery.data?.content ?? []}
          isSubmitting={createMutation.isPending}
          onClose={() => setIsModalOpen(false)}
          onSubmit={(d) => createMutation.mutate(d)}
        />
      ) : null}
    </section>
  )
}

function LiveRateQuoteCalculator({
  contacts,
}: {
  contacts: Array<{ id: string; displayName: string }>
}) {
  const [transporterContactId, setTransporterContactId] = useState(contacts[0]?.id ?? '')
  const [origin, setOrigin] = useState('')
  const [destination, setDestination] = useState('')
  const [mode, setMode] = useState('ROAD')
  const [weightKg, setWeightKg] = useState<number | undefined>(50)
  const [quoteResult, setQuoteResult] = useState<RateQuoteResponse | null>(null)
  const [isCalculating, setIsCalculating] = useState(false)

  const handleCalculate = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!transporterContactId) return
    setIsCalculating(true)
    try {
      const res = await quoteFreightRate({
        transporterContactId,
        origin: origin.trim() || undefined,
        destination: destination.trim() || undefined,
        mode,
        weightKg: weightKg ?? undefined,
      })
      setQuoteResult(res)
    } finally {
      setIsCalculating(false)
    }
  }

  return (
    <article className="document-card">
      <header className="document-card-header">
        <h2>
          <Calculator aria-hidden="true" size={18} style={{ display: 'inline', marginRight: '0.5rem' }} />
          Rate Quote Engine
        </h2>
      </header>
      <form onSubmit={handleCalculate}>
        <div className="form-group">
          <label htmlFor="quote-transporter">Transporter *</label>
          <select
            id="quote-transporter"
            required
            value={transporterContactId}
            onChange={(e) => setTransporterContactId(e.target.value)}
          >
            <option value="">Select transporter...</option>
            {contacts.map((c) => (
              <option key={c.id} value={c.id}>{c.displayName}</option>
            ))}
          </select>
        </div>

        <div className="form-group">
          <label htmlFor="quote-origin">Origin</label>
          <input
            id="quote-origin"
            placeholder="e.g. Bhiwandi"
            type="text"
            value={origin}
            onChange={(e) => setOrigin(e.target.value)}
          />
        </div>

        <div className="form-group">
          <label htmlFor="quote-dest">Destination</label>
          <input
            id="quote-dest"
            placeholder="e.g. Pune"
            type="text"
            value={destination}
            onChange={(e) => setDestination(e.target.value)}
          />
        </div>

        <div className="form-group">
          <label htmlFor="quote-mode">Transport Mode</label>
          <select id="quote-mode" value={mode} onChange={(e) => setMode(e.target.value)}>
            <option value="ROAD">Road</option>
            <option value="RAIL">Rail</option>
            <option value="AIR">Air</option>
          </select>
        </div>

        <div className="form-group">
          <label htmlFor="quote-weight">Cargo Weight (kg)</label>
          <input
            id="quote-weight"
            min="0"
            step="0.01"
            type="number"
            value={weightKg ?? ''}
            onChange={(e) => setWeightKg(e.target.value ? Number(e.target.value) : undefined)}
          />
        </div>

        <Button disabled={isCalculating} type="submit" variant="primary">
          {isCalculating ? 'Computing...' : 'Calculate Freight Quote'}
        </Button>
      </form>

      {quoteResult ? (
        <div className="quote-result-box" style={{ marginTop: '1rem', padding: '1rem', background: 'var(--k-color-bg-subtle, #fafafa)', borderRadius: '6px' }}>
          {quoteResult.found ? (
            <>
              <div className="progress-row">
                <span>Estimated Freight</span>
                <strong style={{ fontSize: '1.25rem', color: 'var(--k-color-brand, #0f8576)' }}>
                  <Money amount={quoteResult.freightAmount} />
                </strong>
              </div>
              <p className="cell-muted" style={{ marginTop: '0.5rem', fontSize: '0.875rem' }}>
                <strong>Calculation Basis:</strong> {quoteResult.basis}
              </p>
            </>
          ) : (
            <p className="text-warning">{quoteResult.message || 'No matching rate card found for this lane/weight.'}</p>
          )}
        </div>
      ) : null}
    </article>
  )
}

function CreateRateCardModal({
  contacts,
  isSubmitting,
  onClose,
  onSubmit,
}: {
  contacts: Array<{ id: string; displayName: string }>
  isSubmitting: boolean
  onClose: () => void
  onSubmit: (data: FreightRateCardRequest) => void
}) {
  const [transporterContactId, setTransporterContactId] = useState(contacts[0]?.id ?? '')
  const [origin, setOrigin] = useState('')
  const [destination, setDestination] = useState('')
  const [mode, setMode] = useState('ROAD')
  const [weightSlabMinKg, setWeightSlabMinKg] = useState<number | undefined>(undefined)
  const [weightSlabMaxKg, setWeightSlabMaxKg] = useState<number | undefined>(undefined)
  const [rateType, setRateType] = useState('PER_KG')
  const [rate, setRate] = useState<number>(0)
  const [minCharge, setMinCharge] = useState<number | undefined>(undefined)
  const [effectiveFrom, setEffectiveFrom] = useState('')
  const [effectiveTo, setEffectiveTo] = useState('')
  const [notes, setNotes] = useState('')

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!transporterContactId || rate <= 0) return
    onSubmit({
      transporterContactId,
      origin: origin.trim() || null,
      destination: destination.trim() || null,
      mode,
      weightSlabMinKg: weightSlabMinKg ?? null,
      weightSlabMaxKg: weightSlabMaxKg ?? null,
      rateType,
      rate,
      minCharge: minCharge ?? null,
      effectiveFrom: effectiveFrom || null,
      effectiveTo: effectiveTo || null,
      notes: notes.trim() || null,
    })
  }

  return (
    <div className="modal-backdrop" role="dialog" aria-modal="true">
      <div className="modal-card">
        <header className="modal-header">
          <h2>Create Freight Rate Card</h2>
          <button className="modal-close" onClick={onClose} type="button">×</button>
        </header>
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label htmlFor="rc-transporter">Transporter *</label>
            <select
              id="rc-transporter"
              required
              value={transporterContactId}
              onChange={(e) => setTransporterContactId(e.target.value)}
            >
              <option value="">Select transporter...</option>
              {contacts.map((c) => (
                <option key={c.id} value={c.id}>{c.displayName}</option>
              ))}
            </select>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="rc-origin">Origin Lane (optional)</label>
              <input
                id="rc-origin"
                placeholder="Leave blank for any origin"
                type="text"
                value={origin}
                onChange={(e) => setOrigin(e.target.value)}
              />
            </div>
            <div className="form-group">
              <label htmlFor="rc-dest">Destination Lane (optional)</label>
              <input
                id="rc-dest"
                placeholder="Leave blank for any destination"
                type="text"
                value={destination}
                onChange={(e) => setDestination(e.target.value)}
              />
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="rc-mode">Transport Mode</label>
              <select id="rc-mode" value={mode} onChange={(e) => setMode(e.target.value)}>
                <option value="ROAD">Road</option>
                <option value="RAIL">Rail</option>
                <option value="AIR">Air</option>
              </select>
            </div>
            <div className="form-group">
              <label htmlFor="rc-slab-min">Weight Slab Min (kg)</label>
              <input
                id="rc-slab-min"
                min="0"
                step="0.01"
                type="number"
                value={weightSlabMinKg ?? ''}
                onChange={(e) => setWeightSlabMinKg(e.target.value ? Number(e.target.value) : undefined)}
              />
            </div>
            <div className="form-group">
              <label htmlFor="rc-slab-max">Weight Slab Max (kg)</label>
              <input
                id="rc-slab-max"
                min="0"
                step="0.01"
                type="number"
                value={weightSlabMaxKg ?? ''}
                onChange={(e) => setWeightSlabMaxKg(e.target.value ? Number(e.target.value) : undefined)}
              />
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="rc-type">Rate Type *</label>
              <select id="rc-type" value={rateType} onChange={(e) => setRateType(e.target.value)}>
                <option value="PER_KG">Per Kilogram (â‚¹/kg)</option>
                <option value="FLAT">Flat Fee per Trip (â‚¹)</option>
                <option value="PER_UNIT">Per Package / Unit (â‚¹/pkg)</option>
              </select>
            </div>
            <div className="form-group">
              <label htmlFor="rc-rate">Rate Amount (â‚¹) *</label>
              <input
                id="rc-rate"
                min="0.01"
                required
                step="0.01"
                type="number"
                value={rate || ''}
                onChange={(e) => setRate(Number(e.target.value))}
              />
            </div>
            <div className="form-group">
              <label htmlFor="rc-min">Minimum Charge (â‚¹)</label>
              <input
                id="rc-min"
                min="0"
                step="0.01"
                type="number"
                value={minCharge ?? ''}
                onChange={(e) => setMinCharge(e.target.value ? Number(e.target.value) : undefined)}
              />
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="rc-from">Effective From</label>
              <input
                id="rc-from"
                type="date"
                value={effectiveFrom}
                onChange={(e) => setEffectiveFrom(e.target.value)}
              />
            </div>
            <div className="form-group">
              <label htmlFor="rc-to">Effective To</label>
              <input
                id="rc-to"
                type="date"
                value={effectiveTo}
                onChange={(e) => setEffectiveTo(e.target.value)}
              />
            </div>
          </div>

          <div className="form-group">
            <label htmlFor="rc-notes">Notes</label>
            <input
              id="rc-notes"
              type="text"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
            />
          </div>

          <footer className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isSubmitting} type="submit" variant="primary">
              {isSubmitting ? 'Saving...' : 'Add Rate Card'}
            </Button>
          </footer>
        </form>
      </div>
    </div>
  )
}
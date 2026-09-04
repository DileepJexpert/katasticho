import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useNavigate, useParams } from 'react-router-dom'
import {
  ArrowLeft,
  Plus,
  Trash2,
  Users,
} from 'lucide-react'
import {
  Button,
  DataTable,
  DocumentError,
  EntityPicker,
  FormField,
  Modal,
  NumberInput,
  PageHeader,
  SelectInput,
  StatusChip,
  } from '@/design-system'
import { listContacts } from '@/features/contacts/contacts-api'
import {
  addCustomerToBeat,
  getBeat,
  getBeatCustomers,
  removeCustomerFromBeat,
  type BeatCustomer,
} from '@/features/field-sales/field-sales-api'

export function BeatDetailPage() {
  const { beatId = '' } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [isAddCustomerOpen, setIsAddCustomerOpen] = useState(false)

  const { data: beat, isLoading, isError } = useQuery({
    queryKey: ['field-sales', 'beats', beatId],
    queryFn: () => getBeat(beatId),
    enabled: !!beatId,
  })

  const { data: customers = [] } = useQuery({
    queryKey: ['field-sales', 'beats', beatId, 'customers'],
    queryFn: () => getBeatCustomers(beatId),
    enabled: !!beatId,
  })

  const addCustomerMutation = useMutation({
    mutationFn: (payload: { contactId: string; visitSequence?: number; visitFrequency?: string }) =>
      addCustomerToBeat(beatId, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'beats', beatId, 'customers'] })
      setIsAddCustomerOpen(false)
    },
  })

  const removeCustomerMutation = useMutation({
    mutationFn: (contactId: string) => removeCustomerFromBeat(beatId, contactId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'beats', beatId, 'customers'] })
    },
  })

  if (isLoading) return <div className="directory-state">Loading sales beat profile...</div>
  if (isError || !beat) return <DocumentError onBack={() => navigate('/beats')} />

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div style={{ display: 'flex', gap: 8 }}>
            <Button onClick={() => setIsAddCustomerOpen(true)} type="button" variant="primary">
              <Plus aria-hidden="true" size={16} />
              <span>Add Customer Stop</span>
            </Button>
          </div>
        }
        description={`Area: ${beat.area || 'General'} | City: ${beat.city || 'â€”'} | Status: ${beat.isActive ? 'ACTIVE' : 'INACTIVE'}`}
        eyebrow="Territory Sales Beat"
        title={`${beat.code} â€” ${beat.name}`}
      />

      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 16 }}>
        <button className="button button--ghost" onClick={() => navigate('/beats')} type="button">
          <ArrowLeft aria-hidden="true" size={16} />
          <span>Back to Beats</span>
        </button>
      </div>

      <div className="summary-strip">
        <div className="metric-cell">
          <span className="metric-label">Beat Code</span>
          <strong className="metric-value">{beat.code}</strong>
        </div>
        <div className="metric-cell">
          <span className="metric-label">Assigned Stops</span>
          <strong className="metric-value">{customers.length}</strong>
        </div>
        <div className="metric-cell">
          <span className="metric-label">Status</span>
          <strong className="metric-value"><StatusChip status={beat.isActive ? 'ACTIVE' : 'INACTIVE'} /></strong>
        </div>
      </div>

      <div className="table-card">
        <div className="card-header" style={{ padding: '16px 20px', borderBottom: '1px solid var(--k-color-border)' }}>
          <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 600 }}>Scheduled Customer Stops</h3>
        </div>

        {customers.length === 0 ? (
          <div className="directory-state">
            <Users aria-hidden="true" size={32} />
            <p>No customers assigned to this beat yet. Add retailer stops in sequence order.</p>
          </div>
        ) : (
          <DataTable caption="Beat Customer Stops">
            <thead>
              <tr>
                <th scope="col" style={{ width: 80 }}>Seq #</th>
                <th scope="col">Customer / Retailer</th>
                <th scope="col">Company</th>
                <th scope="col">Phone / Mobile</th>
                <th scope="col">Visit Frequency</th>
                <th scope="col" style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {customers.map((c: BeatCustomer) => (
                <tr key={c.id}>
                  <td><strong>#{c.visitSequence ?? 1}</strong></td>
                  <td><strong>{c.contactName}</strong></td>
                  <td>{c.companyName || 'â€”'}</td>
                  <td>{c.phone || 'â€”'}</td>
                  <td><StatusChip status={c.visitFrequency || 'WEEKLY'} /></td>
                  <td style={{ textAlign: 'right' }}>
                    <button
                      aria-label={`Remove ${c.contactName}`}
                      className="button button--ghost"
                      onClick={() => {
                        if (window.confirm(`Remove ${c.contactName} from beat?`)) {
                          removeCustomerMutation.mutate(c.contactId)
                        }
                      }}
                      type="button"
                    >
                      <Trash2 aria-hidden="true" size={16} />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </div>

      {isAddCustomerOpen ? (
        <AddCustomerModal
          isPending={addCustomerMutation.isPending}
          nextSequence={customers.length + 1}
          onClose={() => setIsAddCustomerOpen(false)}
          onSubmit={(payload) => addCustomerMutation.mutate(payload)}
        />
      ) : null}
    </section>
  )
}

function AddCustomerModal({
  onClose,
  onSubmit,
  isPending,
  nextSequence,
}: {
  onClose: () => void
  onSubmit: (payload: { contactId: string; visitSequence: number; visitFrequency: string }) => void
  isPending: boolean
  nextSequence: number
}) {
  const [contactId, setContactId] = useState('')
  const [visitSequence, setVisitSequence] = useState(nextSequence)
  const [visitFrequency, setVisitFrequency] = useState('WEEKLY')

  return (
    <Modal
      footer={
        <>
          <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
          <Button
            disabled={isPending || !contactId}
            onClick={() =>
              onSubmit({
                contactId,
                visitSequence,
                visitFrequency,
              })
            }
            variant="primary"
          >
            {isPending ? 'Adding...' : 'Add Customer'}
          </Button>
        </>
      }
      isOpen
      onClose={onClose}
      size="md"
      title="Add Customer Stop to Beat"
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        <FormField label="Select Customer / Contact" required>
          <EntityPicker
            value={contactId || null}
            onChange={(id) => setContactId(id || '')}
            onSearch={async (query) => {
              const res = await listContacts({ search: query, size: 20 })
              return res.content
            }}
            getOptionId={(c) => c.id}
            getOptionLabel={(c) => c.displayName || c.companyName || c.name || 'Unknown Contact'}
            getOptionDescription={(c) => [c.phone, c.companyName].filter(Boolean).join(' • ') || undefined}
            getOptionBadge={(c) => c.contactType || undefined}
            placeholder="Search customer by name, business or phone..."
          />
        </FormField>

        <FormField label="Visit Sequence Order">
          <NumberInput
            min={1}
            onChange={(e) => setVisitSequence(Number(e.target.value))}
            value={visitSequence}
          />
        </FormField>

        <FormField label="Visit Frequency">
          <SelectInput
            onChange={(e) => setVisitFrequency(e.target.value)}
            value={visitFrequency}
          >
            <option value="DAILY">Daily</option>
            <option value="WEEKLY">Weekly</option>
            <option value="BIWEEKLY">Bi-Weekly</option>
            <option value="FORTNIGHTLY">Fortnightly</option>
            <option value="MONTHLY">Monthly</option>
          </SelectInput>
        </FormField>
      </div>
    </Modal>
  )
}

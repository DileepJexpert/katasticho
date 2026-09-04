import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import {
  MapPin,
  Plus,
  Search,
  Trash2,
} from 'lucide-react'
import {
  Button,
  DataTable,
  FormField,
  FormGrid,
  Modal,
  PageHeader,
  StatusChip,
  TextAreaInput,
  TextInput,
} from '@/design-system'
import {
  createBeat,
  deleteBeat,
  listBeats,
  type Beat,
} from '@/features/field-sales/field-sales-api'

export function BeatsPage() {
  const [searchTerm, setSearchTerm] = useState('')
  const [isAddOpen, setIsAddOpen] = useState(false)
  const queryClient = useQueryClient()

  const { data: pageData, isLoading, isError } = useQuery({
    queryKey: ['field-sales', 'beats'],
    queryFn: () => listBeats(),
  })

  const beats: Beat[] = pageData?.content ?? []

  const deleteMutation = useMutation({
    mutationFn: deleteBeat,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'beats'] })
    },
  })

  const createMutation = useMutation({
    mutationFn: createBeat,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'beats'] })
      setIsAddOpen(false)
    },
  })

  const filteredBeats = beats.filter(
    (b: Beat) =>
      (b.name || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (b.code || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (b.area && b.area.toLowerCase().includes(searchTerm.toLowerCase()))
  )

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <Button onClick={() => setIsAddOpen(true)} type="button" variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>Create Beat</span>
          </Button>
        }
        description="Territory sales beats, retailer customer stops, and scheduled route lines."
        eyebrow="Field Sales & Territory"
        title="Sales Beats"
      />

      <div className="summary-strip">
        <div className="metric-cell">
          <span className="metric-label">Active Beats</span>
          <strong className="metric-value">{beats.length}</strong>
        </div>
      </div>

      <div className="table-card">
        <div className="search-bar-wrap" style={{ padding: '16px 20px', borderBottom: '1px solid var(--k-color-border)' }}>
          <div className="search-input-group" style={{ display: 'flex', alignItems: 'center', gap: 8, maxWidth: 360 }}>
            <Search aria-hidden="true" size={16} />
            <input
              aria-label="Search beats"
              className="form-input"
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Search by name, code, or area..."
              type="search"
              value={searchTerm}
            />
          </div>
        </div>

        {isLoading ? (
          <div className="directory-state">Loading sales beats...</div>
        ) : isError ? (
          <div className="directory-state directory-state--error">Failed to load sales beats.</div>
        ) : filteredBeats.length === 0 ? (
          <div className="directory-state">
            <MapPin aria-hidden="true" size={32} />
            <p>No sales beats found. Add a beat to organize territory customer visits.</p>
          </div>
        ) : (
          <DataTable caption="Sales Beats Register">
            <thead>
              <tr>
                <th scope="col">Beat Code</th>
                <th scope="col">Beat Name</th>
                <th scope="col">Area / Territory</th>
                <th scope="col">City / State</th>
                <th scope="col">Status</th>
                <th scope="col" style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredBeats.map((beat: Beat) => (
                <tr key={beat.id}>
                  <td>
                    <Link className="table-link" to={`/beats/${beat.id}`}>
                      <strong>{beat.code}</strong>
                    </Link>
                  </td>
                  <td>{beat.name}</td>
                  <td>{beat.area || 'â€”'}</td>
                  <td>{[beat.city, beat.state].filter(Boolean).join(', ') || 'â€”'}</td>
                  <td><StatusChip status={beat.isActive ? 'ACTIVE' : 'INACTIVE'} /></td>
                  <td style={{ textAlign: 'right' }}>
                    <button
                      aria-label={`Delete ${beat.name}`}
                      className="button button--ghost"
                      onClick={() => {
                        if (window.confirm(`Delete beat ${beat.name}?`)) {
                          deleteMutation.mutate(beat.id)
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

      {isAddOpen ? (
        <AddBeatModal
          isPending={createMutation.isPending}
          onClose={() => setIsAddOpen(false)}
          onSubmit={(payload) => createMutation.mutate(payload)}
        />
      ) : null}
    </section>
  )
}

function AddBeatModal({
  onClose,
  onSubmit,
  isPending,
}: {
  onClose: () => void
  onSubmit: (payload: { code: string; name: string; area?: string; city?: string; state?: string; description?: string }) => void
  isPending: boolean
}) {
  const [code, setCode] = useState('')
  const [name, setName] = useState('')
  const [area, setArea] = useState('')
  const [city, setCity] = useState('')
  const [state, setState] = useState('')
  const [description, setDescription] = useState('')

  return (
    <Modal
      footer={
        <>
          <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
          <Button
            disabled={isPending || !code || !name}
            onClick={() =>
              onSubmit({
                code,
                name,
                area: area || undefined,
                city: city || undefined,
                state: state || undefined,
                description: description || undefined,
              })
            }
            variant="primary"
          >
            {isPending ? 'Saving...' : 'Create Beat'}
          </Button>
        </>
      }
      isOpen
      onClose={onClose}
      size="md"
      title="Create Sales Beat"
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        <FormField label="Beat Code" required>
          <TextInput
            onChange={(e) => setCode(e.target.value)}
            placeholder="e.g. BT-NORTH-01"
            required
            value={code}
          />
        </FormField>

        <FormField label="Beat Name" required>
          <TextInput
            onChange={(e) => setName(e.target.value)}
            placeholder="e.g. MG Road Chemist Hub"
            required
            value={name}
          />
        </FormField>

        <FormGrid columns={2}>
          <FormField label="Area / Territory">
            <TextInput
              onChange={(e) => setArea(e.target.value)}
              placeholder="e.g. Central Market"
              value={area}
            />
          </FormField>
          <FormField label="City">
            <TextInput
              onChange={(e) => setCity(e.target.value)}
              placeholder="e.g. Mumbai"
              value={city}
            />
          </FormField>
        </FormGrid>

        <FormField label="State">
          <TextInput
            onChange={(e) => setState(e.target.value)}
            placeholder="e.g. Maharashtra"
            value={state}
          />
        </FormField>

        <FormField label="Description (Optional)">
          <TextAreaInput
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Notes on schedule, major landmarks..."
            rows={2}
            value={description}
          />
        </FormField>
      </div>
    </Modal>
  )
}

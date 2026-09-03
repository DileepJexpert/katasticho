import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ChevronLeft,
  ChevronRight,
  Eye,
  Plus,
  Presentation,
  X,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import {
  createDetailAid,
  listDetailAids,
  type DetailAid,
} from '@/features/field-sales/field-sales-api'

export function DetailAidsPage() {
  const [isAddOpen, setIsAddOpen] = useState(false)
  const [activeAid, setActiveAid] = useState<DetailAid | null>(null)
  const queryClient = useQueryClient()

  const { data: aids = [], isLoading, isError } = useQuery({
    queryKey: ['mr', 'detail-aids'],
    queryFn: () => listDetailAids(),
  })

  const createMutation = useMutation({
    mutationFn: createDetailAid,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mr', 'detail-aids'] })
      setIsAddOpen(false)
    },
  })

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <Button onClick={() => setIsAddOpen(true)} type="button" variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>Upload Visual Aid</span>
          </Button>
        }
        description="Interactive e-Detailing presentation aids, clinical trial slides, and doctor digital flipbooks."
        eyebrow="E-Detailing & Visual Aids"
        title="Visual Detailing Aids"
      />

      <div className="summary-strip">
        <div className="metric-cell">
          <span className="metric-label">Active Visual Aids</span>
          <strong className="metric-value">{aids.length}</strong>
        </div>
      </div>

      <div className="table-card">
        {isLoading ? (
          <div className="directory-state">Loading visual aids...</div>
        ) : isError ? (
          <div className="directory-state directory-state--error">Failed to load visual aids.</div>
        ) : aids.length === 0 ? (
          <div className="directory-state">
            <Presentation aria-hidden="true" size={32} />
            <p>No visual detailing aids uploaded. Create a digital flipbook for field doctor detailing.</p>
          </div>
        ) : (
          <DataTable caption="Visual Detailing Aids Library">
            <thead>
              <tr>
                <th scope="col">Title & Presentation</th>
                <th scope="col">Product Brand</th>
                <th scope="col">Specialty Target</th>
                <th scope="col" style={{ textAlign: 'right' }}>Total Slides</th>
                <th scope="col">Status</th>
                <th scope="col" style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {aids.map((a: DetailAid) => (
                <tr key={a.id}>
                  <td><strong>{a.name}</strong></td>
                  <td>{a.productName}</td>
                  <td>{a.specialtyTarget || 'General Physician'}</td>
                  <td style={{ textAlign: 'right' }}>{a.slideCount ?? 1}</td>
                  <td><StatusChip status={a.active ? 'ACTIVE' : 'INACTIVE'} /></td>
                  <td style={{ textAlign: 'right' }}>
                    <Button onClick={() => setActiveAid(a)} type="button" variant="secondary">
                      <Eye aria-hidden="true" size={14} />
                      <span>Present (e-Detail)</span>
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </div>

      {isAddOpen ? (
        <CreateAidModal
          isPending={createMutation.isPending}
          onClose={() => setIsAddOpen(false)}
          onSubmit={(payload) => createMutation.mutate(payload)}
        />
      ) : null}

      {activeAid ? (
        <DetailingPresenterModal
          aid={activeAid}
          onClose={() => setActiveAid(null)}
        />
      ) : null}
    </section>
  )
}

function DetailingPresenterModal({
  aid,
  onClose,
}: {
  aid: DetailAid
  onClose: () => void
}) {
  const [currentSlide, setCurrentSlide] = useState(1)
  const maxSlides = aid.slideCount || 4

  return (
    <div className="modal-backdrop" style={{ zIndex: 1200 }}>
      <div className="modal-card" style={{ maxWidth: 840, width: '90vw', height: '80vh', display: 'flex', flexDirection: 'column' }}>
        <div className="modal-header">
          <div>
            <h2 className="modal-title">{aid.name}</h2>
            <span style={{ fontSize: '0.85rem', color: 'var(--k-color-text-muted)' }}>
              Target: {aid.specialtyTarget || 'General'} | Product: {aid.productName}
            </span>
          </div>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--k-color-surface-hover)', borderRadius: 8, margin: '16px 20px', padding: 24, border: '1px solid var(--k-color-border)', flexDirection: 'column', gap: 16 }}>
          <div style={{ textAlign: 'center' }}>
            <span style={{ fontSize: '0.8rem', fontWeight: 700, letterSpacing: 1, textTransform: 'uppercase', color: 'var(--k-color-brand)' }}>
              Slide {currentSlide} of {maxSlides}
            </span>
            <h3 style={{ fontSize: '1.4rem', margin: '8px 0' }}>Clinical Efficacy & Pharmacokinetics</h3>
            <p style={{ maxWidth: 540, margin: '0 auto', color: 'var(--k-color-text-muted)' }}>
              Superior 24-hour BP control demonstrated in multi-center Phase III comparative trials with 94% patient compliance.
            </p>
          </div>
        </div>

        <div className="modal-footer" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ display: 'flex', gap: 8 }}>
            <Button
              disabled={currentSlide <= 1}
              onClick={() => setCurrentSlide((s) => Math.max(1, s - 1))}
              type="button"
              variant="secondary"
            >
              <ChevronLeft aria-hidden="true" size={16} />
              <span>Previous Slide</span>
            </Button>
            <Button
              disabled={currentSlide >= maxSlides}
              onClick={() => setCurrentSlide((s) => Math.min(maxSlides, s + 1))}
              type="button"
              variant="secondary"
            >
              <span>Next Slide</span>
              <ChevronRight aria-hidden="true" size={16} />
            </Button>
          </div>
          <Button onClick={onClose} type="button" variant="primary">
            <span>Finish Presentation</span>
          </Button>
        </div>
      </div>
    </div>
  )
}

function CreateAidModal({
  onClose,
  onSubmit,
  isPending,
}: {
  onClose: () => void
  onSubmit: (payload: { name: string; productName: string; specialtyTarget?: string; slideCount: number }) => void
  isPending: boolean
}) {
  const [name, setName] = useState('')
  const [productName, setProductName] = useState('')
  const [specialtyTarget, setSpecialtyTarget] = useState('Cardiology')
  const [slideCount, setSlideCount] = useState(6)

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 440 }}>
        <div className="modal-header">
          <h2 className="modal-title">Upload Visual Detailing Aid</h2>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            onSubmit({
              name,
              productName,
              specialtyTarget: specialtyTarget || undefined,
              slideCount,
            })
          }}
        >
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div className="form-field">
              <label className="form-label" htmlFor="aid-title">Aid Name *</label>
              <input
                className="form-input"
                id="aid-title"
                onChange={(e) => setName(e.target.value)}
                placeholder="Cardio Care Clinical Monograph"
                required
                value={name}
              />
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div className="form-field">
                <label className="form-label" htmlFor="aid-prod">Product Brand *</label>
                <input
                  className="form-input"
                  id="aid-prod"
                  onChange={(e) => setProductName(e.target.value)}
                  placeholder="Telmi-40"
                  required
                  value={productName}
                />
              </div>

              <div className="form-field">
                <label className="form-label" htmlFor="aid-spec">Target Specialty</label>
                <input
                  className="form-input"
                  id="aid-spec"
                  onChange={(e) => setSpecialtyTarget(e.target.value)}
                  placeholder="Cardiologist"
                  value={specialtyTarget}
                />
              </div>
            </div>

            <div className="form-field">
              <label className="form-label" htmlFor="aid-slides">Slide Count</label>
              <input
                className="form-input"
                id="aid-slides"
                min={1}
                onChange={(e) => setSlideCount(parseInt(e.target.value, 10) || 1)}
                type="number"
                value={slideCount}
              />
            </div>
          </div>

          <div className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending || !name || !productName} type="submit" variant="primary">
              {isPending ? 'Saving...' : 'Upload Aid'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}

import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  Plus,
  Trash2,
  CheckCircle2,
  Tag,
  } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import {
  listFranchiseNodes,
  listBranchPriceOverrides,
  saveBranchPriceOverride,
  deleteBranchPriceOverride,
} from '@/features/franchise/franchise-api'
import { listItems } from '@/features/items/items-api'

export function FranchiseNodeDetailPage() {
  const { nodeId = '' } = useParams<{ nodeId: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [feedback, setFeedback] = useState<string | null>(null)

  const [isAddOverrideOpen, setIsAddOverrideOpen] = useState(false)
  const [selectedItemId, setSelectedItemId] = useState('')
  const [overridePrice, setOverridePrice] = useState('')
  const [overrideReason, setOverrideReason] = useState('Local market competition')

  const nodesQuery = useQuery({
    queryKey: ['franchise-nodes'],
    queryFn: () => listFranchiseNodes(),
  })

  const overridesQuery = useQuery({
    queryKey: ['franchise-price-overrides', nodeId],
    queryFn: () => listBranchPriceOverrides(nodeId),
    enabled: Boolean(nodeId),
  })

  const itemsQuery = useQuery({
    queryKey: ['items-dropdown'],
    queryFn: () => listItems({ page: 0 }),
  })

  const saveOverrideMutation = useMutation({
    mutationFn: () => saveBranchPriceOverride({
      branchId: nodeId,
      itemId: selectedItemId,
      overrideSellingPrice: Number(overridePrice),
      reason: overrideReason,
    }),
    onSuccess: () => {
      setIsAddOverrideOpen(false)
      setSelectedItemId('')
      setOverridePrice('')
      queryClient.invalidateQueries({ queryKey: ['franchise-price-overrides', nodeId] })
      setFeedback('Branch price override saved.')
    },
  })

  const deleteOverrideMutation = useMutation({
    mutationFn: (id: string) => deleteBranchPriceOverride(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['franchise-price-overrides', nodeId] })
      setFeedback('Price override removed. Standard master catalog price restored.')
    },
  })

  const nodes = nodesQuery.data ?? []
  const node = nodes.find((n) => n.id === nodeId)
  const overrides = overridesQuery.data ?? []
  const items = itemsQuery.data?.content ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Franchise / Branch Management"
        title={node ? `${node.name} (${node.nodeCode})` : 'Franchise Store'}
        description={`Model: ${node?.nodeType || 'FOFO'} · City: ${node?.city || '—'} · Royalty: ${node?.royaltyPercentage ?? 5}%`}
        actions={
          <div className="table-actions">
            <Button onClick={() => setIsAddOverrideOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Add Price Override
            </Button>
          </div>
        }
      />

      {feedback && (
        <div className="feedback-alert feedback-alert--success" role="status">
          <CheckCircle2 size={16} />
          <span>{feedback}</span>
          <button className="feedback-alert__close" onClick={() => setFeedback(null)} type="button">×</button>
        </div>
      )}

      <div className="document-actions">
        <Button onClick={() => navigate('/franchise')} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to Franchise Stores
        </Button>
      </div>

      <section className="document-card" style={{ marginTop: '16px' }}>
        <h2>Branch Local Price Overrides ({overrides.length})</h2>
        <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginBottom: '16px' }}>
          Items configured here will sell at this store at the custom override price instead of the global master catalog price.
        </p>

        {overridesQuery.isLoading ? (
          <div className="directory-state">Loading price overrides...</div>
        ) : overrides.length === 0 ? (
          <div className="directory-state">
            <Tag size={24} />
            <strong>No local price overrides for this store. Standard catalog pricing applies.</strong>
          </div>
        ) : (
          <DataTable caption="Price overrides">
            <thead>
              <tr>
                <th scope="col">Item SKU / Name</th>
                <th className="numeric-cell" scope="col">Standard Selling Price</th>
                <th className="numeric-cell" scope="col">Store Override Price</th>
                <th scope="col">Reason</th>
                <th scope="col">Action</th>
              </tr>
            </thead>
            <tbody>
              {overrides.map((ov) => (
                <tr key={ov.id}>
                  <td><strong>{ov.itemName || ov.itemId}</strong></td>
                  <td className="numeric-cell"><Money amount={ov.standardSellingPrice} /></td>
                  <td className="numeric-cell" style={{ fontWeight: 600, color: 'var(--color-primary)' }}>
                    <Money amount={ov.overrideSellingPrice} />
                  </td>
                  <td>{ov.reason || '—'}</td>
                  <td>
                    <Button
                      disabled={deleteOverrideMutation.isPending}
                      onClick={() => deleteOverrideMutation.mutate(ov.id)}
                      variant="destructive"
                    >
                      <Trash2 size={14} />
                      Remove Override
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </section>

      {/* Add Price Override Modal */}
      <Modal
        footer={
          <>
            <Button onClick={() => setIsAddOverrideOpen(false)} variant="secondary">Cancel</Button>
            <Button
              disabled={saveOverrideMutation.isPending || !selectedItemId || !overridePrice}
              onClick={() => saveOverrideMutation.mutate()}
              variant="primary"
            >
              {saveOverrideMutation.isPending ? 'Saving...' : 'Save Override'}
            </Button>
          </>
        }
        isOpen={isAddOverrideOpen}
        onClose={() => setIsAddOverrideOpen(false)}
        size="md"
        title="Add Local Price Override"
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <FormField label="Select Catalog Item" required>
            <SelectInput
              onChange={(e) => {
                setSelectedItemId(e.target.value)
                const it = items.find((i) => i.id === e.target.value)
                if (it) setOverridePrice(String(it.sellingPrice))
              }}
              value={selectedItemId}
            >
              <option value="">Select Item from Master Catalog</option>
              {items.map((it) => (
                <option key={it.id} value={it.id}>
                  {it.sku ? `[${it.sku}] ` : ''}{it.name} (Std: ₹{it.sellingPrice})
                </option>
              ))}
            </SelectInput>
          </FormField>

          <FormField label="Custom Store Selling Price (₹)" required>
            <NumberInput
              min={0}
              onChange={(e) => setOverridePrice(e.target.value)}
              step="0.01"
              value={overridePrice}
            />
          </FormField>

          <FormField label="Reason for Override">
            <TextInput
              onChange={(e) => setOverrideReason(e.target.value)}
              placeholder="e.g. Higher airport rent, local festival promo"
              value={overrideReason}
            />
          </FormField>
        </div>
      </Modal>
    </section>
  )
}

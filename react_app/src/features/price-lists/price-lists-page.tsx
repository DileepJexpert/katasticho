import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Plus, Tag } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import {
  createPriceList,
  listPriceLists,
  type CreatePriceListRequest,
  type PriceList,
} from '@/features/price-lists/price-lists-api'

export function PriceListsPage() {
  const [showCreateModal, setShowCreateModal] = useState(false)
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const priceLists = useQuery({
    queryKey: ['price-lists'],
    queryFn: listPriceLists,
  })

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Sales / Pricing"
        title="Price Lists & Tier Schemes"
        description="Customer tier pricing, volume slab discounts, and promotional markup price lists."
        actions={
          <Button onClick={() => setShowCreateModal(true)} variant="primary">
            <Plus size={16} /> Create Price List
          </Button>
        }
      />

      <section className="list-panel" aria-label="Price list directory">
        {priceLists.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Price lists could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : priceLists.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading price lists...</div>
        ) : priceLists.data?.length ? (
          <DataTable caption="Price lists">
            <thead>
              <tr>
                <th scope="col">Price list</th>
                <th scope="col">Scheme type</th>
                <th scope="col">Currency</th>
                <th className="numeric-cell" scope="col">Custom rules</th>
                <th scope="col">Default</th>
                <th scope="col">Status</th>
                <th scope="col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {priceLists.data.map((list) => (
                <PriceListRow
                  key={list.id}
                  onOpen={() => navigate(appRoutes.priceListDetail ? appRoutes.priceListDetail(list.id) : `/price-lists/${list.id}`)}
                  priceList={list}
                />
              ))}
            </tbody>
          </DataTable>
        ) : (
          <div className="directory-state">
            <Tag aria-hidden="true" size={24} />
            <strong>No price lists configured.</strong>
            <p>Create wholesale, distributor, or seasonal price lists to override base item pricing.</p>
          </div>
        )}
      </section>

      {/* Create Modal */}
      {showCreateModal && (
        <CreatePriceListModal
          onClose={() => setShowCreateModal(false)}
          onSuccess={(id) => {
            setShowCreateModal(false)
            queryClient.invalidateQueries({ queryKey: ['price-lists'] })
            navigate(appRoutes.priceListDetail ? appRoutes.priceListDetail(id) : `/price-lists/${id}`)
          }}
        />
      )}
    </section>
  )
}

function PriceListRow({ onOpen, priceList }: { onOpen: () => void; priceList: PriceList }) {
  return (
    <tr onClick={onOpen} style={{ cursor: 'pointer' }}>
      <td>
        <div className="item-primary">
          <span aria-hidden="true" className="item-avatar"><Tag size={15} /></span>
          <div className="cell-stack">
            <strong>{priceList.name}</strong>
            <code>{priceList.code}</code>
          </div>
        </div>
      </td>
      <td>{priceList.schemeType}</td>
      <td>{priceList.currency}</td>
      <td className="numeric-cell"><strong>{priceList.itemCount} items</strong></td>
      <td><StatusChip status={priceList.isDefault ? 'Default' : 'Standard'} /></td>
      <td><StatusChip status={priceList.active ? 'Active' : 'Inactive'} /></td>
      <td>
        <Button onClick={(e) => { e.stopPropagation(); onOpen() }} variant="ghost">
          Configure Rules
        </Button>
      </td>
    </tr>
  )
}

function CreatePriceListModal({ onClose, onSuccess }: { onClose: () => void; onSuccess: (id: string) => void }) {
  const [code, setCode] = useState('')
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [currency, setCurrency] = useState('INR')
  const [schemeType, setSchemeType] = useState('PERCENTAGE_DISCOUNT')
  const [isDefault, setIsDefault] = useState(false)

  const mutation = useMutation({
    mutationFn: () => {
      const payload: CreatePriceListRequest = {
        code,
        name,
        description: description || undefined,
        currency,
        schemeType,
        isDefault,
      }
      return createPriceList(payload)
    },
    onSuccess: (res) => onSuccess(res.id),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog">
        <header className="modal-header">
          <h3>Create Price List</h3>
          <Button onClick={onClose} variant="ghost">✕</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: '1rem' }}>
            <label className="field-group">
              <span>Code *</span>
              <input onChange={(e) => setCode(e.target.value)} placeholder="e.g. PL-WHOLESALE" value={code} />
            </label>
            <label className="field-group">
              <span>Name *</span>
              <input onChange={(e) => setName(e.target.value)} placeholder="e.g. Wholesale Tier A" value={name} />
            </label>
          </div>
          <label className="field-group">
            <span>Description</span>
            <input onChange={(e) => setDescription(e.target.value)} placeholder="15% off standard prices for tier A distributors" value={description} />
          </label>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
            <label className="field-group">
              <span>Pricing Scheme</span>
              <select onChange={(e) => setSchemeType(e.target.value)} value={schemeType}>
                <option value="PERCENTAGE_DISCOUNT">Percentage Discount</option>
                <option value="FIXED_PRICE">Fixed Item Prices</option>
                <option value="MARKUP">Cost Markup</option>
              </select>
            </label>
            <label className="field-group">
              <span>Currency</span>
              <input onChange={(e) => setCurrency(e.target.value)} value={currency} />
            </label>
          </div>
          <label style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <input checked={isDefault} onChange={(e) => setIsDefault(e.target.checked)} type="checkbox" />
            <span>Set as Default Price List</span>
          </label>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={!code || !name || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Creating...' : 'Create Price List'}
          </Button>
        </footer>
      </div>
    </div>
  )
}
import { useState } from 'react'
import type { ReactNode } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  DollarSign,
  Plus,
  Trash2,
  Users,
} from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import {
  addPriceListContact,
  addPriceListItem,
  getPriceList,
  getPriceListContacts,
  getPriceListItems,
  removePriceListContact,
  removePriceListItem,
  type PriceListContact,
  type PriceListItem,
} from '@/features/price-lists/price-lists-api'
import { listItems, type Item } from '@/features/items/items-api'
import { listContacts, type Contact } from '@/features/contacts/contacts-api'

export function PriceListDetailPage() {
  const { priceListId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<'ITEMS' | 'CONTACTS'>('ITEMS')
  const [showAddItemModal, setShowAddItemModal] = useState(false)
  const [showAddContactModal, setShowAddContactModal] = useState(false)

  const priceListQuery = useQuery({
    queryKey: ['price-lists', priceListId],
    queryFn: () => getPriceList(priceListId!),
    enabled: Boolean(priceListId),
  })

  const itemsQuery = useQuery({
    queryKey: ['price-list-items', priceListId],
    queryFn: () => getPriceListItems(priceListId!),
    enabled: Boolean(priceListId) && activeTab === 'ITEMS',
  })

  const contactsQuery = useQuery({
    queryKey: ['price-list-contacts', priceListId],
    queryFn: () => getPriceListContacts(priceListId!),
    enabled: Boolean(priceListId) && activeTab === 'CONTACTS',
  })

  const removeItemMutation = useMutation({
    mutationFn: (itemId: string) => removePriceListItem(priceListId!, itemId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['price-list-items', priceListId] }),
  })

  const removeContactMutation = useMutation({
    mutationFn: (contactId: string) => removePriceListContact(priceListId!, contactId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['price-list-contacts', priceListId] }),
  })

  if (!priceListId) return <DocumentError onBack={() => navigate(appRoutes.priceLists)} />
  if (priceListQuery.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading price list...</div></section>
  if (priceListQuery.isError || !priceListQuery.data) return <DocumentError onBack={() => navigate(appRoutes.priceLists)} />

  const priceList = priceListQuery.data
  const items = itemsQuery.data ?? []
  const contacts = contactsQuery.data ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <Button onClick={() => navigate(appRoutes.priceLists)} variant="secondary">
              <ArrowLeft className="icon" /> Back to Price Lists
            </Button>
            {activeTab === 'ITEMS' ? (
              <Button onClick={() => setShowAddItemModal(true)} variant="primary">
                <Plus className="icon" /> Add Item Rule
              </Button>
            ) : (
              <Button onClick={() => setShowAddContactModal(true)} variant="primary">
                <Plus className="icon" /> Assign Customer
              </Button>
            )}
          </div>
        }
        description={`Scheme: ${priceList.schemeType} Â· Currency: ${priceList.currency}`}
        eyebrow="Inventory / Pricing & Tier Schemes"
        title={priceList.name}
      />

      <div className="document-facts-grid" style={{ marginBottom: '1.5rem' }}>
        <Fact label="Code" value={<strong>{priceList.code}</strong>} />
        <Fact label="Scheme Type" value={<StatusChip status={priceList.schemeType} />} />
        <Fact label="Currency" value={priceList.currency} />
        <Fact label="Default Tier" value={priceList.isDefault ? 'Yes (System Default)' : 'No'} />
        <Fact label="Status" value={<StatusChip status={priceList.active ? 'ACTIVE' : 'INACTIVE'} />} />
      </div>

      <div style={{ display: 'flex', gap: '0.5rem', borderBottom: '1px solid var(--color-border)', marginBottom: '1rem' }}>
        <button
          className={`tab-btn ${activeTab === 'ITEMS' ? 'active' : ''}`}
          onClick={() => setActiveTab('ITEMS')}
          style={{ padding: '0.5rem 1rem', background: 'none', border: 'none', borderBottom: activeTab === 'ITEMS' ? '2px solid var(--color-primary)' : 'none', cursor: 'pointer', fontWeight: activeTab === 'ITEMS' ? 600 : 400 }}
          type="button"
        >
          <DollarSign className="icon" style={{ marginRight: '4px', verticalAlign: 'middle' }} /> Item Pricing Rules ({items.length})
        </button>
        <button
          className={`tab-btn ${activeTab === 'CONTACTS' ? 'active' : ''}`}
          onClick={() => setActiveTab('CONTACTS')}
          style={{ padding: '0.5rem 1rem', background: 'none', border: 'none', borderBottom: activeTab === 'CONTACTS' ? '2px solid var(--color-primary)' : 'none', cursor: 'pointer', fontWeight: activeTab === 'CONTACTS' ? 600 : 400 }}
          type="button"
        >
          <Users className="icon" style={{ marginRight: '4px', verticalAlign: 'middle' }} /> Assigned Customers ({contacts.length})
        </button>
      </div>

      {activeTab === 'ITEMS' && (
        items.length > 0 ? (
          <DataTable caption="Item Pricing Rules">
            <thead>
              <tr>
                <th scope="col">Item</th>
                <th className="numeric-cell" scope="col">Custom Price</th>
                <th className="numeric-cell" scope="col">Discount %</th>
                <th className="numeric-cell" scope="col">Min Quantity</th>
                <th scope="col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {items.map((row: PriceListItem) => (
                <tr key={row.id || row.itemId}>
                  <td>
                    <div>
                      <strong>{row.itemName}</strong>
                      {row.itemSku && <div style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>SKU: {row.itemSku}</div>}
                    </div>
                  </td>
                  <td className="numeric-cell">
                    {row.customPrice != null ? <Money amount={Number(row.customPrice)} /> : 'â€”'}
                  </td>
                  <td className="numeric-cell">
                    {row.discountPercentage != null ? `${row.discountPercentage}%` : 'â€”'}
                  </td>
                  <td className="numeric-cell">{row.minQuantity ?? 1}</td>
                  <td>
                    <Button
                      disabled={removeItemMutation.isPending}
                      onClick={() => removeItemMutation.mutate(row.itemId)}
                      variant="destructive"
                    >
                      <Trash2 className="icon" /> Remove
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <div className="directory-state">
            No custom pricing rules defined for this price list. Base catalog prices apply.
          </div>
        )
      )}

      {activeTab === 'CONTACTS' && (
        contacts.length > 0 ? (
          <DataTable caption="Assigned Customers">
            <thead>
              <tr>
                <th scope="col">Customer / Tier Contact</th>
                <th scope="col">Phone</th>
                <th scope="col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {contacts.map((row: PriceListContact) => (
                <tr key={row.id || row.contactId}>
                  <td>
                    <div>
                      <strong>{row.contactName}</strong>
                      {row.email && <div style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>{row.email}</div>}
                    </div>
                  </td>
                  <td>{row.phone ?? 'â€”'}</td>
                  <td>
                    <Button
                      disabled={removeContactMutation.isPending}
                      onClick={() => removeContactMutation.mutate(row.contactId)}
                      variant="destructive"
                    >
                      <Trash2 className="icon" /> Remove
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <div className="directory-state">
            No customers specifically bound to this tier yet.
          </div>
        )
      )}

      {showAddItemModal && (
        <AddPriceListItemModal
          onClose={() => setShowAddItemModal(false)}
          onSuccess={() => {
            setShowAddItemModal(false)
            queryClient.invalidateQueries({ queryKey: ['price-list-items', priceListId] })
          }}
          priceListId={priceListId}
        />
      )}

      {showAddContactModal && (
        <AddPriceListContactModal
          onClose={() => setShowAddContactModal(false)}
          onSuccess={() => {
            setShowAddContactModal(false)
            queryClient.invalidateQueries({ queryKey: ['price-list-contacts', priceListId] })
          }}
          priceListId={priceListId}
        />
      )}
    </section>
  )
}

function AddPriceListItemModal({
  priceListId,
  onClose,
  onSuccess,
}: {
  priceListId: string
  onClose: () => void
  onSuccess: () => void
}) {
  const [itemId, setItemId] = useState('')
  const [customPrice, setCustomPrice] = useState<number | ''>('')
  const [discountPercentage, setDiscountPercentage] = useState<number | ''>('')
  const [minQuantity, setMinQuantity] = useState<number | ''>(1)

  const itemsQuery = useQuery({
    queryKey: ['items-dropdown'],
    queryFn: () => listItems(),
  })

  const mutation = useMutation({
    mutationFn: () =>
      addPriceListItem(priceListId, {
        itemId,
        customPrice: customPrice === '' ? undefined : Number(customPrice),
        discountPercentage: discountPercentage === '' ? undefined : Number(discountPercentage),
        minQuantity: minQuantity === '' ? undefined : Number(minQuantity),
      }),
    onSuccess: () => onSuccess(),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog">
        <header className="modal-header">
          <h3>Add Item Pricing Rule</h3>
          <Button onClick={onClose} variant="ghost">âœ•</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <label className="field-group">
            <span>Select Product / Item</span>
            <select onChange={(e) => setItemId(e.target.value)} value={itemId}>
              <option value="">-- Choose Item --</option>
              {itemsQuery.data?.content?.map((item: Item) => (
                <option key={item.id} value={item.id}>
                  {item.name} ({item.sku ?? 'No SKU'})
                </option>
              ))}
            </select>
          </label>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
            <label className="field-group">
              <span>Custom Fixed Price</span>
              <input
                onChange={(e) => setCustomPrice(e.target.value === '' ? '' : Number(e.target.value))}
                placeholder="Leave blank for % discount"
                type="number"
                value={customPrice}
              />
            </label>
            <label className="field-group">
              <span>Discount Percentage (%)</span>
              <input
                onChange={(e) => setDiscountPercentage(e.target.value === '' ? '' : Number(e.target.value))}
                placeholder="e.g. 15"
                type="number"
                value={discountPercentage}
              />
            </label>
          </div>

          <label className="field-group">
            <span>Minimum Order Quantity for Scheme</span>
            <input
              min={1}
              onChange={(e) => setMinQuantity(e.target.value === '' ? '' : Number(e.target.value))}
              type="number"
              value={minQuantity}
            />
          </label>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={!itemId || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Saving...' : 'Add Pricing Rule'}
          </Button>
        </footer>
      </div>
    </div>
  )
}

function AddPriceListContactModal({
  priceListId,
  onClose,
  onSuccess,
}: {
  priceListId: string
  onClose: () => void
  onSuccess: () => void
}) {
  const [contactId, setContactId] = useState('')

  const contactsQuery = useQuery({
    queryKey: ['contacts-dropdown'],
    queryFn: () => listContacts(),
  })

  const mutation = useMutation({
    mutationFn: () => addPriceListContact(priceListId, contactId),
    onSuccess: () => onSuccess(),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog">
        <header className="modal-header">
          <h3>Assign Customer to Price Tier</h3>
          <Button onClick={onClose} variant="ghost">âœ•</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <label className="field-group">
            <span>Select Customer / Contact</span>
            <select onChange={(e) => setContactId(e.target.value)} value={contactId}>
              <option value="">-- Choose Contact --</option>
              {contactsQuery.data?.content?.map((c: Contact) => (
                <option key={c.id} value={c.id}>
                  {c.displayName} ({c.contactType ?? 'CUSTOMER'})
                </option>
              ))}
            </select>
          </label>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={!contactId || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Assigning...' : 'Assign Customer'}
          </Button>
        </footer>
      </div>
    </div>
  )
}

function Fact({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="document-fact">
      <dt>{label}</dt>
      <dd>{value}</dd>
    </div>
  )
}

function DocumentError({ onBack }: { onBack: () => void }) {
  return (
    <section className="workspace-page">
      <div className="directory-state">
        <p>Price List not found or failed to load.</p>
        <Button onClick={onBack} variant="secondary">
          <ArrowLeft className="icon" /> Back to Price Lists
        </Button>
      </div>
    </section>
  )
}

import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { AlertTriangle, ArrowLeft, Tag, Users, type LucideIcon } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button, DataTable, DocumentCard, Fact, FactList, FilterTabs, Money, PageHeader, Quantity, StatusChip } from '@/design-system'
import {
  getPriceList,
  listPriceListCustomers,
  listPriceListItems,
  type PriceList,
  type PriceListCustomer,
  type PriceListItem,
} from '@/features/price-lists/price-lists-api'
import { formatDateTime, formatStatusLabel } from '@/shared/format/format'

type PriceListTab = 'overview' | 'tiers' | 'customers'

export function PriceListDetailPage() {
  const { priceListId } = useParams()
  const navigate = useNavigate()
  const [activeTab, setActiveTab] = useState<PriceListTab>('overview')
  const priceListQuery = useQuery({
    queryKey: ['price-lists', priceListId],
    queryFn: () => getPriceList(priceListId!),
    enabled: Boolean(priceListId),
  })
  const tiersQuery = useQuery({
    queryKey: ['price-lists', priceListId, 'tiers'],
    queryFn: () => listPriceListItems(priceListId!),
    enabled: Boolean(priceListId) && activeTab === 'tiers',
  })
  const customersQuery = useQuery({
    queryKey: ['price-lists', priceListId, 'customers'],
    queryFn: () => listPriceListCustomers(priceListId!),
    enabled: Boolean(priceListId) && activeTab === 'customers',
  })

  if (!priceListId) return <PriceListState message="No price list ID was specified." />
  if (priceListQuery.isLoading) return <PriceListState message="Loading price list..." />
  if (priceListQuery.isError || !priceListQuery.data) {
    return (
      <section className="workspace-page">
        <div className="directory-state directory-state--error" role="alert">
          <AlertTriangle aria-hidden="true" size={24} />
          <strong>Price list details could not be loaded.</strong>
          <Button onClick={() => navigate(appRoutes.priceLists)} variant="secondary">Back to price lists</Button>
        </div>
      </section>
    )
  }

  const priceList = priceListQuery.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Sales / Price-list review"
        title={priceList.name}
        description={`${priceList.currency ?? 'No currency'} · ${priceList.isDefault ? 'Organisation default' : 'Non-default list'}`}
        actions={<StatusChip status={priceList.active ? 'Active' : 'Inactive'} />}
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.priceLists)} variant="ghost">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to price lists
        </Button>
        <span className="cell-muted">Read-only review. Price-list and customer-assignment changes remain in Flutter during migration.</span>
      </div>

      <FilterTabs
        activeValue={activeTab}
        ariaLabel="Price-list review sections"
        items={[
          { value: 'overview', label: 'Overview' },
          { value: 'tiers', label: 'Item tiers' },
          { value: 'customers', label: 'Assigned customers' },
        ]}
        onChange={(value) => setActiveTab(value as PriceListTab)}
      />

      {activeTab === 'overview' && <PriceListOverview priceList={priceList} />}
      {activeTab === 'tiers' && <TiersTab isError={tiersQuery.isError} isLoading={tiersQuery.isLoading} tiers={tiersQuery.data ?? []} />}
      {activeTab === 'customers' && <CustomersTab customers={customersQuery.data ?? []} isError={customersQuery.isError} isLoading={customersQuery.isLoading} />}
    </section>
  )
}

function PriceListState({ message }: { message: string }) {
  return <section className="workspace-page"><div aria-live="polite" className="directory-state">{message}</div></section>
}

function PriceListOverview({ priceList }: { priceList: PriceList }) {
  return (
    <div className="document-layout">
      <DocumentCard title="Price-list details">
        <FactList>
          <Fact label="Description" value={priceList.description} />
          <Fact label="Currency" mono value={priceList.currency} />
          <Fact label="Organisation default" value={priceList.isDefault ? 'Yes' : 'No'} />
          <Fact label="Status" value={<StatusChip status={priceList.active ? 'Active' : 'Inactive'} />} />
          <Fact label="Created" value={formatDateTime(priceList.createdAt)} />
        </FactList>
      </DocumentCard>
      <DocumentCard title="Pricing resolution" variant="summary">
        <FactList>
          <Fact label="Customer rule" value="Pinned customer list is checked first" />
          <Fact label="Organisation rule" value="Default list is checked next" />
          <Fact label="Fallback" value="Base item sale price applies when no eligible tier exists" />
        </FactList>
      </DocumentCard>
    </div>
  )
}

function TiersTab({ isError, isLoading, tiers }: { isError: boolean; isLoading: boolean; tiers: PriceListItem[] }) {
  if (isLoading) return <PriceListState message="Loading item tiers..." />
  if (isError) return <div className="directory-state directory-state--error" role="alert">Item tiers could not be loaded.</div>
  if (!tiers.length) return <EmptyPriceListTab icon={Tag} message="No item tiers are configured for this price list." />

  return (
    <DocumentCard title="Item tiers" variant="lines">
      <DataTable caption="Price-list item tiers">
        <thead>
          <tr>
            <th scope="col">Item</th>
            <th className="numeric-cell" scope="col">Minimum quantity</th>
            <th className="numeric-cell" scope="col">Unit price</th>
          </tr>
        </thead>
        <tbody>{tiers.map((tier) => (
          <tr key={tier.id}>
            <td><div className="cell-stack"><strong>{tier.itemName ?? 'Unavailable item'}</strong><code>{tier.itemSku ?? tier.itemId}</code></div></td>
            <td className="numeric-cell"><Quantity value={tier.minQuantity} /></td>
            <td className="numeric-cell"><Money amount={tier.price} /></td>
          </tr>
        ))}</tbody>
      </DataTable>
    </DocumentCard>
  )
}

function CustomersTab({ customers, isError, isLoading }: { customers: PriceListCustomer[]; isError: boolean; isLoading: boolean }) {
  if (isLoading) return <PriceListState message="Loading assigned customers..." />
  if (isError) return <div className="directory-state directory-state--error" role="alert">Assigned customers could not be loaded.</div>
  if (!customers.length) return <EmptyPriceListTab icon={Users} message="No customers are assigned to this price list." />

  return (
    <DocumentCard title="Assigned customers" variant="lines">
      <DataTable caption="Customers assigned to this price list">
        <thead>
          <tr>
            <th scope="col">Customer</th>
            <th scope="col">Role</th>
            <th scope="col">Phone</th>
          </tr>
        </thead>
        <tbody>{customers.map((customer) => (
          <tr key={customer.id}>
            <td><strong>{customer.displayName}</strong></td>
            <td>{formatStatusLabel(customer.contactType ?? 'Customer')}</td>
            <td>{customer.phone ?? '--'}</td>
          </tr>
        ))}</tbody>
      </DataTable>
    </DocumentCard>
  )
}

function EmptyPriceListTab({ icon: Icon, message }: { icon: LucideIcon; message: string }) {
  return <div className="directory-state"><Icon aria-hidden="true" size={24} /><span>{message}</span></div>
}

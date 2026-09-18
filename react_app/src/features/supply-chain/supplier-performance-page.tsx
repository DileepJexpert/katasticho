import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Button,
  EntityPicker,
  FormField,
  FormGrid,
  Modal,
  Money,
  PageHeader,
  Quantity,
  TextInput,
} from '@/design-system'
import { listContacts, type Contact } from '@/features/contacts/contacts-api'
import { useSessionStore } from '@/shared/session/session-store'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { LocalDirectory } from '@/shared/workflows/local-directory'
import {
  calculateSupplierPerformance,
  listSupplierRankings,
  planningRoles,
  type SupplierPerformance,
} from './supply-chain-api'

export function SupplierPerformancePage() {
  return <WorkspaceBoundary roles={planningRoles}><Performance /></WorkspaceBoundary>
}

function Performance() {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const client = useQueryClient()
  const query = useQuery({ queryKey: ['supply', orgId, 'performance'], queryFn: listSupplierRankings })
  const [recalcSupplier, setRecalcSupplier] = useState<{ id: string; name: string } | null>(null)
  const [isRecalcOpen, setIsRecalcOpen] = useState(false)

  const openRecalc = (supplier?: { id: string; name: string }) => {
    setRecalcSupplier(supplier ?? null)
    setIsRecalcOpen(true)
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Supply planning"
        title="Supplier performance history"
        description="Review supplier performance scorecards and recalculate order fulfillment and quality rates."
        actions={<Button variant="primary" onClick={() => openRecalc()}>Recalculate performance</Button>}
      />
      <p className="banner">
        Review supplier performance scorecards and recalculate order fulfillment, received vs ordered quantities, and quality acceptance rates across purchase orders and goods receipts.
      </p>
      <QueryFeedback query={query}>
        <LocalDirectory
          rows={query.data ?? []}
          caption="Supplier performance"
          searchText={(p: SupplierPerformance) => `${p.supplierName ?? ''} ${p.periodStart} ${p.periodEnd}`}
          header={
            <tr>
              <th>Supplier</th>
              <th>Period</th>
              <th>Orders</th>
              <th className="numeric-cell">Ordered</th>
              <th className="numeric-cell">Received</th>
              <th className="numeric-cell">Quality (%)</th>
              <th className="numeric-cell">Recorded amount</th>
              <th>Actions</th>
            </tr>
          }
          renderRow={(p: SupplierPerformance) => (
            <tr key={p.id}>
              <td>{p.supplierName ?? 'Supplier name unavailable'}</td>
              <td>{p.periodStart} to {p.periodEnd}</td>
              <td>{p.totalOrders}</td>
              <td className="numeric-cell"><Quantity value={p.totalQtyOrdered} /></td>
              <td className="numeric-cell"><Quantity value={p.totalQtyReceived} /></td>
              <td className="numeric-cell"><Quantity value={p.qualityRate} /></td>
              <td className="numeric-cell"><Money amount={p.totalAmount} /></td>
              <td>
                <Button variant="ghost" onClick={() => openRecalc({ id: p.supplierId, name: p.supplierName ?? '' })}>
                  Recalculate
                </Button>
              </td>
            </tr>
          )}
        />
      </QueryFeedback>
      {isRecalcOpen && (
        <RecalculatePerformanceModal
          initialSupplier={recalcSupplier}
          onClose={() => setIsRecalcOpen(false)}
          onDone={() => {
            setIsRecalcOpen(false)
            void client.invalidateQueries({ queryKey: ['supply', orgId, 'performance'] })
          }}
        />
      )}
    </section>
  )
}

function RecalculatePerformanceModal({
  initialSupplier,
  onClose,
  onDone,
}: {
  initialSupplier: { id: string; name: string } | null
  onClose: () => void
  onDone: () => void
}) {
  const today = new Date().toISOString().slice(0, 10)
  const defaultFrom = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10)

  const [selectedContact, setSelectedContact] = useState<Contact | null>(
    initialSupplier ? ({ id: initialSupplier.id, displayName: initialSupplier.name } as Contact) : null
  )
  const [from, setFrom] = useState(defaultFrom)
  const [to, setTo] = useState(today)

  const recalcMutation = useMutation({
    mutationFn: () => {
      if (!selectedContact) throw new Error('Please select a supplier')
      return calculateSupplierPerformance(selectedContact.id, from, to)
    },
    onSuccess: onDone,
  })

  const valid = !!selectedContact && !!from && !!to && from <= to

  return (
    <Modal
      isOpen
      title="Recalculate supplier performance"
      description="Compute order fulfillment, quality rate, and spend totals for this supplier in the specified period."
      error={recalcMutation.error?.message}
      onClose={() => { if (!recalcMutation.isPending) onClose() }}
      footer={
        <>
          <Button variant="secondary" disabled={recalcMutation.isPending} onClick={onClose}>
            Cancel
          </Button>
          <Button
            variant="primary"
            disabled={!valid || recalcMutation.isPending}
            loading={recalcMutation.isPending}
            onClick={() => recalcMutation.mutate()}
          >
            Calculate performance
          </Button>
        </>
      }
    >
      <FormGrid>
        <FormField label="Supplier" required>
          <EntityPicker<Contact>
            ariaLabel="Search supplier"
            placeholder="Search vendor by name or email..."
            value={selectedContact?.id ?? null}
            selectedEntity={selectedContact}
            onSearch={async (search) => {
              const res = await listContacts({ filter: 'VENDOR', page: 0, search, size: 25 })
              return res.content.filter((c) => c.active)
            }}
            getOptionId={(c) => c.id}
            getOptionLabel={(c) => c.displayName}
            getOptionDescription={(c) => [c.email, c.phone].filter(Boolean).join(' / ')}
            onChange={(_id, c) => setSelectedContact(c ?? null)}
            disabled={recalcMutation.isPending}
          />
        </FormField>
        <FormField label="From date" required>
          <TextInput
            type="date"
            aria-label="From date"
            value={from}
            onChange={(e) => setFrom(e.target.value)}
            disabled={recalcMutation.isPending}
          />
        </FormField>
        <FormField label="To date" required>
          <TextInput
            type="date"
            aria-label="To date"
            value={to}
            min={from}
            onChange={(e) => setTo(e.target.value)}
            disabled={recalcMutation.isPending}
          />
        </FormField>
      </FormGrid>
    </Modal>
  )
}

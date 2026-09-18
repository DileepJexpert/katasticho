import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Button,
  EntityPicker,
  Fact,
  FactList,
  FormCard,
  FormField,
  FormGrid,
  Modal,
  Money,
  NumberInput,
  PageHeader,
  SelectInput,
  StatusChip,
  TextInput,
  TextAreaInput,
} from '@/design-system'
import { useSessionStore } from '@/shared/session/session-store'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { ConfirmedAction } from '@/shared/workflows/confirmed-action'
import { LocalDirectory } from '@/shared/workflows/local-directory'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import {
  listPartners,
  networkRoles,
  networkWriteBlockers,
  partnerAction,
  requestPartnership,
  searchPartnerDirectory,
  type PartnerDirectoryOrg,
  type TradingPartner,
} from './partner-network-api'

export function PartnersPage() {
  return <WorkspaceBoundary roles={networkRoles}><PartnersWorkspace /></WorkspaceBoundary>
}

function PartnersWorkspace() {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const client = useQueryClient()
  const query = useQuery({ queryKey: ['network', orgId, 'partners'], queryFn: listPartners })
  const [selected, setSelected] = useState<TradingPartner | null>(null)
  const [action, setAction] = useState<{ partner: TradingPartner; action: 'approve' | 'reject' | 'suspend' } | null>(null)
  const [isRequestOpen, setIsRequestOpen] = useState(false)
  const name = (p: TradingPartner) => p.buyerOrgId === orgId ? p.sellerOrgName : p.buyerOrgName

  return <section className="workspace-page">
    <PageHeader
      eyebrow="Partner network"
      title="Trading partners"
      description="Review buyer/seller relationships and incoming partnership requests."
      actions={<Button variant="primary" onClick={() => setIsRequestOpen(true)}>Request partnership</Button>}
    />
    <p className="banner">{networkWriteBlockers.request}</p>
    <QueryFeedback query={query}><LocalDirectory rows={query.data ?? []} caption="Trading partners" searchText={(p) => `${p.sellerOrgName} ${p.buyerOrgName} ${p.status}`}
      header={<tr><th>Organisation</th><th>Your role</th><th>Status</th><th className="numeric-cell">Credit limit</th><th>Actions</th></tr>}
      renderRow={(p) => <tr key={p.id}><td><Button variant="ghost" onClick={() => setSelected(p)}>{name(p)}</Button></td><td>{p.buyerOrgId === orgId ? 'Buyer' : 'Seller'}</td><td><StatusChip status={p.status} /></td><td className="numeric-cell">{p.creditLimit == null ? '--' : <Money amount={p.creditLimit} />}</td><td>
        {p.status === 'PENDING' && <>{p.requestedByOrgId !== orgId && <Button variant="ghost" onClick={() => setAction({ partner: p, action: 'approve' })}>Approve {name(p)}</Button>}<Button variant="ghost" onClick={() => setAction({ partner: p, action: 'reject' })}>Reject {name(p)}</Button></>}
        {p.status === 'APPROVED' && <Button variant="ghost" onClick={() => setAction({ partner: p, action: 'suspend' })}>Suspend {name(p)}</Button>}
      </td></tr>} /></QueryFeedback>
    {selected && <FormCard title={name(selected)} headerAction={<Button variant="ghost" onClick={() => setSelected(null)}>Close details</Button>}><FactList><Fact label="Payment terms" value={selected.paymentTerms} /><Fact label="Delivery terms" value={selected.deliveryTerms} /><Fact label="Notes" value={selected.notes} /><Fact label="Approved" value={selected.approvedAt} /></FactList></FormCard>}
    {action && <ConfirmedAction title={`${action.action} partnership`} description={`${action.action} the relationship with ${name(action.partner)}? This changes whether new network orders are allowed.`} destructive={action.action !== 'approve'} run={() => partnerAction(action.partner.id, action.action)} onClose={() => setAction(null)} onDone={() => { setAction(null); setSelected(null); void client.invalidateQueries({ queryKey: ['network', orgId] }) }} />}
    {isRequestOpen && (
      <RequestPartnershipModal
        onClose={() => setIsRequestOpen(false)}
        onDone={() => {
          setIsRequestOpen(false)
          void client.invalidateQueries({ queryKey: ['network', orgId] })
        }}
      />
    )}
  </section>
}

function RequestPartnershipModal({ onClose, onDone }: { onClose: () => void; onDone: () => void }) {
  const [targetOrg, setTargetOrg] = useState<PartnerDirectoryOrg | null>(null)
  const [role, setRole] = useState<'BUYER' | 'SELLER'>('BUYER')
  const [creditLimit, setCreditLimit] = useState<string>('')
  const [paymentTerms, setPaymentTerms] = useState('')
  const [deliveryTerms, setDeliveryTerms] = useState('')
  const [notes, setNotes] = useState('')

  const requestMutation = useMutation({
    mutationFn: () => {
      if (!targetOrg) throw new Error('Please select an organisation')
      return requestPartnership({
        targetOrgId: targetOrg.id,
        role,
        creditLimit: creditLimit ? Number(creditLimit) : null,
        paymentTerms: paymentTerms.trim() || null,
        deliveryTerms: deliveryTerms.trim() || null,
        notes: notes.trim() || null,
      })
    },
    onSuccess: onDone,
  })

  return (
    <Modal
      isOpen
      title="Request partnership"
      description="Search active organisations from the verified directory to initiate a trading relationship."
      error={requestMutation.error?.message}
      onClose={() => { if (!requestMutation.isPending) onClose() }}
      footer={
        <>
          <Button variant="secondary" disabled={requestMutation.isPending} onClick={onClose}>
            Cancel
          </Button>
          <Button
            variant="primary"
            disabled={!targetOrg || requestMutation.isPending}
            loading={requestMutation.isPending}
            onClick={() => requestMutation.mutate()}
          >
            Send request
          </Button>
        </>
      }
    >
      <FormGrid>
        <FormField label="Target organisation" required>
          <EntityPicker<PartnerDirectoryOrg>
            ariaLabel="Search partner directory"
            placeholder="Search organisation name or GSTIN..."
            value={targetOrg?.id ?? null}
            selectedEntity={targetOrg}
            onSearch={searchPartnerDirectory}
            getOptionId={(org) => org.id}
            getOptionLabel={(org) => org.name}
            getOptionDescription={(org) => [org.industry, org.stateCode, org.gstin].filter(Boolean).join(' • ')}
            onChange={(_id, org) => setTargetOrg(org ?? null)}
            disabled={requestMutation.isPending}
          />
        </FormField>
        <FormField label="Our role" required>
          <SelectInput
            aria-label="Select our role"
            value={role}
            onChange={(e) => setRole(e.target.value as 'BUYER' | 'SELLER')}
            disabled={requestMutation.isPending}
          >
            <option value="BUYER">Buyer (we purchase from them)</option>
            <option value="SELLER">Seller (we supply to them)</option>
          </SelectInput>
        </FormField>
        <FormField label="Credit limit (optional)">
          <NumberInput
            aria-label="Credit limit"
            value={creditLimit}
            onChange={(e) => setCreditLimit(e.target.value)}
            placeholder="e.g. 50000"
            disabled={requestMutation.isPending}
          />
        </FormField>
        <FormField label="Payment terms (optional)">
          <TextInput
            aria-label="Payment terms"
            value={paymentTerms}
            onChange={(e) => setPaymentTerms(e.target.value)}
            placeholder="e.g. Net 30 days"
            disabled={requestMutation.isPending}
          />
        </FormField>
        <FormField label="Delivery terms (optional)">
          <TextInput
            aria-label="Delivery terms"
            value={deliveryTerms}
            onChange={(e) => setDeliveryTerms(e.target.value)}
            placeholder="e.g. Door delivery / Ex-works"
            disabled={requestMutation.isPending}
          />
        </FormField>
        <FormField label="Notes (optional)">
          <TextAreaInput
            aria-label="Notes"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="Add internal or relationship notes..."
            disabled={requestMutation.isPending}
          />
        </FormField>
      </FormGrid>
    </Modal>
  )
}

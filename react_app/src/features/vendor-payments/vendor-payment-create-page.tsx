import { useEffect, useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Save } from 'lucide-react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  EntityPicker,
  FormCard,
  FormField,
  FormGrid,
  Money,
  NumberInput,
  PageHeader,
  SelectInput,
  TextAreaInput,
  TextInput,
} from '@/design-system'
import { listAccounts, type Account } from '@/features/accounts/accounts-api'
import { getBill, listBills, type PurchaseBill } from '@/features/bills/bills-api'
import { listContacts, type Contact } from '@/features/contacts/contacts-api'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { recordVendorPayment, type VendorPaymentRequest } from '@/features/vendor-payments/vendor-payments-api'

function isPaidThroughAccount(account: Account) {
  const name = account.name.toLowerCase()
  return account.isActive && (account.subType === 'CURRENT_ASSET' || account.subType === 'BANK' || name.includes('cash') || name.includes('bank'))
}

function isPayableBill(bill: PurchaseBill) {
  return Number(bill.balanceDue) > 0 && !['DRAFT', 'VOID', 'PAID'].includes(bill.status)
}

function roundCurrency(amount: number) {
  return Math.round((amount + Number.EPSILON) * 100) / 100
}

export function VendorPaymentCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [searchParams] = useSearchParams()
  const sourceBillId = searchParams.get('billId')
  const [contactId, setContactId] = useState(searchParams.get('contactId') ?? '')
  const [selectedVendor, setSelectedVendor] = useState<Contact | null>(null)
  const [selectedVendorLabel, setSelectedVendorLabel] = useState('')
  const [paidThrough, setPaidThrough] = useState<Account | null>(null)
  const [paymentDate, setPaymentDate] = useState(() => new Date().toISOString().slice(0, 10))
  const [paymentMode, setPaymentMode] = useState('BANK_TRANSFER')
  const [referenceNumber, setReferenceNumber] = useState('')
  const [tdsAmount, setTdsAmount] = useState(0)
  const [tdsSection, setTdsSection] = useState('')
  const [notes, setNotes] = useState('')
  const [allocations, setAllocations] = useState<Record<string, number>>({})
  // Keep selected bill details across server-paginated result pages so every
  // allocation is included in the one atomic payment request.
  const [allocationBills, setAllocationBills] = useState<Record<string, PurchaseBill>>({})
  const [billPage, setBillPage] = useState(0)
  const [feedback, setFeedback] = useState<string | null>(null)

  const sourceBill = useQuery({
    queryKey: ['bills', sourceBillId, 'payment-source'],
    queryFn: () => getBill(sourceBillId!),
    enabled: Boolean(sourceBillId),
  })
  const accounts = useQuery({ queryKey: ['accounts'], queryFn: listAccounts })
  const bills = useQuery({
    queryKey: ['bills', 'vendor-payment', contactId, billPage],
    queryFn: () => listBills({ vendorId: contactId, page: billPage, size: 25 }),
    enabled: Boolean(contactId),
  })

  useEffect(() => {
    const bill = sourceBill.data
    if (!bill?.contactId) return
    setContactId(bill.contactId)
    setSelectedVendorLabel(bill.vendorName ?? '')
    setAllocations((current) => {
      if (current[bill.id] !== undefined) return current
      const requested = Number(searchParams.get('amount'))
      const amount = requested > 0 ? Math.min(requested, Number(bill.balanceDue) || 0) : Number(bill.balanceDue) || 0
      return { ...current, [bill.id]: amount }
    })
    setAllocationBills((current) => current[bill.id] ? current : { ...current, [bill.id]: bill })
  }, [searchParams, sourceBill.data])

  const payableBills = useMemo(() => {
    const current = (bills.data?.content ?? []).filter(isPayableBill)
    const prefetched = sourceBill.data
    return prefetched && isPayableBill(prefetched) && !current.some((bill) => bill.id === prefetched.id)
      ? [prefetched, ...current]
      : current
  }, [bills.data?.content, sourceBill.data])
  const visibleBills = useMemo(() => {
    const retainedAllocations = Object.values(allocationBills)
    const remainingPayableBills = payableBills.filter((bill) => !allocationBills[bill.id])
    return [...retainedAllocations, ...remainingPayableBills]
  }, [allocationBills, payableBills])
  const allocationTotal = useMemo(
    () => roundCurrency(Object.values(allocations).reduce((total, amount) => total + amount, 0)),
    [allocations],
  )
  const paidThroughAccounts = useMemo(
    () => (accounts.data ?? []).filter(isPaidThroughAccount),
    [accounts.data],
  )

  const paymentMutation = useMutation({
    mutationFn: (request: VendorPaymentRequest) => recordVendorPayment(request),
    onSuccess: (payment) => {
      queryClient.invalidateQueries({ queryKey: ['vendor-payments'] })
      queryClient.invalidateQueries({ queryKey: ['bills'] })
      navigate(appRoutes.vendorPaymentDetail(payment.id))
    },
    onError: (error: Error) => setFeedback(error.message),
  })

  const updateAllocation = (bill: PurchaseBill, value: number) => {
    const amount = roundCurrency(Math.max(0, Math.min(value, Number(bill.balanceDue) || 0)))
    setAllocations((current) => {
      if (amount === 0) {
        const remaining = { ...current }
        delete remaining[bill.id]
        return remaining
      }
      return { ...current, [bill.id]: amount }
    })
    setAllocationBills((current) => {
      if (amount > 0) return { ...current, [bill.id]: bill }
      const remaining = { ...current }
      delete remaining[bill.id]
      return remaining
    })
  }

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault()
    setFeedback(null)
    const paymentAllocations = Object.entries(allocations)
      .filter(([, amountApplied]) => amountApplied > 0)
      .map(([billId, amountApplied]) => ({ billId, amountApplied }))
    if (!contactId) {
      setFeedback('Select the vendor whose bills are being settled.')
      return
    }
    if (!paidThrough) {
      setFeedback('Select the cash or bank ledger account used for this payment.')
      return
    }
    if (!paymentAllocations.length || allocationTotal <= 0) {
      setFeedback('Allocate a positive amount to at least one payable bill.')
      return
    }
    paymentMutation.mutate({
      contactId,
      paymentDate,
      amount: allocationTotal,
      paymentMode,
      paidThroughId: paidThrough.id,
      referenceNumber: referenceNumber.trim() || undefined,
      tdsAmount: tdsAmount || undefined,
      tdsSection: tdsSection.trim() || undefined,
      notes: notes.trim() || undefined,
      allocations: paymentAllocations,
    })
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={appRoutes.vendorPayments}><ArrowLeft size={16} /> Back to vendor payments</Link>
      <PageHeader
        eyebrow="Purchases / Payables"
        title="Record Vendor Payment"
        description="Allocate one bank, cash, or UPI payment across payable bills. The payment amount is the sum of allocations, preventing an AP allocation mismatch."
      />
      {feedback ? <div className="banner banner--error" role="alert">{feedback}</div> : null}

      <form className="create-form-container" onSubmit={handleSubmit}>
        <FormCard description="Choose the vendor contact and the real ledger account from which money is paid." stepNumber={1} title="Vendor and payment account">
          <FormGrid columns={3}>
            <FormField label="Vendor contact" required>
              <EntityPicker
                ariaLabel="Search vendor contacts"
                getOptionBadge={(item) => item.contactType}
                getOptionDescription={(item) => [item.companyName, item.gstin, item.phone].filter(Boolean).join(' / ')}
                getOptionId={(item) => item.id}
                getOptionLabel={(item) => item.displayName}
                onChange={(id, item) => {
                  setContactId(id ?? '')
                  setSelectedVendor(item ?? null)
                  setSelectedVendorLabel(item?.displayName ?? '')
                  setAllocations({})
                  setAllocationBills({})
                  setBillPage(0)
                }}
                onSearch={async (search) => (await listContacts({ filter: 'VENDOR', page: 0, search, size: 20 })).content}
                placeholder="Search vendor name, company, GSTIN, or phone"
                selectedEntity={selectedVendor}
                selectedLabel={selectedVendorLabel || undefined}
                value={contactId || null}
              />
            </FormField>
            <FormField label="Paid through" required>
              <EntityPicker
                ariaLabel="Search cash or bank ledger accounts"
                getOptionDescription={(item) => [item.code, item.subType].filter(Boolean).join(' / ')}
                getOptionId={(item) => item.id}
                getOptionLabel={(item) => item.name}
                onChange={(_id, item) => setPaidThrough(item ?? null)}
                options={paidThroughAccounts}
                placeholder="Search cash or bank account"
                selectedEntity={paidThrough}
                value={paidThrough?.id ?? null}
              />
            </FormField>
            <FormField label="Payment date" required><TextInput onChange={(event) => setPaymentDate(event.target.value)} required type="date" value={paymentDate} /></FormField>
            <FormField label="Payment mode" required>
              <SelectInput onChange={(event) => setPaymentMode(event.target.value)} options={[
                { value: 'BANK_TRANSFER', label: 'Bank transfer' },
                { value: 'CHEQUE', label: 'Cheque' },
                { value: 'UPI', label: 'UPI' },
                { value: 'CASH', label: 'Cash' },
              ]} value={paymentMode} />
            </FormField>
            <FormField label="Reference or cheque number"><TextInput onChange={(event) => setReferenceNumber(event.target.value)} placeholder="e.g. UTR9988112" value={referenceNumber} /></FormField>
            <FormField label="TDS withheld"><NumberInput currencyPrefix="INR" min={0} onChange={(event) => setTdsAmount(Number(event.target.value) || 0)} step="0.01" value={tdsAmount} /></FormField>
            <FormField label="TDS section"><TextInput onChange={(event) => setTdsSection(event.target.value)} placeholder="e.g. 194C" value={tdsSection} /></FormField>
          </FormGrid>
        </FormCard>

        <FormCard description="Allocate only to posted or partially paid bills for this vendor. Each allocation is capped at the current server-provided balance due." stepNumber={2} title="Bill allocations">
          {!contactId ? <div className="directory-state"><p>Choose a vendor to load their payable bills.</p></div> : bills.isLoading ? <div className="directory-state">Loading payable bills...</div> : visibleBills.length ? (
            <>
              <DataTable caption="Vendor bill payment allocations">
                <thead>
                  <tr>
                    <th scope="col">Bill</th>
                    <th scope="col">Date</th>
                    <th scope="col">Status</th>
                    <th className="numeric-cell" scope="col">Balance due</th>
                    <th className="numeric-cell" scope="col">Amount applied</th>
                  </tr>
                </thead>
                <tbody>
                  {visibleBills.map((bill) => (
                    <tr key={bill.id}>
                      <td><div className="cell-stack"><strong>{bill.billNumber}</strong>{bill.vendorBillNumber ? <span className="cell-muted">Ref {bill.vendorBillNumber}</span> : null}</div></td>
                      <td>{formatDate(bill.billDate)}</td>
                      <td>{formatStatusLabel(bill.status)}</td>
                      <td className="numeric-cell"><Money amount={bill.balanceDue} currency={bill.currency ?? 'INR'} /></td>
                      <td className="numeric-cell"><NumberInput aria-label={`Amount applied to ${bill.billNumber}`} currencyPrefix="INR" max={Number(bill.balanceDue)} min={0} onChange={(event) => updateAllocation(bill, Number(event.target.value) || 0)} step="0.01" value={allocations[bill.id] || 0} /></td>
                    </tr>
                  ))}
                </tbody>
              </DataTable>
              {bills.data && bills.data.totalPages > 1 ? (
                <div className="form-actions-bar">
                  <Button disabled={billPage === 0} onClick={() => setBillPage((page) => page - 1)} type="button" variant="secondary">Previous bills</Button>
                  <span className="cell-muted">Page {billPage + 1} of {bills.data.totalPages}</span>
                  <Button disabled={billPage >= bills.data.totalPages - 1} onClick={() => setBillPage((page) => page + 1)} type="button" variant="secondary">More bills</Button>
                </div>
              ) : null}
            </>
          ) : <div className="directory-state"><p>This vendor has no payable bills.</p></div>}
          <div className="form-summary-card"><div className="form-summary-row form-summary-row--total"><span>Payment amount</span><Money amount={allocationTotal} /></div></div>
        </FormCard>

        <FormCard description="Notes are retained with the payment and its journal entry." stepNumber={3} title="Notes"><FormField label="Payment notes"><TextAreaInput onChange={(event) => setNotes(event.target.value)} placeholder="Remittance advice or approval note" rows={3} value={notes} /></FormField></FormCard>

        <div className="form-actions-bar">
          <Button onClick={() => navigate(appRoutes.vendorPayments)} type="button" variant="secondary">Cancel</Button>
          <Button disabled={paymentMutation.isPending || !contactId || !paidThrough || allocationTotal <= 0} type="submit" variant="primary"><Save size={16} />{paymentMutation.isPending ? 'Recording...' : 'Record vendor payment'}</Button>
        </div>
      </form>
    </section>
  )
}

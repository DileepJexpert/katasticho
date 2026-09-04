import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowUpRight, ChevronLeft, ChevronRight, Plus } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  FormField,
  Modal,
  Money,
  NumberInput,
  PageHeader,
  SelectInput,
  StatusChip,
  TextInput,
} from '@/design-system'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  listVendorPayments,
  recordVendorPayment,
  type VendorPayment,
} from '@/features/vendor-payments/vendor-payments-api'

export function VendorPaymentsPage() {
  const [page, setPage] = useState(0)
  const [disburseModalOpen, setDisburseModalOpen] = useState(false)
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [form, setForm] = useState({
    contactId: '',
    paymentDate: new Date().toISOString().slice(0, 10),
    amount: 0,
    paymentMode: 'BANK_TRANSFER',
    referenceNumber: '',
    notes: '',
  })

  const payments = useQuery({
    queryKey: ['vendor-payments', { page }],
    queryFn: () => listVendorPayments({ page }),
  })
  const paymentPage = payments.data

  const disburseMutation = useMutation({
    mutationFn: () =>
      recordVendorPayment({
        contactId: form.contactId,
        paymentDate: form.paymentDate,
        amount: Number(form.amount),
        paymentMode: form.paymentMode,
        referenceNumber: form.referenceNumber,
        notes: form.notes,
      }),
    onSuccess: (newPayment) => {
      setDisburseModalOpen(false)
      queryClient.invalidateQueries({ queryKey: ['vendor-payments'] })
      navigate(appRoutes.vendorPaymentDetail(newPayment.id))
    },
  })

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Purchases / Payables"
        title="Vendor Payments"
        description="Disbursements, cheque payments, NEFT/RTGS transfers, and accounts payable settlements."
        actions={
          <Button onClick={() => setDisburseModalOpen(true)} variant="primary">
            <Plus size={16} />
            Record Payment
          </Button>
        }
      />

      <section className="list-panel" aria-label="Vendor payment directory">
        {payments.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Vendor payments could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : payments.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading vendor payments...</div>
        ) : paymentPage?.content.length ? (
          <>
            <DataTable caption="Vendor payments">
              <thead>
                <tr>
                  <th scope="col">Payment #</th>
                  <th scope="col">Vendor</th>
                  <th scope="col">Date</th>
                  <th scope="col">Mode</th>
                  <th scope="col">Reference</th>
                  <th className="numeric-cell" scope="col">TDS withheld</th>
                  <th scope="col">Status</th>
                  <th className="numeric-cell" scope="col">Amount</th>
                </tr>
              </thead>
              <tbody>
                {paymentPage.content.map((payment) => (
                  <VendorPaymentRow
                    key={payment.id}
                    onOpen={() => navigate(appRoutes.vendorPaymentDetail(payment.id))}
                    payment={payment}
                  />
                ))}
              </tbody>
            </DataTable>
            <footer className="table-footer">
              <span>Showing {paymentPage.content.length} of {paymentPage.totalElements} disbursements · Page {paymentPage.page + 1} of {Math.max(paymentPage.totalPages, 1)}</span>
              <div className="pagination-actions">
                <Button
                  aria-label="Previous page"
                  disabled={page === 0}
                  onClick={() => setPage((current) => Math.max(0, current - 1))}
                  variant="secondary"
                >
                  <ChevronLeft aria-hidden="true" size={16} />
                </Button>
                <Button
                  aria-label="Next page"
                  disabled={paymentPage.last || page + 1 >= paymentPage.totalPages}
                  onClick={() => setPage((current) => current + 1)}
                  variant="secondary"
                >
                  <ChevronRight aria-hidden="true" size={16} />
                </Button>
              </div>
            </footer>
          </>
        ) : (
          <div className="directory-state">
            <ArrowUpRight aria-hidden="true" size={24} />
            <strong>No vendor disbursements found</strong>
            <p>Recorded payments and bank disbursements applied to supplier bills will appear here.</p>
          </div>
        )}
      </section>

      <Modal
        footer={
          <>
            <Button onClick={() => setDisburseModalOpen(false)} variant="secondary">Cancel</Button>
            <Button
              disabled={!form.contactId || form.amount <= 0 || disburseMutation.isPending}
              onClick={() => disburseMutation.mutate()}
              variant="primary"
            >
              {disburseMutation.isPending ? 'Recording...' : 'Disburse Payment'}
            </Button>
          </>
        }
        isOpen={disburseModalOpen}
        onClose={() => setDisburseModalOpen(false)}
        size="md"
        title="Record Vendor Payment"
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <FormField label="Vendor Contact ID" required>
            <TextInput
              onChange={(e) => setForm((f) => ({ ...f, contactId: e.target.value }))}
              placeholder="UUID of supplier"
              required
              value={form.contactId}
            />
          </FormField>
          <FormField label="Payment Date" required>
            <TextInput
              onChange={(e) => setForm((f) => ({ ...f, paymentDate: e.target.value }))}
              required
              type="date"
              value={form.paymentDate}
            />
          </FormField>
          <FormField label="Amount (₹)" required>
            <NumberInput
              min={0}
              onChange={(e) => setForm((f) => ({ ...f, amount: Number(e.target.value) }))}
              required
              step="0.01"
              value={form.amount || ''}
            />
          </FormField>
          <FormField label="Payment Mode">
            <SelectInput
              onChange={(e) => setForm((f) => ({ ...f, paymentMode: e.target.value }))}
              value={form.paymentMode}
            >
              <option value="BANK_TRANSFER">Bank Transfer (NEFT/RTGS/IMPS)</option>
              <option value="CHEQUE">Cheque</option>
              <option value="UPI">UPI</option>
              <option value="CASH">Cash</option>
            </SelectInput>
          </FormField>
          <FormField label="Reference / Cheque #">
            <TextInput
              onChange={(e) => setForm((f) => ({ ...f, referenceNumber: e.target.value }))}
              placeholder="e.g. UTR9988112"
              value={form.referenceNumber}
            />
          </FormField>
          <FormField label="Notes">
            <TextInput
              onChange={(e) => setForm((f) => ({ ...f, notes: e.target.value }))}
              value={form.notes}
            />
          </FormField>
        </div>
      </Modal>
    </section>
  )
}

function VendorPaymentRow({ payment, onOpen }: { payment: VendorPayment; onOpen: () => void }) {
  const currency = payment.currency ?? 'INR'

  return (
    <tr>
      <td>
        <Button className="document-link" onClick={onOpen} variant="ghost">
          <code>{payment.paymentNumber}</code>
        </Button>
      </td>
      <td>
        <strong>{payment.vendorName ?? 'Unknown vendor'}</strong>
      </td>
      <td>{formatDate(payment.paymentDate)}</td>
      <td>{payment.paymentMode ? formatStatusLabel(payment.paymentMode) : 'Bank Transfer'}</td>
      <td>
        {payment.referenceNumber ? <code>{payment.referenceNumber}</code> : <span className="cell-muted">--</span>}
      </td>
      <td className="numeric-cell">
        {payment.tdsAmount ? <Money amount={payment.tdsAmount} currency={currency} /> : <span className="cell-muted">--</span>}
      </td>
      <td>
        <StatusChip status="Posted" />
      </td>
      <td className="numeric-cell">
        <strong><Money amount={payment.amount} currency={currency} /></strong>
      </td>
    </tr>
  )
}

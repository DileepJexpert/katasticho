import { useEffect, useMemo, useRef, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, FileCheck, Save, Trash2 } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  CheckboxInput,
  DataTable,
  EntityPicker,
  FormCard,
  FormField,
  FormGrid,
  Money,
  NumberInput,
  PageHeader,
  TextAreaInput,
  TextInput,
} from '@/design-system'
import { listAccounts, listDefaultAccounts, type Account } from '@/features/accounts/accounts-api'
import { listContacts, type Contact } from '@/features/contacts/contacts-api'
import {
  createInvoice,
  type CreateInvoiceLineRequest,
} from '@/features/invoices/invoices-api'
import { listItems, type Item } from '@/features/items/items-api'
import { BatchAllocationPicker } from '@/features/inventory/batch-allocation-picker'

type InvoiceLineForm = CreateInvoiceLineRequest & {
  id: string
  itemName: string
  unit: string | null
  usesItemRevenueAccount: boolean
  trackBatches: boolean
}

function numberValue(value: number | string | null | undefined) {
  return Number(value) || 0
}

export function InvoiceCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const defaultRevenueInitialised = useRef(false)
  const [customer, setCustomer] = useState<Contact | null>(null)
  const [revenueAccount, setRevenueAccount] = useState<Account | null>(null)
  const [invoiceDate, setInvoiceDate] = useState(() => new Date().toISOString().split('T')[0] || '')
  const [dueDate, setDueDate] = useState(() => {
    const date = new Date()
    date.setDate(date.getDate() + 30)
    return date.toISOString().split('T')[0] || ''
  })
  const [placeOfSupply, setPlaceOfSupply] = useState('')
  const [reverseCharge, setReverseCharge] = useState(false)
  const [notes, setNotes] = useState('')
  const [termsAndConditions, setTermsAndConditions] = useState('')
  const [lines, setLines] = useState<InvoiceLineForm[]>([])
  const [feedback, setFeedback] = useState<string | null>(null)

  const accounts = useQuery({ queryKey: ['accounts'], queryFn: listAccounts })
  const defaultAccounts = useQuery({ queryKey: ['default-accounts'], queryFn: listDefaultAccounts })
  const revenueAccounts = useMemo(
    () => (accounts.data ?? []).filter((account) => account.isActive && account.isInvolvedInTransaction && account.type === 'REVENUE'),
    [accounts.data],
  )

  useEffect(() => {
    if (defaultRevenueInitialised.current || !accounts.data || !defaultAccounts.data) return
    defaultRevenueInitialised.current = true
    const configuredRevenue = defaultAccounts.data.find((account) => account.purpose === 'SALES_REVENUE')
    const matchingAccount = revenueAccounts.find((account) => account.id === configuredRevenue?.accountId || account.code === configuredRevenue?.accountCode)
    if (matchingAccount) setRevenueAccount(matchingAccount)
  }, [accounts.data, defaultAccounts.data, revenueAccounts])

  const updateLine = (id: string, updates: Partial<InvoiceLineForm>) => {
    setLines((previous) => previous.map((line) => line.id === id ? { ...line, ...updates } : line))
  }

  const addCatalogItem = (item: Item | null | undefined) => {
    if (!item) return
    const itemRevenueAccount = item.revenueAccountCode?.trim()
    setLines((previous) => [
      ...previous,
      {
        id: crypto.randomUUID(),
        itemId: item.id,
        itemName: item.name,
        description: item.name,
        hsnCode: item.hsnCode ?? undefined,
        quantity: 1,
        unitPrice: numberValue(item.salePrice),
        discountPercent: 0,
        gstRate: numberValue(item.gstRate),
        taxGroupId: item.defaultTaxGroupId ?? undefined,
        accountCode: itemRevenueAccount || revenueAccount?.code || '',
        unit: item.unitOfMeasure,
        usesItemRevenueAccount: Boolean(itemRevenueAccount),
        trackBatches: item.trackBatches,
      },
    ])
  }

  const selectRevenueAccount = (account: Account | null) => {
    setRevenueAccount(account)
    setLines((previous) => previous.map((line) => line.usesItemRevenueAccount
      ? line
      : { ...line, accountCode: account?.code ?? '' },
    ))
  }

  const totals = useMemo(() => lines.reduce((result, line) => {
    const gross = line.quantity * line.unitPrice
    const discount = gross * (line.discountPercent ?? 0) / 100
    const taxable = gross - discount
    const tax = taxable * numberValue(line.gstRate) / 100
    return {
      gross: result.gross + gross,
      discount: result.discount + discount,
      taxable: result.taxable + taxable,
      tax: result.tax + tax,
    }
  }, { gross: 0, discount: 0, taxable: 0, tax: 0 }), [lines])

  const unresolvedRevenueLine = lines.find((line) => !line.accountCode)
  const createMutation = useMutation({
    mutationFn: createInvoice,
    onSuccess: (created) => {
      queryClient.invalidateQueries({ queryKey: ['invoices'] })
      navigate(appRoutes.invoiceDetail(created.id))
    },
    onError: (error: Error) => setFeedback(error.message),
  })

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault()
    setFeedback(null)
    if (!customer) {
      setFeedback('Select a customer before creating the invoice.')
      return
    }
    if (!lines.length) {
      setFeedback('Add at least one item line before creating the invoice.')
      return
    }
    if (unresolvedRevenueLine) {
      setFeedback(`Choose a revenue account before invoicing ${unresolvedRevenueLine.itemName}.`)
      return
    }
    if (lines.some((line) => !line.description.trim() || line.quantity < 0.01 || line.unitPrice < 0.01 || numberValue(line.gstRate) < 0 || (line.discountPercent ?? 0) > 99.99)) {
      setFeedback('Each line needs a description, quantity and unit price above zero, GST at or above zero, and a discount below 100%.')
      return
    }

    createMutation.mutate({
      contactId: customer.id,
      invoiceDate,
      dueDate: dueDate || undefined,
      placeOfSupply: placeOfSupply.trim() || undefined,
      reverseCharge,
      notes: notes.trim() || undefined,
      termsAndConditions: termsAndConditions.trim() || undefined,
      lines: lines.map((line) => ({
        itemId: line.itemId,
        description: line.description,
        quantity: line.quantity,
        unitPrice: line.unitPrice,
        accountCode: line.accountCode,
        hsnCode: line.hsnCode,
        gstRate: line.gstRate,
        discountPercent: line.discountPercent,
        taxGroupId: line.taxGroupId,
        batchId: line.batchId,
      })),
    })
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={appRoutes.invoices}><ArrowLeft size={16} /> Back to invoices</Link>
      <PageHeader
        eyebrow="Sales / Receivables"
        title="New direct sales invoice"
        description="Use this for an immediate sale. For goods already dispatched against an order, create the linked invoice from the sales order so inventory is not deducted twice."
      />
      {feedback ? <div className="banner banner--error" role="alert">{feedback}</div> : null}
      {accounts.isError || defaultAccounts.isError ? <div className="banner banner--error" role="alert">Revenue-account settings could not be loaded. Direct invoice creation is unavailable until the account configuration can be read.</div> : null}

      <form className="create-form-container" onSubmit={handleSubmit}>
        <FormCard description="Select the receivable contact, issue dates, and the organisation revenue account. The configured Sales Revenue account is selected automatically when available." stepNumber={1} title="Customer and accounting">
          <FormGrid columns={4}>
            <FormField label="Customer" required span={2}>
              <EntityPicker
                ariaLabel="Search customer contacts"
                getOptionBadge={(contact) => contact.contactType}
                getOptionDescription={(contact) => [contact.companyName, contact.gstin, contact.phone].filter(Boolean).join(' / ')}
                getOptionId={(contact) => contact.id}
                getOptionLabel={(contact) => contact.displayName}
                onChange={(_id, contact) => setCustomer(contact ?? null)}
                onSearch={async (search) => (await listContacts({ filter: 'CUSTOMER', page: 0, search, size: 20 })).content}
                placeholder="Search customer name, company, GSTIN, or phone"
                selectedEntity={customer}
                value={customer?.id ?? null}
              />
            </FormField>
            <FormField label="Invoice date" required><TextInput onChange={(event) => setInvoiceDate(event.target.value)} required type="date" value={invoiceDate} /></FormField>
            <FormField label="Due date"><TextInput onChange={(event) => setDueDate(event.target.value)} type="date" value={dueDate} /></FormField>
            <FormField label="Revenue account" required span={2}>
              <EntityPicker
                ariaLabel="Search revenue accounts"
                disabled={accounts.isLoading || defaultAccounts.isLoading}
                getOptionDescription={(account) => `${account.code} / ${account.subType ?? 'Revenue'}`}
                getOptionId={(account) => account.id}
                getOptionLabel={(account) => account.name}
                onChange={(_id, account) => selectRevenueAccount(account ?? null)}
                options={revenueAccounts}
                placeholder={accounts.isLoading || defaultAccounts.isLoading ? 'Loading configured revenue account...' : 'Search active revenue accounts'}
                selectedEntity={revenueAccount}
                value={revenueAccount?.id ?? null}
              />
            </FormField>
            <FormField label="Place of supply"><TextInput onChange={(event) => setPlaceOfSupply(event.target.value)} placeholder="e.g. 09-Uttar Pradesh" value={placeOfSupply} /></FormField>
            <FormField label="Tax treatment">
              <CheckboxInput checked={reverseCharge} description="Recipient pays tax under the applicable reverse-charge rule." onChange={(event) => setReverseCharge(event.target.checked)} title="Reverse charge mechanism" />
            </FormField>
          </FormGrid>
        </FormCard>

        <FormCard description="Search the item catalogue. The item’s revenue-account assignment is retained; otherwise the revenue account selected above is used." stepNumber={2} title={`Invoice lines (${lines.length})`}>
          <FormField label="Add catalog item">
            <EntityPicker<Item>
              ariaLabel="Search items to add to direct invoice"
              getOptionDescription={(item) => [item.sku, item.hsnCode, item.unitOfMeasure, item.totalOnHand === null ? null : `On hand ${item.totalOnHand}`].filter(Boolean).join(' / ')}
              getOptionId={(item) => item.id}
              getOptionLabel={(item) => item.name}
              onChange={(_id, item) => addCatalogItem(item)}
              onSearch={async (search) => (await listItems({ activeOnly: true, search, size: 20 })).content}
              placeholder="Search item name, SKU, or HSN"
              value={null}
            />
          </FormField>

          {lines.length ? (
            <DataTable caption="Direct invoice lines">
              <thead>
                <tr>
                  <th scope="col">Item and description</th>
                  <th scope="col">Revenue account</th>
                  <th scope="col">HSN</th>
                  <th className="numeric-cell" scope="col">Qty</th>
                  <th className="numeric-cell" scope="col">Rate</th>
                  <th className="numeric-cell" scope="col">Discount</th>
                  <th className="numeric-cell" scope="col">GST</th>
                  <th className="numeric-cell" scope="col">Total preview</th>
                  <th scope="col"><span className="visually-hidden">Remove</span></th>
                </tr>
              </thead>
              <tbody>
                {lines.map((line) => {
                  const gross = line.quantity * line.unitPrice
                  const taxable = gross * (1 - (line.discountPercent ?? 0) / 100)
                  const lineTotal = taxable * (1 + numberValue(line.gstRate) / 100)
                  return (
                    <tr key={line.id}>
                      <td><div className="cell-stack"><strong>{line.itemName}</strong><TextInput aria-label={`Description for ${line.itemName}`} onChange={(event) => updateLine(line.id, { description: event.target.value })} value={line.description} />{line.trackBatches && <BatchAllocationPicker itemId={line.itemId ?? null} value={line.batchId ?? null} quantity={line.quantity} automatic disabled={createMutation.isPending} onChange={(batchId) => updateLine(line.id, { batchId })} />}</div></td>
                      <td><code>{line.accountCode || '--'}</code></td>
                      <td><TextInput aria-label={`HSN for ${line.itemName}`} onChange={(event) => updateLine(line.id, { hsnCode: event.target.value || undefined })} placeholder="HSN" value={line.hsnCode ?? ''} /></td>
                      <td className="numeric-cell"><NumberInput min={0.01} onChange={(event) => updateLine(line.id, { quantity: Number(event.target.value) || 0 })} step="0.001" value={line.quantity} /></td>
                      <td className="numeric-cell"><NumberInput currencyPrefix="INR" min={0.01} onChange={(event) => updateLine(line.id, { unitPrice: Number(event.target.value) || 0 })} step="0.01" value={line.unitPrice} /></td>
                      <td className="numeric-cell"><NumberInput max={99.99} min={0} onChange={(event) => updateLine(line.id, { discountPercent: Number(event.target.value) || 0 })} step="0.01" unitSuffix="%" value={line.discountPercent ?? 0} /></td>
                      <td className="numeric-cell"><NumberInput min={0} onChange={(event) => updateLine(line.id, { gstRate: Number(event.target.value) || 0 })} step="0.01" unitSuffix="%" value={numberValue(line.gstRate)} /></td>
                      <td className="numeric-cell"><Money amount={lineTotal} /></td>
                      <td><Button aria-label={`Remove ${line.itemName}`} onClick={() => setLines((previous) => previous.filter((entry) => entry.id !== line.id))} type="button" variant="ghost"><Trash2 size={14} /></Button></td>
                    </tr>
                  )
                })}
              </tbody>
            </DataTable>
          ) : <div className="directory-state"><FileCheck size={28} /><p>Search for a catalog item to begin this invoice.</p></div>}

          <div className="form-summary-card">
            <div className="form-summary-row"><span>Gross value preview</span><Money amount={totals.gross} /></div>
            <div className="form-summary-row"><span>Line discount preview</span><Money amount={totals.discount} /></div>
            <div className="form-summary-row"><span>GST preview</span><Money amount={totals.tax} /></div>
            <div className="form-summary-row form-summary-row--total"><span>Invoice total preview</span><Money amount={totals.taxable + totals.tax} /></div>
          </div>
        </FormCard>

        <FormCard description="Keep customer-facing terms and internal notes with the draft. Sending the invoice is a separate, auditable action." stepNumber={3} title="Terms and notes">
          <FormGrid columns={2}>
            <FormField label="Invoice notes"><TextAreaInput onChange={(event) => setNotes(event.target.value)} placeholder="Customer-visible note" rows={3} value={notes} /></FormField>
            <FormField label="Terms and conditions"><TextAreaInput onChange={(event) => setTermsAndConditions(event.target.value)} placeholder="Payment or supply terms" rows={3} value={termsAndConditions} /></FormField>
          </FormGrid>
        </FormCard>

        <div className="form-actions-bar">
          <Button onClick={() => navigate(appRoutes.invoices)} type="button" variant="secondary">Cancel</Button>
          <Button disabled={createMutation.isPending || !customer || !lines.length || Boolean(unresolvedRevenueLine) || accounts.isLoading || defaultAccounts.isLoading || accounts.isError || defaultAccounts.isError} type="submit" variant="primary"><Save size={16} />{createMutation.isPending ? 'Creating...' : 'Create draft invoice'}</Button>
        </div>
      </form>
    </section>
  )
}

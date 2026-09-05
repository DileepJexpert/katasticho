import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Button, DataTable, EntityPicker, Money, PageHeader, StatusChip } from '@/design-system'
import { TextField } from '@/design-system/text-field'
import { listContacts, type Contact } from '@/features/contacts/contacts-api'
import { useSessionStore } from '@/shared/session/session-store'
import { getWallet, getWalletTransactions, getWalletRedeemable } from './loyalty-api'

export function LoyaltyPage() {
  const user = useSessionStore((s) => s.user)
  return <LoyaltyPageWorkspace key={`${user?.orgId}:${user?.id}:${user?.role}`} />
}

function LoyaltyPageWorkspace() {
  const user = useSessionStore((s) => s.user)
  const allowed = ['OWNER', 'ADMIN', 'OPERATOR'].includes(user?.role ?? '')
  const [customer, setCustomer] = useState<Contact | null>(null)
  const [saleTotal, setSaleTotal] = useState('')
  const wallet = useQuery({ queryKey: ['loyalty-wallet', user?.orgId, customer?.id], queryFn: () => getWallet(customer!.id), enabled: allowed && !!customer })
  const history = useQuery({ queryKey: ['loyalty-transactions', user?.orgId, customer?.id], queryFn: () => getWalletTransactions(customer!.id), enabled: allowed && !!customer })
  const eligible = useQuery({ queryKey: ['loyalty-redeemable', user?.orgId, customer?.id, saleTotal], queryFn: () => getWalletRedeemable(customer!.id, Number(saleTotal)), enabled: allowed && !!customer && saleTotal !== '' && Number.isFinite(Number(saleTotal)) && Number(saleTotal) >= 0 })
  if (!allowed) return <div role="alert" className="directory-state">Loyalty wallets require Owner, Admin, or Operator access.</div>
  return <section className="workspace-page">
    <PageHeader eyebrow="Customer loyalty" title="Customer Loyalty & Digital Wallet" description="Inspect customer balances, transaction history, and the server-calculated redemption limit." />
    <div className="banner" role="status">Standalone bonus adjustments are not supported by the existing API. Earning and redemption require a real sale receipt; this screen does not create synthetic receipts or alter wallets independently of a sale.</div>
    <div className="document-card"><h2>Customer wallet</h2><EntityPicker<Contact> ariaLabel="Select customer to view wallet" value={customer?.id ?? null} selectedEntity={customer}
      onChange={(_id, c) => { setCustomer(c ?? null); setSaleTotal('') }}
      onSearch={async (search) => (await listContacts({ filter: 'CUSTOMER', search })).content.filter((c) => c.active)}
      getOptionId={(c) => c.id} getOptionLabel={(c) => c.displayName} getOptionDescription={(c) => [c.companyName, c.phone, c.billingCity].filter(Boolean).join(' / ')} /></div>
    {!customer ? <p className="directory-state">Select a customer to view their wallet.</p> : <>
      {wallet.isError ? <div role="alert">{wallet.error.message}<Button onClick={() => wallet.refetch()}>Retry wallet</Button></div> : wallet.data ? <div className="summary-strip">{[['Balance', wallet.data.balance], ['Total earned', wallet.data.totalEarned], ['Total redeemed', wallet.data.totalRedeemed]].map(([label, amount]) => <div className="summary-card" key={label}><span>{label}</span><Money amount={amount} /></div>)}</div> : <p role="status">Loading wallet...</p>}
      <TextField label="Sale total for redemption preview" type="number" min="0" step="0.01" value={saleTotal} onChange={(e) => setSaleTotal(e.target.value)} hint="Read-only eligibility check. This does not redeem funds." />
      {eligible.isError && <p role="alert">{eligible.error.message}</p>}{eligible.data && <p>Maximum redeemable: <Money amount={eligible.data.maxRedeemable ?? 0} />. Minimum redemption is 10.</p>}
      {history.isError ? <div role="alert">{history.error.message}<Button onClick={() => history.refetch()}>Retry history</Button></div> : history.data ? <DataTable caption="Wallet transactions"><thead><tr><th>Date</th><th>Type</th><th>Reference type</th><th>Notes</th><th className="numeric-cell">Amount</th><th className="numeric-cell">Balance after</th></tr></thead><tbody>{history.data.map((t) => <tr key={t.id}><td>{t.createdAt?.slice(0, 10) ?? '-'}</td><td><StatusChip status={t.txnType} /></td><td>{t.referenceType ?? '-'}</td><td>{t.notes ?? '-'}</td><td className="numeric-cell"><Money amount={t.amount} /></td><td className="numeric-cell"><Money amount={t.balanceAfter} /></td></tr>)}</tbody></DataTable> : <p role="status">Loading transactions...</p>}
    </>}
  </section>
}

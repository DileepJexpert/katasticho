import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowDownLeft,
  ArrowUpRight,
  Coins,
  Plus,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { listContacts } from '@/features/contacts/contacts-api'
import {
  earnLoyaltyPoints,
  getWallet,
  getWalletTransactions,
  redeemLoyaltyPoints,
} from '@/features/loyalty/loyalty-api'

export function LoyaltyPage() {
  const queryClient = useQueryClient()
  const [selectedContactId, setSelectedContactId] = useState<string>('')
  const [pointsToEarn, setPointsToEarn] = useState('')
  const [earnNotes, setEarnNotes] = useState('')
  const [pointsToRedeem, setPointsToRedeem] = useState('')
  const [redeemNotes, setRedeemNotes] = useState('')
  const [isEarnModalOpen, setIsEarnModalOpen] = useState(false)
  const [isRedeemModalOpen, setIsRedeemModalOpen] = useState(false)

  const contactsQuery = useQuery({
    queryKey: ['loyalty-contacts-list'],
    queryFn: () => listContacts({ filter: 'CUSTOMER', page: 0, search: '' }),
  })

  const contacts = contactsQuery.data?.content ?? []

  // Auto-select first contact if none selected
  const activeContactId = selectedContactId || (contacts[0]?.id ?? '')

  const walletQuery = useQuery({
    queryKey: ['loyalty-wallet', activeContactId],
    queryFn: () => (activeContactId ? getWallet(activeContactId) : Promise.resolve(null)),
    enabled: Boolean(activeContactId),
  })

  const transactionsQuery = useQuery({
    queryKey: ['loyalty-transactions', activeContactId],
    queryFn: () => (activeContactId ? getWalletTransactions(activeContactId) : Promise.resolve([])),
    enabled: Boolean(activeContactId),
  })

  const wallet = walletQuery.data
  const transactions = transactionsQuery.data ?? []

  const earnMutation = useMutation({
    mutationFn: ({ contactId, amount, notes }: { contactId: string; amount: number; notes?: string }) =>
      earnLoyaltyPoints({ contactId, amount, notes }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['loyalty-wallet', activeContactId] })
      queryClient.invalidateQueries({ queryKey: ['loyalty-transactions', activeContactId] })
      setIsEarnModalOpen(false)
      setPointsToEarn('')
      setEarnNotes('')
    },
  })

  const redeemMutation = useMutation({
    mutationFn: ({ contactId, points, notes }: { contactId: string; points: number; notes?: string }) =>
      redeemLoyaltyPoints({ contactId, points, notes }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['loyalty-wallet', activeContactId] })
      queryClient.invalidateQueries({ queryKey: ['loyalty-transactions', activeContactId] })
      setIsRedeemModalOpen(false)
      setPointsToRedeem('')
      setRedeemNotes('')
    },
  })

  const selectedContact = contacts.find((c) => c.id === activeContactId)

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="CRM / Customer Engagement"
        title="Customer Loyalty & Digital Wallet"
        description="Reward points ledger, checkout redemptions, bonus campaigns, and transaction history."
        actions={<StatusChip status="Loyalty Program" />}
      />

      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Active Wallet Balance</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-primary)' }}>
            <Quantity value={wallet?.balance || 0} /> pts
          </strong>
          <span className="summary-card__hint">
            Cash Value: <Money amount={(wallet?.balance || 0) * 1} />
          </span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Cumulative Earned</span>
          <strong className="summary-card__value">
            <Quantity value={wallet?.totalEarned || 0} /> pts
          </strong>
          <span className="summary-card__hint">Lifetime reward earnings</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Total Redeemed</span>
          <strong className="summary-card__value">
            <Quantity value={wallet?.totalRedeemed || 0} /> pts
          </strong>
          <span className="summary-card__hint">Points used in purchases</span>
        </div>

        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Quick Actions</span>
          <div style={{ display: 'flex', gap: 6, marginTop: 4, flexWrap: 'wrap' }}>
            <Button onClick={() => setIsEarnModalOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={12} style={{ marginRight: 4 }} />
              Award Points
            </Button>
            <Button
              disabled={!wallet?.balance || wallet.balance <= 0}
              onClick={() => setIsRedeemModalOpen(true)}
              variant="secondary"
            >
              <Coins aria-hidden="true" size={12} style={{ marginRight: 4 }} />
              Redeem
            </Button>
          </div>
        </div>
      </div>

      {/* Customer selector bar */}
      <div className="list-toolbar" style={{ justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', gap: 'var(--space-sm)', alignItems: 'center' }}>
          <span style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--color-text-secondary)' }}>
            Customer:
          </span>
          <select
            aria-label="Select customer to view wallet"
            className="select-field"
            onChange={(e) => setSelectedContactId(e.target.value)}
            style={{
              padding: '6px 14px',
              borderRadius: 'var(--radius-md)',
              border: '1px solid var(--color-border)',
              background: 'var(--color-surface)',
              color: 'var(--color-text-primary)',
              fontWeight: 600,
            }}
            value={activeContactId}
          >
            {contacts.map((c) => (
              <option key={c.id} value={c.id}>
                {c.displayName} {c.phone ? `(${c.phone})` : ''}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Transaction History Table */}
      <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
        <h3 style={{ fontSize: '1.05rem', fontWeight: 600, marginBottom: 'var(--space-sm)' }}>
          Points Transaction History for {selectedContact?.displayName || 'Customer'}
        </h3>

        {transactionsQuery.isLoading ? (
          <div aria-live="polite" className="directory-state">
            Loading points history...
          </div>
        ) : transactions.length === 0 ? (
          <div className="directory-state">
            <Coins aria-hidden="true" size={24} />
            <strong>No loyalty transactions yet.</strong>
            <p>Reward points will accumulate automatically on completed POS receipts and invoices.</p>
          </div>
        ) : (
          <DataTable caption="Wallet transaction ledger">
            <thead>
              <tr>
                <th scope="col">Date & Time</th>
                <th scope="col">Transaction Type</th>
                <th className="numeric-cell" scope="col">Points</th>
                <th className="numeric-cell" scope="col">Balance After</th>
                <th scope="col">Notes / Reference</th>
              </tr>
            </thead>
            <tbody>
              {transactions.map((txn) => {
                const isEarn = txn.txnType === 'EARN'
                return (
                  <tr key={txn.id}>
                    <td>
                      <span className="cell-muted">{txn.createdAt || 'â€”'}</span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                        {isEarn ? (
                          <ArrowDownLeft aria-hidden="true" size={14} color="var(--color-success)" />
                        ) : (
                          <ArrowUpRight aria-hidden="true" size={14} color="var(--color-error)" />
                        )}
                        <StatusChip status={txn.txnType} />
                      </div>
                    </td>
                    <td className="numeric-cell">
                      <strong style={{ color: isEarn ? 'var(--color-success)' : 'var(--color-error)' }}>
                        {isEarn ? '+' : '-'}
                        <Quantity value={txn.amount} /> pts
                      </strong>
                    </td>
                    <td className="numeric-cell">
                      <strong>
                        <Quantity value={txn.balanceAfter} /> pts
                      </strong>
                    </td>
                    <td>
                      <span className="cell-muted">{txn.notes || txn.referenceType || 'â€”'}</span>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </DataTable>
        )}
      </div>

      {/* MODAL: AWARD POINTS */}
      {isEarnModalOpen && (
        <div
          role="dialog"
          aria-modal="true"
          aria-labelledby="earn-points-title"
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(0,0,0,0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: 'var(--space-md)',
          }}
        >
          <div
            className="panel-card"
            style={{
              width: '100%',
              maxWidth: 420,
              backgroundColor: 'var(--color-surface)',
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--space-lg)',
              border: '1px solid var(--color-border)',
            }}
          >
            <h3 id="earn-points-title" style={{ fontSize: '1.2rem', fontWeight: 600, marginBottom: 'var(--space-sm)' }}>
              Award Bonus Loyalty Points
            </h3>
            <p className="cell-muted" style={{ fontSize: '0.85rem', marginBottom: 'var(--space-md)' }}>
              Credit reward points to <strong>{selectedContact?.displayName}</strong>.
            </p>
            <div style={{ marginBottom: 'var(--space-sm)' }}>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                Points to Credit
              </label>
              <input
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid var(--color-border)',
                  fontSize: '1.1rem',
                  fontWeight: 600,
                }}
                onChange={(e) => setPointsToEarn(e.target.value)}
                placeholder="100"
                type="number"
                value={pointsToEarn}
              />
            </div>
            <div style={{ marginBottom: 'var(--space-md)' }}>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                Reason / Campaign Note
              </label>
              <input
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid var(--color-border)',
                }}
                onChange={(e) => setEarnNotes(e.target.value)}
                placeholder="e.g. Festival bonus / goodwill credit"
                type="text"
                value={earnNotes}
              />
            </div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 'var(--space-sm)' }}>
              <Button onClick={() => setIsEarnModalOpen(false)} variant="secondary">
                Cancel
              </Button>
              <Button
                disabled={!pointsToEarn || earnMutation.isPending}
                onClick={() =>
                  earnMutation.mutate({
                    contactId: activeContactId,
                    amount: Number(pointsToEarn),
                    notes: earnNotes,
                  })
                }
                variant="primary"
              >
                {earnMutation.isPending ? 'Crediting...' : 'Credit Points'}
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL: REDEEM POINTS */}
      {isRedeemModalOpen && (
        <div
          role="dialog"
          aria-modal="true"
          aria-labelledby="redeem-points-title"
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(0,0,0,0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: 'var(--space-md)',
          }}
        >
          <div
            className="panel-card"
            style={{
              width: '100%',
              maxWidth: 420,
              backgroundColor: 'var(--color-surface)',
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--space-lg)',
              border: '1px solid var(--color-border)',
            }}
          >
            <h3 id="redeem-points-title" style={{ fontSize: '1.2rem', fontWeight: 600, marginBottom: 'var(--space-sm)' }}>
              Redeem Loyalty Points
            </h3>
            <p className="cell-muted" style={{ fontSize: '0.85rem', marginBottom: 'var(--space-md)' }}>
              Available Balance: <strong>{wallet?.balance || 0} points</strong> (₹{(wallet?.balance || 0).toFixed(2)})
            </p>
            <div style={{ marginBottom: 'var(--space-sm)' }}>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                Points to Redeem
              </label>
              <input
                max={wallet?.balance || 0}
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid var(--color-border)',
                  fontSize: '1.1rem',
                  fontWeight: 600,
                }}
                onChange={(e) => setPointsToRedeem(e.target.value)}
                placeholder="50"
                type="number"
                value={pointsToRedeem}
              />
            </div>
            <div style={{ marginBottom: 'var(--space-md)' }}>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                Redemption Notes
              </label>
              <input
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid var(--color-border)',
                }}
                onChange={(e) => setRedeemNotes(e.target.value)}
                placeholder="e.g. Counter invoice discount redemption"
                type="text"
                value={redeemNotes}
              />
            </div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 'var(--space-sm)' }}>
              <Button onClick={() => setIsRedeemModalOpen(false)} variant="secondary">
                Cancel
              </Button>
              <Button
                disabled={!pointsToRedeem || Number(pointsToRedeem) > (wallet?.balance || 0) || redeemMutation.isPending}
                onClick={() =>
                  redeemMutation.mutate({
                    contactId: activeContactId,
                    points: Number(pointsToRedeem),
                    notes: redeemNotes,
                  })
                }
                variant="primary"
              >
                {redeemMutation.isPending ? 'Redeeming...' : 'Confirm Redemption'}
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}

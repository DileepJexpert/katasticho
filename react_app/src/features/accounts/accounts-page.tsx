import { useDeferredValue, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  BookOpen,
  ChevronLeft,
  ChevronRight,
  Edit2,
  Plus,
  Search,
  Sparkles,
  Trash2,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatStatusLabel } from '@/shared/format/format'
import {
  createAccount,
  deleteAccount,
  listAccounts,
  seedTemplate,
  updateAccount,
  type Account,
  type AccountType,
} from '@/features/accounts/accounts-api'

const typeTabs = [
  { label: 'All', value: 'ALL' },
  { label: 'Assets', value: 'ASSET' },
  { label: 'Liabilities', value: 'LIABILITY' },
  { label: 'Equity', value: 'EQUITY' },
  { label: 'Revenue', value: 'REVENUE' },
  { label: 'Expenses', value: 'EXPENSE' },
] as const

type TypeFilter = (typeof typeTabs)[number]['value']
const PAGE_SIZE = 25

export function AccountsPage() {
  const [selectedTab, setSelectedTab] = useState<TypeFilter>('ALL')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(0)
  const [showCreateModal, setShowCreateModal] = useState(false)
  const [editingAccount, setEditingAccount] = useState<Account | null>(null)
  const [showSeedModal, setShowSeedModal] = useState(false)

  const deferredSearch = useDeferredValue(search.trim().toLowerCase())
  // const navigate = useNavigate()
  const queryClient = useQueryClient()

  const accounts = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => deleteAccount(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['accounts'] }),
  })

  const allAccounts = accounts.data ?? []

  const filteredAccounts = allAccounts.filter((acc) => {
    if (selectedTab !== 'ALL' && acc.type?.toUpperCase() !== selectedTab) {
      return false
    }
    if (!deferredSearch) return true
    return (
      acc.code.toLowerCase().includes(deferredSearch) ||
      acc.name.toLowerCase().includes(deferredSearch) ||
      (acc.subType ?? '').toLowerCase().includes(deferredSearch) ||
      (acc.parentAccountName ?? '').toLowerCase().includes(deferredSearch)
    )
  })

  const totalPages = Math.max(1, Math.ceil(filteredAccounts.length / PAGE_SIZE))
  const paginatedAccounts = filteredAccounts.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE)

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <Button onClick={() => setShowSeedModal(true)} variant="secondary">
              <Sparkles className="icon" /> Industry Templates
            </Button>
            <Button onClick={() => setShowCreateModal(true)} variant="primary">
              <Plus className="icon" /> Add Account
            </Button>
          </div>
        }
        description="Hierarchical Chart of Accounts, financial classifications, system accounts, and opening balances."
        eyebrow="Accounting / General Ledger"
        title="Chart of Accounts"
      />

      <section className="list-panel" aria-label="Chart of accounts directory">
        <div className="list-toolbar list-toolbar--stacked">
          <div aria-label="Filter by account type" className="filter-chips" role="tablist">
            {typeTabs.map((tab) => {
              const count =
                tab.value === 'ALL'
                  ? allAccounts.length
                  : allAccounts.filter((a) => a.type?.toUpperCase() === tab.value).length

              return (
                <button
                  aria-selected={selectedTab === tab.value}
                  className={`filter-chip ${selectedTab === tab.value ? 'filter-chip--active' : ''}`}
                  key={tab.value}
                  onClick={() => {
                    setSelectedTab(tab.value)
                    setPage(0)
                  }}
                  role="tab"
                  type="button"
                >
                  <span>{tab.label}</span>
                  {accounts.data ? <span className="filter-chip-count">{count}</span> : null}
                </button>
              )
            })}
          </div>

          <label className="directory-search">
            <Search aria-hidden="true" size={18} />
            <span className="sr-only">Search accounts</span>
            <input
              onChange={(event) => {
                setSearch(event.target.value)
                setPage(0)
              }}
              placeholder="Search by account code, name, category..."
              type="search"
              value={search}
            />
          </label>
        </div>

        {accounts.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Accounts could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : accounts.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading accounts...</div>
        ) : paginatedAccounts.length ? (
          <>
            <DataTable caption="Chart of accounts">
              <thead>
                <tr>
                  <th scope="col">Code</th>
                  <th scope="col">Account Name</th>
                  <th scope="col">Type</th>
                  <th scope="col">Category</th>
                  <th scope="col">Parent Account</th>
                  <th className="numeric-cell" scope="col">Opening Balance</th>
                  <th scope="col">Status</th>
                  <th scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {paginatedAccounts.map((account) => (
                  <tr key={account.id}>
                    <td>
                      <Link to={`${appRoutes.accounts}/${account.id}`}>
                        <code>{account.code}</code>
                      </Link>
                    </td>
                    <td>
                      <div>
                        <Link to={`${appRoutes.accounts}/${account.id}`}>
                          <strong>{account.name}</strong>
                        </Link>
                        {account.isSystem && (
                          <span style={{ marginLeft: '6px', fontSize: '0.7rem', color: 'var(--color-primary)' }}>
                            [System]
                          </span>
                        )}
                      </div>
                    </td>
                    <td>
                      <StatusChip status={account.type} />
                    </td>
                    <td>{account.subType ? formatStatusLabel(account.subType) : '—'}</td>
                    <td>{account.parentAccountName ?? '—'}</td>
                    <td className="numeric-cell">
                      <Money amount={account.openingBalance} currency={account.currency ?? 'INR'} />
                    </td>
                    <td>
                      <StatusChip status={account.isActive ? 'Active' : 'Inactive'} />
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '0.25rem', alignItems: 'center' }}>
                        <Button onClick={() => setEditingAccount(account)} variant="ghost">
                          <Edit2 className="icon" style={{ width: 14, height: 14 }} />
                        </Button>
                        {!account.isSystem && (
                          <Button
                            disabled={deleteMutation.isPending}
                            onClick={() => {
                              if (confirm(`Delete account ${account.name} (${account.code})?`)) {
                                deleteMutation.mutate(account.id)
                              }
                            }}
                            variant="ghost"
                          >
                            <Trash2 className="icon" style={{ width: 14, height: 14, color: 'var(--color-danger, #BE3A34)' }} />
                          </Button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>

            <footer className="table-footer">
              <span>
                {filteredAccounts.length} account{filteredAccounts.length === 1 ? '' : 's'}{' '}
                {deferredSearch ? 'matching this search' : selectedTab !== 'ALL' ? `in ${selectedTab.toLowerCase()}` : 'in total'}
              </span>
              <div className="pagination-actions">
                <button
                  aria-label="Previous page"
                  disabled={page === 0}
                  onClick={() => setPage((current) => current - 1)}
                  type="button"
                >
                  <ChevronLeft aria-hidden="true" size={16} />
                </button>
                <span>
                  Page {page + 1} of {totalPages}
                </span>
                <button
                  aria-label="Next page"
                  disabled={page + 1 >= totalPages}
                  onClick={() => setPage((current) => current + 1)}
                  type="button"
                >
                  <ChevronRight aria-hidden="true" size={16} />
                </button>
              </div>
            </footer>
          </>
        ) : (
          <div className="directory-state">
            <BookOpen aria-hidden="true" size={24} />
            <strong>No accounts found.</strong>
            <p>
              {deferredSearch
                ? 'Try a different code, name, or classification.'
                : 'Seed standard industry accounts or create custom ledger accounts.'}
            </p>
          </div>
        )}
      </section>

      {showCreateModal && (
        <CreateAccountModal
          accounts={allAccounts}
          onClose={() => setShowCreateModal(false)}
          onSuccess={() => {
            setShowCreateModal(false)
            queryClient.invalidateQueries({ queryKey: ['accounts'] })
          }}
        />
      )}

      {editingAccount && (
        <EditAccountModal
          account={editingAccount}
          onClose={() => setEditingAccount(null)}
          onSuccess={() => {
            setEditingAccount(null)
            queryClient.invalidateQueries({ queryKey: ['accounts'] })
          }}
        />
      )}

      {showSeedModal && (
        <SeedTemplateModal
          onClose={() => setShowSeedModal(false)}
          onSuccess={() => {
            setShowSeedModal(false)
            queryClient.invalidateQueries({ queryKey: ['accounts'] })
          }}
        />
      )}
    </section>
  )
}

function CreateAccountModal({
  accounts,
  onClose,
  onSuccess,
}: {
  accounts: Account[]
  onClose: () => void
  onSuccess: () => void
}) {
  const [code, setCode] = useState('')
  const [name, setName] = useState('')
  const [type, setType] = useState<AccountType>('ASSET')
  const [subType, setSubType] = useState('')
  const [parentId, setParentId] = useState('')
  const [description, setDescription] = useState('')
  const [openingBalance, setOpeningBalance] = useState<number | ''>('')

  const mutation = useMutation({
    mutationFn: () =>
      createAccount({
        code,
        name,
        type,
        subType: subType || undefined,
        parentId: parentId || undefined,
        description: description || undefined,
        openingBalance: openingBalance === '' ? undefined : Number(openingBalance),
        currency: 'INR',
      }),
    onSuccess: () => onSuccess(),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog">
        <header className="modal-header">
          <h3>Create Ledger Account</h3>
          <Button onClick={onClose} variant="ghost">✕</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: '1rem' }}>
            <label className="field-group">
              <span>Account Code *</span>
              <input onChange={(e) => setCode(e.target.value)} placeholder="e.g. 1050" required value={code} />
            </label>
            <label className="field-group">
              <span>Account Name *</span>
              <input onChange={(e) => setName(e.target.value)} placeholder="e.g. Petty Cash Bangalore" required value={name} />
            </label>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
            <label className="field-group">
              <span>Account Type *</span>
              <select onChange={(e) => setType(e.target.value as AccountType)} value={type}>
                <option value="ASSET">Asset</option>
                <option value="LIABILITY">Liability</option>
                <option value="EQUITY">Equity</option>
                <option value="REVENUE">Revenue</option>
                <option value="EXPENSE">Expense</option>
              </select>
            </label>
            <label className="field-group">
              <span>Sub-Type / Category</span>
              <input onChange={(e) => setSubType(e.target.value)} placeholder="e.g. Current Asset, Bank Account" value={subType} />
            </label>
          </div>

          <label className="field-group">
            <span>Parent Account (Optional)</span>
            <select onChange={(e) => setParentId(e.target.value)} value={parentId}>
              <option value="">-- No Parent (Root Account) --</option>
              {accounts.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.code} - {a.name} ({a.type})
                </option>
              ))}
            </select>
          </label>

          <label className="field-group">
            <span>Opening Balance (INR)</span>
            <input
              onChange={(e) => setOpeningBalance(e.target.value === '' ? '' : Number(e.target.value))}
              placeholder="0.00"
              type="number"
              value={openingBalance}
            />
          </label>

          <label className="field-group">
            <span>Description / Narration</span>
            <textarea onChange={(e) => setDescription(e.target.value)} placeholder="Account usage notes..." rows={2} value={description} />
          </label>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={!code || !name || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Creating...' : 'Create Account'}
          </Button>
        </footer>
      </div>
    </div>
  )
}

function EditAccountModal({
  account,
  onClose,
  onSuccess,
}: {
  account: Account
  onClose: () => void
  onSuccess: () => void
}) {
  const [name, setName] = useState(account.name)
  const [subType, setSubType] = useState(account.subType ?? '')
  const [description, setDescription] = useState(account.description ?? '')
  const [isActive, setIsActive] = useState(account.isActive)

  const mutation = useMutation({
    mutationFn: () =>
      updateAccount(account.id, {
        name,
        subType: subType || undefined,
        description: description || undefined,
        isActive,
      }),
    onSuccess: () => onSuccess(),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog">
        <header className="modal-header">
          <h3>Edit Account ({account.code})</h3>
          <Button onClick={onClose} variant="ghost">✕</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <label className="field-group">
            <span>Account Name *</span>
            <input onChange={(e) => setName(e.target.value)} required value={name} />
          </label>

          <label className="field-group">
            <span>Sub-Type / Category</span>
            <input onChange={(e) => setSubType(e.target.value)} value={subType} />
          </label>

          <label className="field-group">
            <span>Description</span>
            <textarea onChange={(e) => setDescription(e.target.value)} rows={2} value={description} />
          </label>

          <label style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', cursor: 'pointer' }}>
            <input checked={isActive} onChange={(e) => setIsActive(e.target.checked)} type="checkbox" />
            <span>Account is Active</span>
          </label>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={!name || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Saving...' : 'Save Changes'}
          </Button>
        </footer>
      </div>
    </div>
  )
}

function SeedTemplateModal({
  onClose,
  onSuccess,
}: {
  onClose: () => void
  onSuccess: () => void
}) {
  const [industry, setIndustry] = useState('TRADING')

  const mutation = useMutation({
    mutationFn: () => seedTemplate(industry),
    onSuccess: () => onSuccess(),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog">
        <header className="modal-header">
          <h3>Seed Standard Chart of Accounts</h3>
          <Button onClick={onClose} variant="ghost">✕</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <p style={{ fontSize: '0.875rem', color: 'var(--color-text-muted)' }}>
            Automatically populate Indian standard statutory and operational Chart of Accounts tailored to your industry. Existing accounts will not be overwritten.
          </p>
          <label className="field-group">
            <span>Select Industry Template</span>
            <select onChange={(e) => setIndustry(e.target.value)} value={industry}>
              <option value="TRADING">General Trading / Wholesale & Retail</option>
              <option value="PHARMA">Pharmaceutical Distributor / Pharmacy</option>
              <option value="MANUFACTURING">Manufacturing & Assembly</option>
              <option value="SERVICES">Services & Professional Practice</option>
            </select>
          </label>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            <Sparkles className="icon" /> {mutation.isPending ? 'Seeding...' : 'Seed Accounts'}
          </Button>
        </footer>
      </div>
    </div>
  )
}

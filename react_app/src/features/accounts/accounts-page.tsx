import { useDeferredValue, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  BookOpen,
  Edit2,
  Plus,
  Sparkles,
  Trash2,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  CheckboxInput,
  DataTable,
  DirectoryToolbar,
  EmptyState,
  FilterTabs,
  FormField,
  FormGrid,
  Modal,
  Money,
  NumberInput,
  PageHeader,
  SearchInput,
  SelectInput,
  StatusChip,
  TablePagination,
  TextAreaInput,
  TextInput,
} from '@/design-system'
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
        <DirectoryToolbar ariaLabel="Filter chart of accounts by type and search" stacked>
          <FilterTabs
            activeValue={selectedTab}
            ariaLabel="Filter by account type"
            items={typeTabs.map((t) => ({
              value: t.value,
              label: t.label,
              count: t.value === 'ALL'
                ? allAccounts.length
                : allAccounts.filter((a) => a.type?.toUpperCase() === t.value).length,
            }))}
            onChange={(val) => {
              setSelectedTab(val);
              setPage(0);
            }}
          />
          <SearchInput
            ariaLabel="Search accounts"
            onChange={(val) => {
              setSearch(val);
              setPage(0);
            }}
            onClear={() => {
              setSearch('');
              setPage(0);
            }}
            placeholder="Search by account code, name, category..."
            value={search}
          />
        </DirectoryToolbar>

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

            <TablePagination
              filterDescription={deferredSearch ? 'matching this search' : selectedTab !== 'ALL' ? `in ${selectedTab.toLowerCase()}` : 'in total'}
              isFiltered={Boolean(deferredSearch || selectedTab !== 'ALL')}
              itemLabel="account"
              onPageChange={(p) => setPage(p)}
              page={page}
              totalElements={filteredAccounts.length}
              totalPages={totalPages}
            />
          </>
        ) : (
          <EmptyState
            action={
              <Button onClick={() => setShowCreateModal(true)} variant="primary">
                <Plus aria-hidden="true" size={16} />
                <span>New Account</span>
              </Button>
            }
            description={deferredSearch ? 'Try a different code, name, or classification.' : 'Seed standard industry accounts or create custom ledger accounts.'}
            icon={BookOpen}
            title="No accounts found."
          />
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
    <Modal
      footer={
        <>
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={!code || !name || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Creating...' : 'Create Account'}
          </Button>
        </>
      }
      isOpen
      onClose={onClose}
      size="lg"
      title="Create Ledger Account"
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        <FormGrid columns={2}>
          <FormField label="Account Code" required>
            <TextInput
              onChange={(e) => setCode(e.target.value)}
              placeholder="e.g. 1050"
              required
              value={code}
            />
          </FormField>
          <FormField label="Account Name" required>
            <TextInput
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. Petty Cash Bangalore"
              required
              value={name}
            />
          </FormField>
        </FormGrid>

        <FormGrid columns={2}>
          <FormField label="Account Type" required>
            <SelectInput
              onChange={(e) => setType(e.target.value as AccountType)}
              value={type}
            >
              <option value="ASSET">Asset</option>
              <option value="LIABILITY">Liability</option>
              <option value="EQUITY">Equity</option>
              <option value="REVENUE">Revenue</option>
              <option value="EXPENSE">Expense</option>
            </SelectInput>
          </FormField>
          <FormField label="Sub-Type / Category">
            <TextInput
              onChange={(e) => setSubType(e.target.value)}
              placeholder="e.g. Current Asset, Bank Account"
              value={subType}
            />
          </FormField>
        </FormGrid>

        <FormField label="Parent Account (Optional)">
          <SelectInput onChange={(e) => setParentId(e.target.value)} value={parentId}>
            <option value="">-- No Parent (Root Account) --</option>
            {accounts.map((a) => (
              <option key={a.id} value={a.id}>
                {a.code} - {a.name} ({a.type})
              </option>
            ))}
          </SelectInput>
        </FormField>

        <FormField label="Opening Balance (₹)">
          <NumberInput
            min={0}
            onChange={(e) => setOpeningBalance(e.target.value === '' ? '' : Number(e.target.value))}
            placeholder="0.00"
            step="0.01"
            value={openingBalance}
          />
        </FormField>

        <FormField label="Description / Narration">
          <TextAreaInput
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Account usage notes..."
            rows={2}
            value={description}
          />
        </FormField>
      </div>
    </Modal>
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
    <Modal
      footer={
        <>
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={!name || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Saving...' : 'Save Changes'}
          </Button>
        </>
      }
      isOpen
      onClose={onClose}
      size="md"
      title={`Edit Account (${account.code})`}
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        <FormField label="Account Name" required>
          <TextInput onChange={(e) => setName(e.target.value)} required value={name} />
        </FormField>

        <FormField label="Sub-Type / Category">
          <TextInput onChange={(e) => setSubType(e.target.value)} value={subType} />
        </FormField>

        <FormField label="Description">
          <TextAreaInput onChange={(e) => setDescription(e.target.value)} rows={2} value={description} />
        </FormField>

        <CheckboxInput
          checked={isActive}
          label="Account is Active"
          onChange={(e) => setIsActive(e.target.checked)}
        />
      </div>
    </Modal>
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
    <Modal
      footer={
        <>
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            <Sparkles className="icon" /> {mutation.isPending ? 'Seeding...' : 'Seed Accounts'}
          </Button>
        </>
      }
      isOpen
      onClose={onClose}
      size="md"
      title="Seed Standard Chart of Accounts"
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        <p style={{ fontSize: '0.875rem', color: 'var(--color-text-muted)' }}>
          Automatically populate Indian standard statutory and operational Chart of Accounts tailored to your industry. Existing accounts will not be overwritten.
        </p>
        <FormField label="Select Industry Template">
          <SelectInput onChange={(e) => setIndustry(e.target.value)} value={industry}>
            <option value="TRADING">General Trading / Wholesale & Retail</option>
            <option value="PHARMA">Pharmaceutical Distributor / Pharmacy</option>
            <option value="MANUFACTURING">Manufacturing & Assembly</option>
            <option value="SERVICES">Services & Professional Practice</option>
          </SelectInput>
        </FormField>
      </div>
    </Modal>
  )
}

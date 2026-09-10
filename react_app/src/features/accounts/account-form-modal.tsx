import { useState, type FormEvent } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Button, FormField, FormGrid, Modal, NumberInput, SelectInput, TextAreaInput, TextInput } from '@/design-system'
import { useSessionStore } from '@/shared/session/session-store'
import {
  createAccount,
  updateAccount,
  deleteAccount,
  activateAccount,
  deactivateAccount,
  type Account,
  type CreateAccountRequest,
  type UpdateAccountRequest,
} from './accounts-api'

const accountTypeOptions = [
  { label: 'Asset', value: 'ASSET' },
  { label: 'Liability', value: 'LIABILITY' },
  { label: 'Equity', value: 'EQUITY' },
  { label: 'Revenue', value: 'REVENUE' },
  { label: 'Expense', value: 'EXPENSE' },
]

export function AccountFormModal({
  account,
  parentAccounts = [],
  onClose,
  onSaved,
}: {
  account?: Account
  parentAccounts?: Account[]
  onClose: () => void
  onSaved: (account: Account) => void
}) {
  const role = useSessionStore((state) => state.user?.role) ?? ''
  const canManage = ['OWNER', 'ADMIN', 'ACCOUNTANT'].includes(role)
  const queryClient = useQueryClient()

  const [code, setCode] = useState(account?.code ?? '')
  const [name, setName] = useState(account?.name ?? '')
  const [type, setType] = useState<CreateAccountRequest['type']>(
    (account?.type?.toUpperCase() as CreateAccountRequest['type']) ?? 'ASSET'
  )
  const [subType, setSubType] = useState(account?.subType ?? '')
  const [parentCode, setParentCode] = useState(account?.parentId ?? '')
  const [description, setDescription] = useState(account?.description ?? '')
  const [openingBalance, setOpeningBalance] = useState<number>(Number(account?.openingBalance) || 0)
  const [error, setError] = useState('')

  const mutation = useMutation({
    mutationFn: async () => {
      if (account) {
        const updatePayload: UpdateAccountRequest = {
          name: name.trim(),
          subType: subType.trim() || null,
          description: description.trim() || null,
          openingBalance: openingBalance || 0,
        }
        return updateAccount(account.id, updatePayload)
      } else {
        const createPayload: CreateAccountRequest = {
          code: code.trim(),
          name: name.trim(),
          type,
          subType: subType.trim() || null,
          parentCode: parentCode.trim() || null,
          description: description.trim() || null,
          openingBalance: openingBalance || 0,
        }
        return createAccount(createPayload)
      }
    },
    onSuccess: (saved) => {
      void queryClient.invalidateQueries({ queryKey: ['accounts'] })
      onSaved(saved)
    },
    onError: (err: Error) => {
      setError(err.message || 'Failed to save account.')
    },
  })

  function handleSubmit(event: FormEvent) {
    event.preventDefault()
    if (!canManage || mutation.isPending) return

    if (!account && !code.trim()) {
      setError('Account code is required.')
      return
    }
    if (!name.trim()) {
      setError('Account name is required.')
      return
    }

    setError('')
    mutation.mutate()
  }

  return (
    <Modal
      isOpen
      size="lg"
      title={account ? `Edit Account: ${account.name}` : 'Create New Account'}
      onClose={() => {
        if (!mutation.isPending) onClose()
      }}
      error={error || mutation.error?.message}
      footer={
        <>
          <Button variant="secondary" disabled={mutation.isPending} onClick={onClose}>
            Cancel
          </Button>
          <Button
            type="submit"
            form="account-form"
            loading={mutation.isPending}
            disabled={!canManage || mutation.isPending}
          >
            {account ? 'Update Account' : 'Create Account'}
          </Button>
        </>
      }
    >
      <form id="account-form" onSubmit={handleSubmit} className="create-form-container">
        <FormGrid columns={2}>
          <FormField label="Account Code" required={!account}>
            <TextInput
              required={!account}
              maxLength={20}
              placeholder="e.g. 1010, 5020"
              value={code}
              onChange={(e) => setCode(e.target.value)}
              disabled={Boolean(account) || mutation.isPending}
            />
          </FormField>

          <FormField label="Account Name" required>
            <TextInput
              required
              maxLength={255}
              placeholder="e.g. Petty Cash, Office Supplies"
              value={name}
              onChange={(e) => setName(e.target.value)}
              disabled={mutation.isPending}
            />
          </FormField>

          <FormField label="Account Type" required={!account}>
            <SelectInput
              disabled={Boolean(account) || mutation.isPending}
              onChange={(e) => setType(e.target.value as CreateAccountRequest['type'])}
              options={accountTypeOptions}
              value={type}
            />
          </FormField>

          <FormField label="Category / Subtype">
            <TextInput
              maxLength={100}
              placeholder="e.g. Current Assets, Operating Expenses"
              value={subType}
              onChange={(e) => setSubType(e.target.value)}
              disabled={mutation.isPending}
            />
          </FormField>

          {!account && (
            <FormField label="Parent Account Code (Optional)">
              {parentAccounts.length > 0 ? (
                <SelectInput
                  disabled={mutation.isPending}
                  onChange={(e) => setParentCode(e.target.value)}
                  options={[
                    { label: 'None (Top level)', value: '' },
                    ...parentAccounts.map((pa) => ({
                      label: `${pa.code} - ${pa.name}`,
                      value: pa.code,
                    })),
                  ]}
                  value={parentCode}
                />
              ) : (
                <TextInput
                  placeholder="Parent account code if sub-account"
                  value={parentCode}
                  onChange={(e) => setParentCode(e.target.value)}
                  disabled={mutation.isPending}
                />
              )}
            </FormField>
          )}

          <FormField label="Opening Balance">
            <NumberInput
              value={openingBalance}
              onChange={(e) => setOpeningBalance(parseFloat(e.target.value) || 0)}
              disabled={mutation.isPending}
            />
          </FormField>
        </FormGrid>

        <FormField label="Description / Purpose" span="full">
          <TextAreaInput
            rows={3}
            placeholder="Optional account description or guidance for posting..."
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            disabled={mutation.isPending}
          />
        </FormField>
      </form>
    </Modal>
  )
}

export function AccountStatusModal({
  account,
  onClose,
  onUpdated,
}: {
  account: Account
  onClose: () => void
  onUpdated: () => void
}) {
  const queryClient = useQueryClient()
  const activate = !account.isActive

  const mutation = useMutation({
    mutationFn: () => (activate ? activateAccount(account.id) : deactivateAccount(account.id)),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['accounts'] })
      onUpdated()
    },
  })

  return (
    <Modal
      isOpen
      title={activate ? 'Activate Account' : 'Deactivate Account'}
      error={mutation.error?.message}
      onClose={() => {
        if (!mutation.isPending) onClose()
      }}
      footer={
        <>
          <Button variant="secondary" disabled={mutation.isPending} onClick={onClose}>
            Cancel
          </Button>
          <Button
            variant={activate ? 'primary' : 'destructive'}
            loading={mutation.isPending}
            onClick={() => mutation.mutate()}
          >
            Confirm {activate ? 'Activation' : 'Deactivation'}
          </Button>
        </>
      }
    >
      <p>
        Are you sure you want to {activate ? 'activate' : 'deactivate'} account{' '}
        <strong>{account.code} - {account.name}</strong>?
        {!activate && ' Inactive accounts cannot be selected for new transactions.'}
      </p>
    </Modal>
  )
}

export function AccountDeleteModal({
  account,
  onClose,
  onDeleted,
}: {
  account: Account
  onClose: () => void
  onDeleted: () => void
}) {
  const queryClient = useQueryClient()

  const mutation = useMutation({
    mutationFn: () => deleteAccount(account.id),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['accounts'] })
      onDeleted()
    },
  })

  return (
    <Modal
      isOpen
      title="Delete Account"
      error={mutation.error?.message}
      onClose={() => {
        if (!mutation.isPending) onClose()
      }}
      footer={
        <>
          <Button variant="secondary" disabled={mutation.isPending} onClick={onClose}>
            Keep Account
          </Button>
          <Button
            variant="destructive"
            loading={mutation.isPending}
            disabled={account.isSystem || account.isInvolvedInTransaction}
            onClick={() => mutation.mutate()}
          >
            Delete Account
          </Button>
        </>
      }
    >
      {account.isSystem ? (
        <p>System accounts cannot be deleted as they are required by ERP posting rules.</p>
      ) : account.isInvolvedInTransaction ? (
        <p>This account has posted transactions in the general ledger and cannot be deleted. Deactivate it instead.</p>
      ) : (
        <p>
          Are you sure you want to permanently delete account <strong>{account.code} - {account.name}</strong>?
        </p>
      )}
    </Modal>
  )
}

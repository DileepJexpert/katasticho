import { useState, type FormEvent } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Button, CheckboxInput, FormField, FormGrid, Modal, NumberInput, SelectInput, TextAreaInput, TextInput } from '@/design-system'
import { useSessionStore } from '@/shared/session/session-store'
import {
  createBankAccount,
  updateBankAccount,
  deleteBankAccount,
  type BankAccount,
  type BankAccountRequest,
} from './banking-api'

const accountTypeOptions = [
  { label: 'Current Account', value: 'CURRENT' },
  { label: 'Savings Account', value: 'SAVINGS' },
  { label: 'Overdraft Account', value: 'OVERDRAFT' },
  { label: 'Credit Card', value: 'CREDIT_CARD' },
]

export function BankAccountFormModal({
  account,
  onClose,
  onSaved,
}: {
  account?: BankAccount
  onClose: () => void
  onSaved: (account: BankAccount) => void
}) {
  const role = useSessionStore((state) => state.user?.role) ?? ''
  const canManage = ['OWNER', 'ADMIN', 'ACCOUNTANT'].includes(role)
  const queryClient = useQueryClient()

  const [name, setName] = useState(account?.name ?? '')
  const [bankName, setBankName] = useState(account?.bankName ?? '')
  const [accountNumber, setAccountNumber] = useState(account?.accountNumber ?? '')
  const [ifsc, setIfsc] = useState(account?.ifsc ?? '')
  const [branch, setBranch] = useState(account?.branch ?? '')
  const [accountType, setAccountType] = useState(account?.accountType ?? 'CURRENT')
  const [glAccountCode, setGlAccountCode] = useState(account?.glAccountCode ?? '')
  const [openingBalance, setOpeningBalance] = useState<number>(Number(account?.openingBalance) || 0)
  const [isDefault, setIsDefault] = useState(account?.isDefault ?? false)
  const [notes, setNotes] = useState(account?.notes ?? '')
  const [error, setError] = useState('')

  const mutation = useMutation({
    mutationFn: async () => {
      const payload: BankAccountRequest = {
        name: name.trim(),
        bankName: bankName.trim() || null,
        accountNumber: accountNumber.trim() || null,
        ifsc: ifsc.trim() || null,
        branch: branch.trim() || null,
        accountType,
        glAccountCode: glAccountCode.trim() || null,
        openingBalance: openingBalance || 0,
        isDefault,
        notes: notes.trim() || null,
      }
      return account ? updateBankAccount(account.id, payload) : createBankAccount(payload)
    },
    onSuccess: (saved) => {
      void queryClient.invalidateQueries({ queryKey: ['bank-accounts'] })
      onSaved(saved)
    },
    onError: (err: Error) => {
      setError(err.message || 'Failed to save bank account.')
    },
  })

  function handleSubmit(event: FormEvent) {
    event.preventDefault()
    if (!canManage || mutation.isPending) return

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
      title={account ? `Edit Bank Account: ${account.name}` : 'Add Bank Account'}
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
            form="bank-account-form"
            loading={mutation.isPending}
            disabled={!canManage || mutation.isPending}
          >
            {account ? 'Update Account' : 'Save Bank Account'}
          </Button>
        </>
      }
    >
      <form id="bank-account-form" onSubmit={handleSubmit} className="create-form-container">
        <FormGrid columns={2}>
          <FormField label="Account Display Name" required>
            <TextInput
              required
              maxLength={255}
              placeholder="e.g. HDFC Main Operating"
              value={name}
              onChange={(e) => setName(e.target.value)}
              disabled={mutation.isPending}
            />
          </FormField>

          <FormField label="Bank Name">
            <TextInput
              maxLength={100}
              placeholder="e.g. HDFC Bank, ICICI Bank"
              value={bankName}
              onChange={(e) => setBankName(e.target.value)}
              disabled={mutation.isPending}
            />
          </FormField>

          <FormField label="Account Number">
            <TextInput
              maxLength={50}
              placeholder="e.g. 50200012345678"
              value={accountNumber}
              onChange={(e) => setAccountNumber(e.target.value)}
              disabled={mutation.isPending}
            />
          </FormField>

          <FormField label="IFSC Code">
            <TextInput
              maxLength={20}
              placeholder="e.g. HDFC0001234"
              value={ifsc}
              onChange={(e) => setIfsc(e.target.value.toUpperCase())}
              disabled={mutation.isPending}
            />
          </FormField>

          <FormField label="Branch Name">
            <TextInput
              maxLength={100}
              placeholder="e.g. Koramangala Branch"
              value={branch}
              onChange={(e) => setBranch(e.target.value)}
              disabled={mutation.isPending}
            />
          </FormField>

          <FormField label="Account Type">
            <SelectInput
              disabled={mutation.isPending}
              onChange={(e) => setAccountType(e.target.value)}
              options={accountTypeOptions}
              value={accountType}
            />
          </FormField>

          <FormField label="GL Account Code (Optional)">
            <TextInput
              maxLength={20}
              placeholder="Leave blank to auto-create under 1020"
              value={glAccountCode}
              onChange={(e) => setGlAccountCode(e.target.value)}
              disabled={mutation.isPending}
            />
          </FormField>

          <FormField label="Opening Balance">
            <NumberInput
              value={openingBalance}
              onChange={(e) => setOpeningBalance(parseFloat(e.target.value) || 0)}
              disabled={mutation.isPending}
            />
          </FormField>
        </FormGrid>

        <CheckboxInput
          label="Set as default bank account for receipts and payments"
          checked={isDefault}
          onChange={(e) => setIsDefault(e.target.checked)}
          disabled={mutation.isPending}
        />

        <FormField label="Notes" span="full">
          <TextAreaInput
            rows={2}
            placeholder="Optional account notes or instructions..."
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            disabled={mutation.isPending}
          />
        </FormField>
      </form>
    </Modal>
  )
}

export function BankAccountDeleteModal({
  account,
  onClose,
  onDeleted,
}: {
  account: BankAccount
  onClose: () => void
  onDeleted: () => void
}) {
  const queryClient = useQueryClient()

  const mutation = useMutation({
    mutationFn: () => deleteBankAccount(account.id),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['bank-accounts'] })
      onDeleted()
    },
  })

  return (
    <Modal
      isOpen
      title="Remove Bank Account"
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
            variant="destructive"
            loading={mutation.isPending}
            disabled={account.isDefault}
            onClick={() => mutation.mutate()}
          >
            Confirm Delete
          </Button>
        </>
      }
    >
      {account.isDefault ? (
        <p>This is the default bank account for the organisation and cannot be deleted. Promote another account to default first.</p>
      ) : (
        <p>
          Are you sure you want to remove bank account <strong>{account.name}</strong> ({account.accountNumber ? `•••• ${account.accountNumber.slice(-4)}` : 'No A/c #'})?
        </p>
      )}
    </Modal>
  )
}

import { useQuery } from '@tanstack/react-query'
import { Button, EntityPicker } from '@/design-system'
import { listContacts, type Contact, type ContactFilter } from '@/features/contacts/contacts-api'
import { listOrgUsers, type OrgUser } from '@/features/settings/settings-api'
import { listBeats, type Beat } from './field-sales-api'

type PickerProps<T> = {
  value: T | null
  onChange: (value: T | null) => void
  disabled?: boolean
  id?: string
}

async function allBeats() {
  const first = await listBeats(0, 100)
  const beats = [...first.content]
  for (let page = 1; page < first.totalPages; page += 1) {
    beats.push(...(await listBeats(page, 100)).content)
  }
  return beats
}

async function searchContacts(search: string, filter: ContactFilter, preferredCategory?: string) {
  const contacts = (await listContacts({ filter, page: 0, search, size: 25 })).content
    .filter((contact) => contact.active)

  if (!preferredCategory) return contacts
  return contacts.sort((left, right) => {
    const leftPreferred = left.medicalCategory === preferredCategory ? 1 : 0
    const rightPreferred = right.medicalCategory === preferredCategory ? 1 : 0
    return rightPreferred - leftPreferred
  })
}

export function FieldSalespersonPicker({ value, onChange, disabled, id }: PickerProps<OrgUser>) {
  const users = useQuery({ queryKey: ['org-users'], queryFn: listOrgUsers })
  const options = (users.data ?? []).filter((user) => user.active)

  return (
    <>
      <EntityPicker<OrgUser>
        ariaLabel="Select salesperson"
        disabled={disabled || users.isPending || users.isError}
        getOptionDescription={(user) => `${user.email} / ${user.role}`}
        getOptionId={(user) => user.id}
        getOptionLabel={(user) => user.fullName || user.email}
        id={id}
        onChange={(_userId, user) => onChange(user ?? null)}
        options={options}
        placeholder="Search active organisation users"
        selectedEntity={value}
        value={value?.id ?? null}
      />
      {users.isError ? (
        <div role="alert">
          Salespeople could not be loaded.
          <Button disabled={disabled} onClick={() => void users.refetch()} variant="secondary">Retry</Button>
        </div>
      ) : null}
    </>
  )
}

export function FieldBeatPicker({ value, onChange, disabled, id }: PickerProps<Beat>) {
  const beats = useQuery({ queryKey: ['field-sales', 'beats', 'picker'], queryFn: allBeats })
  const options = (beats.data ?? []).filter((beat) => beat.isActive)

  return (
    <>
      <EntityPicker<Beat>
        ariaLabel="Select field sales beat"
        disabled={disabled || beats.isPending || beats.isError}
        getOptionDescription={(beat) => [beat.code, beat.area, beat.city].filter(Boolean).join(' / ')}
        getOptionId={(beat) => beat.id}
        getOptionLabel={(beat) => beat.name}
        id={id}
        onChange={(_beatId, beat) => onChange(beat ?? null)}
        options={options}
        placeholder="Search active beats"
        selectedEntity={value}
        value={value?.id ?? null}
      />
      {beats.isError ? (
        <div role="alert">
          Beats could not be loaded.
          <Button disabled={disabled} onClick={() => void beats.refetch()} variant="secondary">Retry</Button>
        </div>
      ) : null}
    </>
  )
}

export function FieldContactPicker({
  value,
  onChange,
  disabled,
  id,
  filter = 'CUSTOMER',
  preferredCategory,
  ariaLabel = 'Select field contact',
}: PickerProps<Contact> & {
  filter?: ContactFilter
  preferredCategory?: string
  ariaLabel?: string
}) {
  return (
    <EntityPicker<Contact>
      ariaLabel={ariaLabel}
      disabled={disabled}
      getOptionDescription={(contact) => [
        contact.companyName,
        contact.medicalCategory,
        contact.phone ?? contact.mobile,
        contact.gstin,
      ].filter(Boolean).join(' / ')}
      getOptionId={(contact) => contact.id}
      getOptionLabel={(contact) => contact.displayName}
      id={id}
      onChange={(_contactId, contact) => onChange(contact ?? null)}
      onSearch={(search) => searchContacts(search, filter, preferredCategory)}
      placeholder="Search name, company, phone, or GSTIN"
      selectedEntity={value}
      value={value?.id ?? null}
    />
  )
}

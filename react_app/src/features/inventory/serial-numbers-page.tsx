import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useSearchParams } from 'react-router-dom'
import {
  Button,
  DataTable,
  DirectoryToolbar,
  FormField,
  FormGrid,
  Modal,
  PageHeader,
  SearchInput,
  SelectInput,
  StatusChip,
  TextAreaInput,
} from '@/design-system'
import { getItem, type Item } from '@/features/items/items-api'
import { listWarehouses } from '@/features/warehouses/warehouses-api'
import { formatDateTime } from '@/shared/format/format'
import { useInventoryAccess } from './inventory-access'
import { InventoryItemPicker } from './inventory-pickers'
import {
  listAvailableSerials,
  listSerialNumbers,
  markSerialDamaged,
  markSerialReturned,
  receiveSerials,
  type SerialNumberRecord,
} from './serial-numbers-api'

export function SerialNumbersPage() {
  const [params] = useSearchParams()
  return <SerialNumbersWorkspace key={params.get('itemId') ?? ''} />
}

function SerialNumbersWorkspace() {
  const access = useInventoryAccess()
  const queryClient = useQueryClient()
  const [params, setParams] = useSearchParams()
  const itemId = params.get('itemId') ?? ''
  const [selectedItem, setSelectedItem] = useState<Item | null>(null)
  const [mode, setMode] = useState('all')
  const [warehouseId, setWarehouseId] = useState('')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(0)

  // Modals state
  const [isReceiveOpen, setIsReceiveOpen] = useState(false)
  const [selectedForDamage, setSelectedForDamage] = useState<SerialNumberRecord | null>(null)
  const [selectedForReturn, setSelectedForReturn] = useState<SerialNumberRecord | null>(null)
  const [receiveWarehouseId, setReceiveWarehouseId] = useState('')
  const [receiveSerialsText, setReceiveSerialsText] = useState('')
  const [damageNotes, setDamageNotes] = useState('')
  const [actionError, setActionError] = useState<string | null>(null)

  const item = useQuery({
    queryKey: ['items', itemId],
    queryFn: () => getItem(itemId),
    enabled: Boolean(itemId),
  })
  const warehouses = useQuery({ queryKey: ['warehouses'], queryFn: listWarehouses })
  const records = useQuery({
    queryKey: ['serial-numbers', itemId, page],
    queryFn: () => listSerialNumbers(itemId, page),
    enabled: Boolean(itemId) && mode === 'all',
  })
  const available = useQuery({
    queryKey: ['serial-numbers', 'available', itemId, warehouseId],
    queryFn: () => listAvailableSerials(itemId, warehouseId || undefined),
    enabled: Boolean(itemId) && mode === 'available',
  })

  const query = mode === 'all' ? records : available
  const allRows = mode === 'all' ? records.data?.content ?? [] : available.data ?? []
  const filtered = allRows.filter((record) =>
    record.serial.toLowerCase().includes(search.trim().toLowerCase())
  )
  const pages =
    mode === 'all'
      ? Math.max(1, records.data?.totalPages ?? 1)
      : Math.max(1, Math.ceil(filtered.length / 25))
  const currentPage = mode === 'all' ? page : Math.min(page, pages - 1)
  const visible =
    mode === 'all' ? filtered : filtered.slice(currentPage * 25, currentPage * 25 + 25)

  function changeItem(value: Item | null) {
    setSelectedItem(value)
    setPage(0)
    setSearch('')
    const next = new URLSearchParams(params)
    if (value) next.set('itemId', value.id)
    else next.delete('itemId')
    setParams(next)
  }

  function refreshSerials() {
    void queryClient.invalidateQueries({ queryKey: ['serial-numbers', itemId] })
    void queryClient.invalidateQueries({ queryKey: ['serial-numbers', 'available', itemId] })
  }

  const receiveMutation = useMutation({
    mutationFn: async () => {
      const serials = receiveSerialsText
        .split(/[\n,]+/)
        .map((s) => s.trim())
        .filter(Boolean)
      if (!serials.length) {
        throw new Error('Please enter at least one serial number.')
      }
      return receiveSerials({
        itemId,
        warehouseId: receiveWarehouseId || undefined,
        serials,
      })
    },
    onSuccess: () => {
      refreshSerials()
      setIsReceiveOpen(false)
      setReceiveSerialsText('')
      setActionError(null)
    },
    onError: (err: unknown) => {
      setActionError(err instanceof Error ? err.message : 'Failed to receive serial numbers.')
    },
  })

  const damageMutation = useMutation({
    mutationFn: async () => {
      if (!selectedForDamage) return
      return markSerialDamaged(selectedForDamage.id, damageNotes.trim() || undefined)
    },
    onSuccess: () => {
      refreshSerials()
      setSelectedForDamage(null)
      setDamageNotes('')
      setActionError(null)
    },
    onError: (err: unknown) => {
      setActionError(err instanceof Error ? err.message : 'Failed to mark serial damaged.')
    },
  })

  const returnMutation = useMutation({
    mutationFn: async () => {
      if (!selectedForReturn) return
      return markSerialReturned(selectedForReturn.id)
    },
    onSuccess: () => {
      refreshSerials()
      setSelectedForReturn(null)
      setActionError(null)
    },
    onError: (err: unknown) => {
      setActionError(err instanceof Error ? err.message : 'Failed to mark serial returned.')
    },
  })

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Traceability"
        title="Serial numbers"
        description="Review the serial register by item, availability and warehouse. Serial status is not an inventory balance."
      />
      <FormField label="Item">
        <InventoryItemPicker
          includeInactive
          onChange={changeItem}
          value={item.data ?? (selectedItem?.id === itemId ? selectedItem : null)}
        />
      </FormField>

      {item.isError && (
        <div role="alert">
          {item.error.message}
          <Button onClick={() => void item.refetch()} variant="secondary">
            Retry item
          </Button>
        </div>
      )}

      {!access.operate && (
        <p className="cell-muted">
          Read-only review. Receiving, sale assignment, damage and returns need a separately
          reviewed document/stock integration. An empty register does not prove whether serial
          tracking is enabled.
        </p>
      )}

      {!itemId ? (
        <p>Select an item to review its serial history.</p>
      ) : (
        <section className="list-panel">
          <DirectoryToolbar ariaLabel="Filter serial register">
            <SelectInput
              aria-label="Serial view"
              onChange={(event) => {
                setMode(event.target.value)
                setPage(0)
                setSearch('')
              }}
              options={[
                { value: 'all', label: 'All serial history' },
                { value: 'available', label: 'Available in stock' },
              ]}
              value={mode}
            />
            {mode === 'available' && (
              <SelectInput
                aria-label="Serial warehouse"
                onChange={(event) => {
                  setWarehouseId(event.target.value)
                  setPage(0)
                }}
                options={(warehouses.data ?? []).map((warehouse) => ({
                  value: warehouse.id,
                  label: warehouse.name,
                }))}
                placeholderOption="All warehouses"
                value={warehouseId}
              />
            )}
            <SearchInput
              onChange={(value) => {
                setSearch(value)
                if (mode === 'available') setPage(0)
              }}
              onClear={() => setSearch('')}
              placeholder={
                mode === 'all' ? 'Find serial on this page' : 'Find available serial'
              }
              value={search}
            />
            {access.operate && (
              <Button
                onClick={() => {
                  setActionError(null)
                  setIsReceiveOpen(true)
                }}
                variant="secondary"
              >
                Receive serials
              </Button>
            )}
          </DirectoryToolbar>

          {warehouses.isError && (
            <div role="alert">
              Warehouse labels unavailable.
              <Button onClick={() => void warehouses.refetch()} variant="secondary">
                Retry warehouses
              </Button>
            </div>
          )}

          {query.isError ? (
            <div role="alert">
              {query.error.message}
              <Button onClick={() => void query.refetch()} variant="secondary">
                Retry serials
              </Button>
            </div>
          ) : query.isPending ? (
            <p role="status">Loading serial numbers...</p>
          ) : (
            <>
              <DataTable caption="Serial number register">
                <thead>
                  <tr>
                    <th>Serial</th>
                    <th>Warehouse</th>
                    <th>Status</th>
                    <th>Received / sold</th>
                    <th>Source line references</th>
                    <th>Notes</th>
                    {access.operate && <th>Actions</th>}
                  </tr>
                </thead>
                <tbody>
                  {visible.map((record) => (
                    <tr key={record.id}>
                      <td>
                        <code>{record.serial}</code>
                      </td>
                      <td>
                        {warehouses.data?.find(
                          (warehouse) => warehouse.id === record.warehouseId
                        )?.name ??
                          record.warehouseId ??
                          '--'}
                      </td>
                      <td>
                        <StatusChip status={record.status} />
                      </td>
                      <td>
                        <div className="cell-stack">
                          <span>
                            {record.receivedAt ? formatDateTime(record.receivedAt) : '--'}
                          </span>
                          <span>{record.soldAt ? formatDateTime(record.soldAt) : '--'}</span>
                        </div>
                      </td>
                      <td>
                        <div className="cell-stack">
                          <code>Receipt: {record.receiptLineId ?? '--'}</code>
                          <code>Invoice: {record.invoiceLineId ?? '--'}</code>
                          <code>Batch: {record.batchId ?? '--'}</code>
                        </div>
                      </td>
                      <td>{record.notes ?? '--'}</td>
                      {access.operate && (
                        <td>
                          <div style={{ display: 'flex', gap: '6px' }}>
                            {record.status === 'IN_STOCK' && (
                              <Button
                                onClick={() => {
                                  setActionError(null)
                                  setDamageNotes('')
                                  setSelectedForDamage(record)
                                }}
                                variant="destructive"
                              >
                                Mark damaged
                              </Button>
                            )}
                            {record.status === 'SOLD' && (
                              <Button
                                onClick={() => {
                                  setActionError(null)
                                  setSelectedForReturn(record)
                                }}
                                variant="secondary"
                              >
                                Mark returned
                              </Button>
                            )}
                          </div>
                        </td>
                      )}
                    </tr>
                  ))}
                </tbody>
              </DataTable>
              {!visible.length && (
                <p>
                  No serial records match this view
                  {mode === 'all' && search ? ' on this page' : ''}.
                </p>
              )}
              <div className="document-actions">
                <Button
                  disabled={page === 0}
                  onClick={() => {
                    setPage(page - 1)
                    if (mode === 'all') setSearch('')
                  }}
                  variant="secondary"
                >
                  Previous serials
                </Button>
                <span>
                  Page {currentPage + 1} of {pages}
                </span>
                <Button
                  disabled={
                    mode === 'all'
                      ? records.data?.last !== false
                      : currentPage + 1 >= pages
                  }
                  onClick={() => {
                    setPage(page + 1)
                    if (mode === 'all') setSearch('')
                  }}
                  variant="secondary"
                >
                  Next serials
                </Button>
              </div>
            </>
          )}
        </section>
      )}

      {/* Receive Serials Modal */}
      {isReceiveOpen && (
        <Modal
          description="Register newly received serial numbers into stock."
          footer={
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', width: '100%' }}>
              <Button
                disabled={receiveMutation.isPending}
                onClick={() => setIsReceiveOpen(false)}
                variant="ghost"
              >
                Cancel
              </Button>
              <Button
                loading={receiveMutation.isPending}
                onClick={() => receiveMutation.mutate()}
                variant="primary"
              >
                Receive serials
              </Button>
            </div>
          }
          isOpen={isReceiveOpen}
          onClose={() => !receiveMutation.isPending && setIsReceiveOpen(false)}
          size="md"
          title="Receive serial numbers"
        >
          {actionError && (
            <div className="directory-state directory-state--error" role="alert" style={{ marginBottom: '12px' }}>
              {actionError}
            </div>
          )}
          <FormGrid columns={1}>
            <FormField label="Warehouse">
              <SelectInput
                aria-label="Target warehouse"
                onChange={(e) => setReceiveWarehouseId(e.target.value)}
                options={(warehouses.data ?? []).map((w) => ({ value: w.id, label: w.name }))}
                placeholderOption="Default warehouse"
                value={receiveWarehouseId}
              />
            </FormField>
            <FormField
              hint="Enter one serial number per line, or separate with commas."
              label="Serial numbers"
              required
            >
              <TextAreaInput
                aria-label="Serial numbers"
                onChange={(e) => setReceiveSerialsText(e.target.value)}
                placeholder={'SN-10001\nSN-10002\nSN-10003'}
                rows={5}
                value={receiveSerialsText}
              />
            </FormField>
          </FormGrid>
        </Modal>
      )}

      {/* Mark Damaged Modal */}
      {selectedForDamage && (
        <Modal
          description={`Mark serial ${selectedForDamage.serial} as damaged.`}
          footer={
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', width: '100%' }}>
              <Button
                disabled={damageMutation.isPending}
                onClick={() => setSelectedForDamage(null)}
                variant="ghost"
              >
                Cancel
              </Button>
              <Button
                loading={damageMutation.isPending}
                onClick={() => damageMutation.mutate()}
                variant="destructive"
              >
                Confirm damaged
              </Button>
            </div>
          }
          isOpen={Boolean(selectedForDamage)}
          onClose={() => !damageMutation.isPending && setSelectedForDamage(null)}
          size="sm"
          title={`Mark ${selectedForDamage.serial} damaged`}
        >
          {actionError && (
            <div className="directory-state directory-state--error" role="alert" style={{ marginBottom: '12px' }}>
              {actionError}
            </div>
          )}
          <FormField hint="Describe damage inspection or cause." label="Damage notes">
            <TextAreaInput
              aria-label="Damage notes"
              onChange={(e) => setDamageNotes(e.target.value)}
              placeholder="e.g. Scratched lens, failed internal diagnostic"
              rows={3}
              value={damageNotes}
            />
          </FormField>
        </Modal>
      )}

      {/* Mark Returned Modal */}
      {selectedForReturn && (
        <Modal
          description={`Customer return for serial ${selectedForReturn.serial}.`}
          footer={
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', width: '100%' }}>
              <Button
                disabled={returnMutation.isPending}
                onClick={() => setSelectedForReturn(null)}
                variant="ghost"
              >
                Cancel
              </Button>
              <Button
                loading={returnMutation.isPending}
                onClick={() => returnMutation.mutate()}
                variant="primary"
              >
                Confirm return
              </Button>
            </div>
          }
          isOpen={Boolean(selectedForReturn)}
          onClose={() => !returnMutation.isPending && setSelectedForReturn(null)}
          size="sm"
          title={`Return serial ${selectedForReturn.serial}`}
        >
          {actionError && (
            <div className="directory-state directory-state--error" role="alert" style={{ marginBottom: '12px' }}>
              {actionError}
            </div>
          )}
          <p>
            Are you sure you want to mark serial <strong>{selectedForReturn.serial}</strong> as
            returned? This removes the sale association and marks the serial as returned.
          </p>
        </Modal>
      )}
    </section>
  )
}

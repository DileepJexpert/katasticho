import { useEffect, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ChevronLeft, ChevronRight, ClipboardCheck, Plus, Trash2 } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  EmptyState,
  EntityPicker,
  FormCard,
  FormField,
  FormGrid,
  Modal,
  NumberInput,
  PageHeader,
  SelectInput,
  StatusChip,
  TextAreaInput,
  TextInput,
} from '@/design-system'
import { listItems, type Item } from '@/features/items/items-api'
import { listWarehouses } from '@/features/warehouses/warehouses-api'
import { formatDate, formatQuantity, formatStatusLabel } from '@/shared/format/format'
import {
  createStockCount,
  listStockCounts,
  type CreateStockCountRequest,
  type StockCount,
} from '@/features/stock-counts/stock-counts-api'

type CountLineDraft = {
  item: Item
  countedQuantity: string
  notes: string
}

function todayIso() {
  const date = new Date()
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}

function errorMessage(error: unknown, fallback: string) {
  return error instanceof Error && error.message ? error.message : fallback
}

export function StockCountsPage() {
  const [page, setPage] = useState(0)
  const [showCreateModal, setShowCreateModal] = useState(false)
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const counts = useQuery({
    queryKey: ['stock-counts', { page }],
    queryFn: () => listStockCounts(page),
  })
  const countPage = counts.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Audits"
        title="Physical Stock Counts"
        description="Record a warehouse count, review the server-calculated variance, then post one immutable stock adjustment per variance."
        actions={
          <Button onClick={() => setShowCreateModal(true)} variant="primary">
            <Plus size={16} /> New stock count
          </Button>
        }
      />

      <section className="list-panel" aria-label="Stock count directory">
        {counts.isError ? (
          <EmptyState
            action={<Button onClick={() => counts.refetch()} variant="secondary">Retry</Button>}
            className="directory-state--error"
            title="Stock counts could not be loaded"
            description="Check your connection and permissions, then try again."
          />
        ) : counts.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading stock counts...</div>
        ) : countPage?.content.length ? (
          <>
            <DataTable caption="Stock count register">
              <thead>
                <tr>
                  <th scope="col">Count #</th>
                  <th scope="col">Warehouse</th>
                  <th scope="col">Count date</th>
                  <th className="numeric-cell" scope="col">Lines</th>
                  <th className="numeric-cell" scope="col">Variances</th>
                  <th scope="col">Status</th>
                  <th scope="col"><span className="visually-hidden">Actions</span></th>
                </tr>
              </thead>
              <tbody>
                {countPage.content.map((count) => (
                  <StockCountRow
                    count={count}
                    key={count.id}
                    onOpen={() => navigate(appRoutes.stockCountDetail(count.id))}
                  />
                ))}
              </tbody>
            </DataTable>
            <footer className="table-footer">
              <span>{countPage.totalElements} count{countPage.totalElements === 1 ? '' : 's'} in this organisation</span>
              <div className="pagination-actions">
                <Button aria-label="Previous page" disabled={countPage.page === 0} onClick={() => setPage((current) => current - 1)} variant="ghost"><ChevronLeft aria-hidden="true" size={16} /></Button>
                <span>Page {countPage.page + 1} of {Math.max(countPage.totalPages, 1)}</span>
                <Button aria-label="Next page" disabled={countPage.last} onClick={() => setPage((current) => current + 1)} variant="ghost"><ChevronRight aria-hidden="true" size={16} /></Button>
              </div>
            </footer>
          </>
        ) : (
          <EmptyState
            action={<Button onClick={() => setShowCreateModal(true)} variant="secondary">Start a count</Button>}
            description="Choose a warehouse and enter the physical quantities for the items being audited."
            icon={ClipboardCheck}
            title="No stock counts recorded"
          />
        )}
      </section>

      <CreateStockCountModal
        isOpen={showCreateModal}
        onClose={() => setShowCreateModal(false)}
        onSuccess={(id) => {
          setShowCreateModal(false)
          queryClient.invalidateQueries({ queryKey: ['stock-counts'] })
          navigate(appRoutes.stockCountDetail(id))
        }}
      />
    </section>
  )
}

function StockCountRow({ onOpen, count }: { onOpen: () => void; count: StockCount }) {
  return (
    <tr>
      <td>
        <div className="item-primary">
          <span aria-hidden="true" className="item-avatar"><ClipboardCheck size={15} /></span>
          <strong>{count.countNumber}</strong>
        </div>
      </td>
      <td>{count.warehouseName ?? count.warehouseId}</td>
      <td>{formatDate(count.countDate)}</td>
      <td className="numeric-cell">{formatQuantity(count.lineCount)}</td>
      <td className="numeric-cell">{formatQuantity(count.varianceCount)}</td>
      <td><StatusChip status={formatStatusLabel(count.status)} /></td>
      <td><Button onClick={onOpen} variant="ghost">Open</Button></td>
    </tr>
  )
}

function CreateStockCountModal({
  isOpen,
  onClose,
  onSuccess,
}: {
  isOpen: boolean
  onClose: () => void
  onSuccess: (id: string) => void
}) {
  const [warehouseId, setWarehouseId] = useState('')
  const [countDate, setCountDate] = useState(todayIso)
  const [notes, setNotes] = useState('')
  const [lines, setLines] = useState<CountLineDraft[]>([])
  const [formError, setFormError] = useState<string | null>(null)
  const [itemPickerKey, setItemPickerKey] = useState(0)
  const warehouses = useQuery({ queryKey: ['warehouses'], queryFn: listWarehouses, enabled: isOpen })

  useEffect(() => {
    const activeWarehouses = (warehouses.data ?? []).filter((warehouse) => warehouse.active)
    if (!warehouseId && activeWarehouses.length === 1 && activeWarehouses[0]) {
      setWarehouseId(activeWarehouses[0].id)
    }
  }, [warehouseId, warehouses.data])

  useEffect(() => {
    if (isOpen) return
    setWarehouseId('')
    setCountDate(todayIso())
    setNotes('')
    setLines([])
    setFormError(null)
    setItemPickerKey(0)
  }, [isOpen])

  const createMutation = useMutation({
    mutationFn: (request: CreateStockCountRequest) => createStockCount(request),
    onSuccess: (count) => onSuccess(count.id),
    onError: (error) => setFormError(errorMessage(error, 'The stock count could not be created.')),
  })

  function closeModal() {
    if (createMutation.isPending) return
    setFormError(null)
    onClose()
  }

  function addItem(item: Item | null | undefined) {
    if (!item) return
    if (lines.some((line) => line.item.id === item.id)) {
      setFormError(`${item.name} is already included in this count.`)
      setItemPickerKey((current) => current + 1)
      return
    }

    setLines((previous) => [...previous, { item, countedQuantity: '', notes: '' }])
    setFormError(null)
    setItemPickerKey((current) => current + 1)
  }

  function updateLine(itemId: string, updates: Partial<CountLineDraft>) {
    setLines((previous) => previous.map((line) => line.item.id === itemId ? { ...line, ...updates } : line))
  }

  function submit() {
    setFormError(null)
    if (!warehouseId) {
      setFormError('Select the warehouse being physically counted.')
      return
    }
    if (!countDate) {
      setFormError('Enter the count date.')
      return
    }
    if (lines.length === 0) {
      setFormError('Add at least one item and enter its physical quantity.')
      return
    }

    const invalidLine = lines.find((line) => {
      const quantity = Number(line.countedQuantity)
      return line.countedQuantity.trim() === '' || !Number.isFinite(quantity) || quantity < 0
    })
    if (invalidLine) {
      setFormError(`Enter a zero or positive physical quantity for ${invalidLine.item.name}.`)
      return
    }

    createMutation.mutate({
      warehouseId,
      countDate,
      notes: notes.trim() || undefined,
      lines: lines.map((line) => ({
        itemId: line.item.id,
        countedQuantity: Number(line.countedQuantity),
        notes: line.notes.trim() || undefined,
      })),
    })
  }

  return (
    <Modal
      description="The server snapshots the warehouse balance and calculates each variance when this draft is created. A posted count cannot be edited."
      error={formError}
      footer={<><Button disabled={createMutation.isPending} onClick={closeModal} variant="secondary">Cancel</Button><Button loading={createMutation.isPending} onClick={submit} variant="primary">Create draft count</Button></>}
      isOpen={isOpen}
      onClose={closeModal}
      size="xl"
      title="New physical stock count"
    >
      <FormCard description="Choose the exact warehouse and day for this count sheet." stepNumber={1} title="Count details">
        <FormGrid columns={2}>
          <FormField error={warehouses.isError ? 'Warehouses could not be loaded.' : undefined} label="Warehouse" required>
            <SelectInput
              disabled={warehouses.isLoading || warehouses.isError}
              onChange={(event) => setWarehouseId(event.target.value)}
              options={(warehouses.data ?? []).filter((warehouse) => warehouse.active).map((warehouse) => ({ value: warehouse.id, label: `${warehouse.code} / ${warehouse.name}${warehouse.isDefault ? ' (default)' : ''}` }))}
              placeholderOption={warehouses.isLoading ? 'Loading warehouses...' : 'Select warehouse'}
              value={warehouseId}
            />
          </FormField>
          <FormField label="Count date" required>
            <TextInput onChange={(event) => setCountDate(event.target.value)} required type="date" value={countDate} />
          </FormField>
          <FormField label="Notes" optional span="full">
            <TextAreaInput onChange={(event) => setNotes(event.target.value)} placeholder="e.g. Month-end warehouse verification" rows={2} value={notes} />
          </FormField>
        </FormGrid>
      </FormCard>

      <FormCard description="Add each item being counted. Enter the actual physical quantity, including zero where no stock was found." stepNumber={2} title={`Physical quantities (${lines.length})`}>
        <FormField label="Add catalog item">
          <EntityPicker<Item>
            ariaLabel="Search items to add to stock count"
            getOptionDescription={(item) => [item.sku, item.unitOfMeasure, item.trackBatches ? 'Batch tracked' : 'Standard'].filter(Boolean).join(' / ')}
            getOptionId={(item) => item.id}
            getOptionLabel={(item) => item.name}
            key={itemPickerKey}
            onChange={(_id, item) => addItem(item)}
            onSearch={async (search) => (await listItems({ activeOnly: true, search, size: 20 })).content}
            placeholder="Search item name, SKU, or HSN"
            value={null}
          />
        </FormField>

        {lines.length ? (
          <DataTable caption="Physical stock count lines">
            <thead>
              <tr>
                <th scope="col">Item</th>
                <th className="numeric-cell" scope="col">Physical quantity</th>
                <th scope="col">Count note</th>
                <th scope="col"><span className="visually-hidden">Remove</span></th>
              </tr>
            </thead>
            <tbody>
              {lines.map((line) => (
                <tr key={line.item.id}>
                  <td>
                    <div className="cell-stack">
                      <strong>{line.item.name}</strong>
                      <span className="cell-muted">{[line.item.sku, line.item.unitOfMeasure].filter(Boolean).join(' / ') || 'No SKU or unit recorded'}</span>
                    </div>
                  </td>
                  <td className="numeric-cell">
                    <NumberInput
                      aria-label={`Physical quantity for ${line.item.name}`}
                      min="0"
                      onChange={(event) => updateLine(line.item.id, { countedQuantity: event.target.value })}
                      placeholder="0"
                      step="0.001"
                      value={line.countedQuantity}
                    />
                  </td>
                  <td>
                    <TextInput aria-label={`Count note for ${line.item.name}`} onChange={(event) => updateLine(line.item.id, { notes: event.target.value })} placeholder="Optional variance note" value={line.notes} />
                  </td>
                  <td><Button aria-label={`Remove ${line.item.name}`} onClick={() => setLines((previous) => previous.filter((entry) => entry.item.id !== line.item.id))} variant="ghost"><Trash2 size={15} /></Button></td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <EmptyState description="Search the item catalogue to add the first physical count line." icon={ClipboardCheck} title="No items selected" />
        )}
      </FormCard>
    </Modal>
  )
}

import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button, DataTable, DirectoryToolbar, DocumentCard, FilterTabs, FormField, Modal, Money, PageHeader, Quantity, StatusChip, TextInput } from '@/design-system'
import { useInventoryAccess } from '@/features/inventory/inventory-access'
import { invalidateInventoryQueries } from '@/features/inventory/inventory-cache'
import { listWarehouses } from '@/features/warehouses/warehouses-api'
import { formatPercent } from '@/shared/format/format'
import { downloadBlob } from '@/shared/files/download-blob'
import { useSessionStore } from '@/shared/session/session-store'
import { commitItemImport, downloadItemImportTemplate, previewItemImport, type ItemImportPreview, type ItemImportResult, type ItemImportRow } from './item-import-api'

export function ItemImportPage() {
  const access = useInventoryAccess()
  const orgId = useSessionStore((state) => state.user?.orgId)
  return access.operate ? <ItemImportWorkspace key={orgId} /> : <section className="workspace-page"><PageHeader title="Import items" /><p role="alert">Your role cannot import items.</p></section>
}

function ItemImportWorkspace() {
  const client = useQueryClient()
  const [file, setFile] = useState<File | null>(null)
  const [fileError, setFileError] = useState('')
  const [preview, setPreview] = useState<{ file: File; data: ItemImportPreview } | null>(null)
  const [result, setResult] = useState<ItemImportResult | null>(null)
  const [confirm, setConfirm] = useState(false)
  const [filter, setFilter] = useState('ALL')
  const [page, setPage] = useState(0)
  const warehouses = useQuery({ queryKey: ['warehouses'], queryFn: listWarehouses })
  const defaultWarehouse = warehouses.data?.find((warehouse) => warehouse.isDefault && warehouse.active)
  const template = useMutation({ mutationFn: downloadItemImportTemplate, onSuccess: (blob) => downloadBlob(blob, 'item_import_template.csv') })
  const validate = useMutation({
    mutationFn: previewItemImport,
    retry: false,
    onSuccess: (data, uploadedFile) => { setPreview({ file: uploadedFile, data }); setResult(null); setPage(0); setFilter('ALL') },
  })
  const save = useMutation({
    mutationFn: commitItemImport,
    retry: false,
    onSuccess: (data) => { setResult(data); setPreview(null); setConfirm(false); setFilter('ALL'); setPage(0) },
    onError: () => { setPreview(null); setConfirm(false) },
    onSettled: () => {
      void invalidateInventoryQueries(client)
      for (const key of ['financial-report', 'report-data', 'accounting-dashboard', 'dashboard', 'journals']) {
        void client.invalidateQueries({ queryKey: [key] })
      }
    },
  })
  const busy = validate.isPending || save.isPending
  const previewIssue = preview ? importPreviewIssue(preview.data) : null

  function selectFile(next: File | null) {
    if (busy) return
    setFile(next); setPreview(null); setResult(null); setPage(0); setFilter('ALL'); setConfirm(false)
    validate.reset(); save.reset()
    setFileError(next && !/\.(csv|xlsx)$/i.test(next.name) ? 'Select a CSV or XLSX file.' : next?.size === 0 ? 'The selected file is empty.' : '')
  }

  function previewFile() {
    if (!file || fileError || busy) return
    setPreview(null); setResult(null); save.reset()
    validate.mutate(file)
  }

  const rows: DisplayRow[] = result ? [
    ...result.successRows.map((row) => ({ ...row, outcome: 'CREATED', message: null })),
    ...result.failedRows.map((row) => ({ ...row, outcome: 'SKIPPED', message: row.errorMessage })),
  ].sort((a, b) => a.rowNumber - b.rowNumber) : (preview?.data.rows ?? []).map((row) => ({ ...row, outcome: row.status, message: row.error }))
  const filtered = filter === 'ERRORS' ? rows.filter((row) => row.outcome === 'ERROR' || row.outcome === 'SKIPPED') : rows
  const pages = Math.max(1, Math.ceil(filtered.length / 25))
  const currentPage = Math.min(page, pages - 1)

  return <section className="workspace-page">
    <PageHeader eyebrow="Inventory / Master data" title="Import items" description="Preview a CSV or XLSX file, review row errors, then explicitly commit the same file." actions={<>
      <Link className="button button--secondary" to={appRoutes.items}>Back to items</Link>
      <Button variant="secondary" disabled={template.isPending || busy} onClick={() => template.mutate()}>Download CSV template</Button>
    </>} />
    <p className="banner">Create-only import, not an update tool. Existing SKUs are skipped. Valid rows commit independently; a failed row does not roll back earlier successes. Opening stock is posted by the existing backend to the default warehouse.</p>
    <DocumentCard title="Upload and validate">
      <FormField label="Import file" required><TextInput type="file" accept=".csv,.xlsx" disabled={busy} onChange={(event) => selectFile(event.target.files?.[0] ?? null)} /></FormField>
      {file && <p className="cell-muted">Selected file: {file.name}</p>}
      <p className="cell-muted">Use the downloaded headers. The template includes a sample row; replace it before importing. The preview shows selected columns only; the entire original file, including batch and rack columns, is committed unchanged.</p>
      {fileError && <p role="alert">{fileError}</p>}
      {template.isError && <p role="alert">Template download failed: {template.error.message}</p>}
      {validate.isError && <p role="alert">Preview failed: {validate.error.message}</p>}
      {previewIssue && <p role="alert">{previewIssue} Correct the original file and preview it again; no import has been submitted.</p>}
      {save.isError && <div role="alert"><p>Import result could not be confirmed: {save.error.message}</p><p>Some rows may already have committed. Review the item directory, then preview the file again. Do not submit a blind retry.</p></div>}
      {warehouses.isError ? <div role="alert">Default warehouse could not be verified.<Button variant="secondary" onClick={() => void warehouses.refetch()}>Retry warehouses</Button></div>
        : warehouses.isPending ? <p role="status">Checking default warehouse...</p>
          : <p>{defaultWarehouse ? `Import warehouse: ${defaultWarehouse.name}` : 'Configure an active default warehouse before committing an import, including files with zero opening stock.'}</p>}
      <div className="document-actions">
        <Button variant="secondary" disabled={!file || Boolean(fileError) || busy} onClick={previewFile}>{validate.isPending ? 'Previewing file...' : 'Preview file'}</Button>
        <Button disabled={!preview || preview.file !== file || preview.data.validRows < 1 || Boolean(previewIssue) || !defaultWarehouse || warehouses.isError || busy || Boolean(result)} onClick={() => setConfirm(true)}>Review import</Button>
      </div>
    </DocumentCard>
    {(preview || result) && <section className="list-panel">
      <div className="document-actions" role="status">{result ? <span>Import result: {result.created} created, {result.skipped} skipped, {result.totalRows} total rows.</span> : <span>Preview only: {preview!.data.validRows} valid, {preview!.data.errorRows} errors, {preview!.data.totalRows} total rows. No items imported yet.</span>}</div>
      {result && <p className="cell-muted">Correct skipped rows in your original file and preview again. Success rows have no item IDs in this response; find them by SKU in the item directory.</p>}
      <DirectoryToolbar ariaLabel="Import row results"><FilterTabs ariaLabel="Import rows" activeValue={filter} onChange={(value) => { setFilter(value); setPage(0) }} items={[{ value: 'ALL', label: 'All rows', count: rows.length }, { value: 'ERRORS', label: result ? 'Skipped rows' : 'Errors', count: rows.filter((row) => row.outcome === 'ERROR' || row.outcome === 'SKIPPED').length }]} /></DirectoryToolbar>
      <ImportRows rows={filtered.slice(currentPage * 25, currentPage * 25 + 25)} />
      {!filtered.length && <p className="directory-state">No rows match this view.</p>}
      <div className="document-actions"><Button variant="secondary" disabled={currentPage === 0} onClick={() => setPage(currentPage - 1)}>Previous import rows</Button><span>Page {currentPage + 1} of {pages}</span><Button variant="secondary" disabled={currentPage + 1 >= pages} onClick={() => setPage(currentPage + 1)}>Next import rows</Button></div>
    </section>}
    <Modal isOpen={confirm} title="Commit item import" onClose={() => { if (!save.isPending) setConfirm(false) }} footer={<>
      <Button variant="secondary" disabled={save.isPending} onClick={() => setConfirm(false)}>Cancel</Button>
      <Button disabled={save.isPending || !preview || preview.file !== file || Boolean(previewIssue) || !defaultWarehouse} onClick={() => { if (preview && preview.file === file && !previewIssue && defaultWarehouse && !save.isPending) save.mutate(preview.file) }}>{save.isPending ? 'Importing...' : 'Import file'}</Button>
    </>}>
      <p>Import {preview?.file.name}? The preview currently contains {preview?.data.validRows} valid rows and {preview?.data.errorRows} errors.</p>
      <p>The server revalidates the complete file. Existing SKUs and invalid rows are skipped; final counts can differ from the preview. This is not an all-or-nothing transaction.</p>
      <p>Positive opening stock on goods creates stock movements in {defaultWarehouse?.name}. The existing backend also posts opening-stock accounting for positive inventory value. There is no automatic undo of the complete import.</p>
    </Modal>
  </section>
}

type DisplayRow = Pick<ItemImportRow, 'rowNumber' | 'sku' | 'name' | 'itemType' | 'purchasePrice' | 'salePrice' | 'openingStock'> & Partial<ItemImportRow> & { outcome: string; message: string | null }

function importPreviewIssue(preview: ItemImportPreview) {
  for (const row of preview.rows) {
    if (row.status === 'ERROR') continue
    if (row.status !== 'OK') return `Row ${row.rowNumber}: unrecognised preview status.`
    if (!['GOODS', 'SERVICE'].includes(row.itemType ?? '')) return `Row ${row.rowNumber}: this import supports goods and services only.`
    for (const [field, value] of Object.entries({ purchasePrice: row.purchasePrice, salePrice: row.salePrice, gstRate: row.gstRate, openingStock: row.openingStock })) {
      if (value != null && (!Number.isFinite(Number(value)) || Number(value) < 0)) return `Row ${row.rowNumber}: ${field} must be a non-negative number.`
    }
    if (row.itemType === 'SERVICE' && Number(row.openingStock) > 0) return `Row ${row.rowNumber}: services cannot receive opening stock.`
  }
  return null
}

function ImportRows({ rows }: { rows: DisplayRow[] }) {
  return <DataTable caption="Item import rows"><thead><tr><th>Row</th><th>SKU / item</th><th>Type / unit</th><th>HSN / GST</th><th className="numeric-cell">Purchase</th><th className="numeric-cell">Sale</th><th className="numeric-cell">Opening stock</th><th>Result</th><th>Validation / failure</th></tr></thead><tbody>{rows.map((row) => <tr key={row.rowNumber}>
    <td>{row.rowNumber}</td><td><div className="cell-stack"><code>{row.sku ?? '--'}</code><span>{row.name ?? '--'}</span></div></td>
    <td><div className="cell-stack"><span>{row.itemType ?? '--'}</span><span>{row.unitOfMeasure ?? '--'}</span></div></td>
    <td><div className="cell-stack"><code>{row.hsnCode ?? '--'}</code><span>{row.gstRate == null ? '--' : formatPercent(row.gstRate)}</span></div></td>
    <td className="numeric-cell">{row.purchasePrice == null ? '--' : <Money amount={row.purchasePrice} />}</td><td className="numeric-cell">{row.salePrice == null ? '--' : <Money amount={row.salePrice} />}</td>
    <td className="numeric-cell">{row.openingStock == null ? '--' : <Quantity value={row.openingStock} unit={row.unitOfMeasure} />}</td><td><StatusChip status={row.outcome} /></td><td>{row.message ?? '--'}</td>
  </tr>)}</tbody></DataTable>
}

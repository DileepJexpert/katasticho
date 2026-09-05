import { useEffect, useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Plus, Save, Trash2 } from 'lucide-react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  CheckboxInput,
  EntityPicker,
  FormCard,
  FormField,
  FormGrid,
  NumberInput,
  PageHeader,
  SelectInput,
  TextAreaInput,
  TextInput,
} from '@/design-system'
import { listContacts, type Contact } from '@/features/contacts/contacts-api'
import { getUoms } from '@/features/inventory/uoms-api'
import {
  createItem,
  getItem,
  updateItem,
  type CreateItemRequest,
  type Item,
  type ItemType,
  type UnitPriceEntry,
  type UpdateItemRequest,
} from '@/features/items/items-api'
import { listWarehouses } from '@/features/warehouses/warehouses-api'

type Feedback = { type: 'error' | 'success'; message: string }

type SecondaryUnitForm = {
  id: string
  uomAbbreviation: string
  conversionFactor: string
  customPrice: string
}

type ItemFormState = {
  sku: string
  name: string
  description: string
  itemType: ItemType
  category: string
  brand: string
  hsnCode: string
  unitOfMeasure: string
  purchasePrice: string
  salePrice: string
  mrp: string
  gstRate: string
  trackInventory: boolean
  trackBatches: boolean
  reorderLevel: string
  reorderQuantity: string
  barcode: string
  manufacturer: string
  preferredVendorId: string
  preferredVendorName: string
  purchaseUom: string
  purchaseUomConversion: string
  purchasePricePerUom: string
  secondaryUnits: SecondaryUnitForm[]
  openingStock: string
  openingWarehouseId: string
  openingBatchNumber: string
  openingMfgDate: string
  openingExpiryDate: string
  active: boolean
}

const itemTypeOptions = [
  { value: 'GOODS', label: 'Goods - stocked and sellable' },
  { value: 'SERVICE', label: 'Service - non-stocked' },
  { value: 'COMPOSITE', label: 'Composite - BOM kit' },
] as const

let secondaryUnitSequence = 0

function createBlankSecondaryUnit(): SecondaryUnitForm {
  secondaryUnitSequence += 1
  return {
    id: 'secondary-unit-' + secondaryUnitSequence,
    uomAbbreviation: '',
    conversionFactor: '',
    customPrice: '',
  }
}

function createBlankForm(): ItemFormState {
  return {
    sku: '',
    name: '',
    description: '',
    itemType: 'GOODS',
    category: '',
    brand: '',
    hsnCode: '',
    unitOfMeasure: 'PCS',
    purchasePrice: '',
    salePrice: '',
    mrp: '',
    gstRate: '18',
    trackInventory: true,
    trackBatches: false,
    reorderLevel: '',
    reorderQuantity: '',
    barcode: '',
    manufacturer: '',
    preferredVendorId: '',
    preferredVendorName: '',
    purchaseUom: '',
    purchaseUomConversion: '',
    purchasePricePerUom: '',
    secondaryUnits: [],
    openingStock: '',
    openingWarehouseId: '',
    openingBatchNumber: '',
    openingMfgDate: '',
    openingExpiryDate: '',
    active: true,
  }
}

function itemToForm(item: Item): ItemFormState {
  return {
    ...createBlankForm(),
    sku: item.sku ?? '',
    name: item.name,
    description: item.description ?? '',
    itemType: item.itemType as ItemType,
    category: item.category ?? '',
    brand: item.brand ?? '',
    hsnCode: item.hsnCode ?? '',
    unitOfMeasure: item.unitOfMeasure ?? 'PCS',
    purchasePrice: stringValue(item.purchasePrice),
    salePrice: stringValue(item.salePrice),
    mrp: stringValue(item.mrp),
    gstRate: stringValue(item.gstRate),
    trackInventory: item.trackInventory,
    trackBatches: item.trackBatches,
    reorderLevel: stringValue(item.reorderLevel),
    reorderQuantity: stringValue(item.reorderQuantity),
    barcode: item.barcode ?? '',
    manufacturer: item.manufacturer ?? '',
    preferredVendorId: item.preferredVendorId ?? '',
    preferredVendorName: item.preferredVendorName ?? '',
    purchaseUom: item.purchaseUom ?? '',
    purchaseUomConversion: stringValue(item.purchaseUomConversion),
    purchasePricePerUom: stringValue(item.purchasePricePerUom),
    secondaryUnits: (item.secondaryUnits ?? []).map((unit) => ({
      id: unit.uomId,
      uomAbbreviation: unit.uomAbbreviation,
      conversionFactor: stringValue(unit.conversionFactor),
      customPrice: stringValue(unit.customPrice),
    })),
    active: item.active,
  }
}

function stringValue(value: number | string | null | undefined) {
  return value === null || value === undefined ? '' : String(value)
}

function optionalText(value: string) {
  return value.trim() || undefined
}

function optionalNumber(value: string) {
  if (!value.trim()) return undefined
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : undefined
}

async function searchVendors(query: string) {
  const page = await listContacts({
    filter: 'VENDOR',
    page: 0,
    search: query,
    size: 25,
  })
  return page.content.filter((contact) => contact.active)
}

function describeVendor(contact: Contact) {
  return [contact.companyName, contact.gstin ? 'GSTIN ' + contact.gstin : null, contact.phone ?? contact.mobile]
    .filter(Boolean)
    .join(' / ')
}

export function ItemFormPage() {
  const { itemId } = useParams()
  const isEditing = Boolean(itemId)
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [form, setForm] = useState<ItemFormState>(createBlankForm)
  const [feedback, setFeedback] = useState<Feedback | null>(null)

  const itemQuery = useQuery({
    queryKey: ['items', itemId],
    queryFn: () => getItem(itemId!),
    enabled: isEditing,
  })
  const uomsQuery = useQuery({
    queryKey: ['uoms'],
    queryFn: () => getUoms(),
  })
  const warehousesQuery = useQuery({
    queryKey: ['warehouses'],
    queryFn: listWarehouses,
    enabled: !isEditing && form.trackInventory,
  })

  useEffect(() => {
    if (itemQuery.data) setForm(itemToForm(itemQuery.data))
  }, [itemQuery.data])

  useEffect(() => {
    if (form.itemType === 'GOODS') return
    setForm((current) => {
      if (!current.trackInventory && !current.trackBatches && !current.openingStock) return current
      return {
        ...current,
        trackInventory: false,
        trackBatches: false,
        openingStock: '',
        openingWarehouseId: '',
        openingBatchNumber: '',
        openingMfgDate: '',
        openingExpiryDate: '',
      }
    })
  }, [form.itemType])

  const saveMutation = useMutation({
    mutationFn: async (request: CreateItemRequest | UpdateItemRequest) => {
      if (isEditing) return updateItem(itemId!, request as UpdateItemRequest)
      return createItem(request as CreateItemRequest)
    },
    onSuccess: (item) => {
      queryClient.invalidateQueries({ queryKey: ['items'] })
      queryClient.invalidateQueries({ queryKey: ['shortbook'] })
      navigate(appRoutes.itemDetail(item.id))
    },
    onError: (error: unknown) => {
      setFeedback({
        type: 'error',
        message: error instanceof Error ? error.message : 'The item could not be saved.',
      })
    },
  })

  if (isEditing && itemQuery.isLoading) {
    return <section className="workspace-page"><div className="directory-state">Loading item for editing...</div></section>
  }

  if (isEditing && (itemQuery.isError || !itemQuery.data)) {
    return (
      <section className="workspace-page">
        <div className="directory-state directory-state--error" role="alert">
          <strong>Item details could not be loaded for editing.</strong>
          <Button onClick={() => navigate(appRoutes.items)} variant="secondary">Back to items</Button>
        </div>
      </section>
    )
  }

  const uomOptions = [
    { value: 'PCS', label: 'PCS - Pieces' },
    ...(uomsQuery.data ?? [])
      .filter((uom) => uom.active && uom.abbreviation.toUpperCase() !== 'PCS')
      .map((uom) => ({ value: uom.abbreviation, label: uom.abbreviation + ' - ' + uom.name })),
  ]
  const activeWarehouses = (warehousesQuery.data ?? []).filter((warehouse) => warehouse.active)
  const tracksStock = form.itemType === 'GOODS' && form.trackInventory
  const supportsBatchTracking = tracksStock

  function updateForm<K extends keyof ItemFormState>(key: K, value: ItemFormState[K]) {
    setForm((current) => ({ ...current, [key]: value }))
  }

  function updateSecondaryUnit(id: string, patch: Partial<SecondaryUnitForm>) {
    setForm((current) => ({
      ...current,
      secondaryUnits: current.secondaryUnits.map((unit) => unit.id === id ? { ...unit, ...patch } : unit),
    }))
  }

  function addSecondaryUnit() {
    setForm((current) => ({ ...current, secondaryUnits: [...current.secondaryUnits, createBlankSecondaryUnit()] }))
  }

  function removeSecondaryUnit(id: string) {
    setForm((current) => ({ ...current, secondaryUnits: current.secondaryUnits.filter((unit) => unit.id !== id) }))
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setFeedback(null)

    if (!form.name.trim()) {
      setFeedback({ type: 'error', message: 'Item name is required.' })
      return
    }
    if (isEditing && !form.sku.trim()) {
      setFeedback({ type: 'error', message: 'SKU is required when editing an item.' })
      return
    }

    const purchaseUomConversion = optionalNumber(form.purchaseUomConversion)
    if (form.purchaseUom && (!purchaseUomConversion || purchaseUomConversion <= 0)) {
      setFeedback({ type: 'error', message: 'Enter a purchase-unit conversion greater than zero.' })
      return
    }

    const secondaryUnits: UnitPriceEntry[] = []
    const secondaryUnitAbbreviations = new Set<string>()
    for (const unit of form.secondaryUnits) {
      const hasValues = Boolean(unit.uomAbbreviation || unit.conversionFactor || unit.customPrice)
      if (!hasValues) continue

      const conversionFactor = optionalNumber(unit.conversionFactor)
      if (!unit.uomAbbreviation || !conversionFactor || conversionFactor <= 0) {
        setFeedback({ type: 'error', message: 'Every additional unit needs a unit and a conversion greater than zero.' })
        return
      }
      if (unit.uomAbbreviation === form.unitOfMeasure || secondaryUnitAbbreviations.has(unit.uomAbbreviation)) {
        setFeedback({ type: 'error', message: 'Additional selling units must be distinct from the base unit and each other.' })
        return
      }
      secondaryUnitAbbreviations.add(unit.uomAbbreviation)
      secondaryUnits.push({
        uomAbbreviation: unit.uomAbbreviation,
        conversionFactor,
        customPrice: optionalNumber(unit.customPrice),
      })
    }

    const openingStock = optionalNumber(form.openingStock)
    if (!isEditing && openingStock !== undefined && openingStock < 0) {
      setFeedback({ type: 'error', message: 'Opening stock cannot be negative.' })
      return
    }
    if (!isEditing && openingStock && form.trackBatches && !form.openingBatchNumber.trim()) {
      setFeedback({ type: 'error', message: 'Batch number is required for opening stock on a batch-tracked item.' })
      return
    }

    const sharedFields = {
      name: form.name.trim(),
      description: optionalText(form.description),
      itemType: form.itemType,
      category: optionalText(form.category),
      brand: optionalText(form.brand),
      hsnCode: optionalText(form.hsnCode),
      unitOfMeasure: form.unitOfMeasure,
      purchasePrice: optionalNumber(form.purchasePrice),
      salePrice: optionalNumber(form.salePrice),
      mrp: optionalNumber(form.mrp),
      gstRate: optionalNumber(form.gstRate),
      trackInventory: tracksStock,
      trackBatches: supportsBatchTracking && form.trackBatches,
      reorderLevel: optionalNumber(form.reorderLevel),
      reorderQuantity: optionalNumber(form.reorderQuantity),
      barcode: optionalText(form.barcode),
      manufacturer: optionalText(form.manufacturer),
      preferredVendorId: optionalText(form.preferredVendorId),
      purchaseUom: optionalText(form.purchaseUom),
      purchaseUomConversion: form.purchaseUom ? purchaseUomConversion : undefined,
      purchasePricePerUom: form.purchaseUom ? optionalNumber(form.purchasePricePerUom) : undefined,
      secondaryUnits,
    }

    if (isEditing) {
      saveMutation.mutate({
        ...sharedFields,
        sku: form.sku.trim(),
        active: form.active,
      })
      return
    }

    saveMutation.mutate({
      ...sharedFields,
      sku: optionalText(form.sku),
      openingStock,
      openingWarehouseId: tracksStock ? optionalText(form.openingWarehouseId) : undefined,
      openingBatchNumber: tracksStock && form.trackBatches ? optionalText(form.openingBatchNumber) : undefined,
      openingMfgDate: tracksStock && form.trackBatches ? optionalText(form.openingMfgDate) : undefined,
      openingExpiryDate: tracksStock && form.trackBatches ? optionalText(form.openingExpiryDate) : undefined,
    })
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={isEditing ? appRoutes.itemDetail(itemId!) : appRoutes.items}>
        <ArrowLeft aria-hidden="true" size={16} />
        {isEditing ? 'Back to item' : 'Back to items'}
      </Link>

      <PageHeader
        eyebrow="Inventory / Master data"
        title={isEditing ? 'Edit item' : 'New item'}
        description={
          isEditing
            ? 'Maintain product, pricing, tax, unit, and inventory controls. Stock quantities stay in the audited stock ledger.'
            : 'Set commercial controls and optionally record the initial stock position as an audited opening movement.'
        }
      />

      {feedback && (
        <div className={'banner banner--' + feedback.type} role="alert">
          <span>{feedback.message}</span>
          <button aria-label="Dismiss message" className="banner-dismiss" onClick={() => setFeedback(null)} type="button">x</button>
        </div>
      )}

      <form className="create-form-container" onSubmit={handleSubmit}>
        <FormCard
          description="Identity, classification, GST, and the base unit used by stock and transaction lines."
          stepNumber={1}
          title="Product identity and tax"
        >
          <FormGrid columns={3}>
            <FormField label="Item name" required span={2}>
              <TextInput
                maxLength={255}
                onChange={(event) => updateForm('name', event.target.value)}
                placeholder="e.g. Turmeric Masala Test 100g"
                required
                value={form.name}
              />
            </FormField>
            <FormField
              hint={isEditing ? 'SKU cannot be blank after item creation.' : 'Leave blank to use the generated SKU.'}
              label="SKU"
              required={isEditing}
            >
              <TextInput
                maxLength={50}
                onChange={(event) => updateForm('sku', event.target.value)}
                placeholder="e.g. MASALA-TURMERIC-100G"
                required={isEditing}
                value={form.sku}
              />
            </FormField>
            <FormField label="Item type" required>
              <SelectInput
                onChange={(event) => updateForm('itemType', event.target.value as ItemType)}
                options={itemTypeOptions}
                required
                value={form.itemType}
              />
            </FormField>
            <FormField label="Base unit" required>
              <SelectInput
                onChange={(event) => updateForm('unitOfMeasure', event.target.value)}
                options={uomOptions}
                required
                value={form.unitOfMeasure}
              />
            </FormField>
            <FormField label="HSN code" hint="Up to 10 characters">
              <TextInput
                maxLength={10}
                onChange={(event) => updateForm('hsnCode', event.target.value)}
                placeholder="e.g. 0910"
                value={form.hsnCode}
              />
            </FormField>
            <FormField label="GST rate">
              <NumberInput
                min={0}
                onChange={(event) => updateForm('gstRate', event.target.value)}
                step="0.01"
                unitSuffix="%"
                value={form.gstRate}
              />
            </FormField>
            <FormField label="Category">
              <TextInput
                onChange={(event) => updateForm('category', event.target.value)}
                placeholder="e.g. Spices"
                value={form.category}
              />
            </FormField>
            <FormField label="Brand">
              <TextInput
                onChange={(event) => updateForm('brand', event.target.value)}
                placeholder="e.g. Katasticho Select"
                value={form.brand}
              />
            </FormField>
            <FormField label="Barcode">
              <TextInput
                maxLength={50}
                onChange={(event) => updateForm('barcode', event.target.value)}
                placeholder="Scan or enter barcode"
                value={form.barcode}
              />
            </FormField>
            <FormField label="Description" span="full">
              <TextAreaInput
                onChange={(event) => updateForm('description', event.target.value)}
                placeholder="Product details for purchasing, sales, and warehouse teams"
                rows={2}
                value={form.description}
              />
            </FormField>
          </FormGrid>
        </FormCard>

        <FormCard
          description="Default purchase and sale amounts are tax-exclusive values. Additional selling units can carry their own price."
          stepNumber={2}
          title="Pricing and units"
        >
          <FormGrid columns={3}>
            <FormField label="Purchase price">
              <NumberInput
                currencyPrefix
                min={0}
                onChange={(event) => updateForm('purchasePrice', event.target.value)}
                step="0.01"
                value={form.purchasePrice}
              />
            </FormField>
            <FormField label="Sale price">
              <NumberInput
                currencyPrefix
                min={0}
                onChange={(event) => updateForm('salePrice', event.target.value)}
                step="0.01"
                value={form.salePrice}
              />
            </FormField>
            <FormField label="MRP">
              <NumberInput
                currencyPrefix
                min={0}
                onChange={(event) => updateForm('mrp', event.target.value)}
                step="0.01"
                value={form.mrp}
              />
            </FormField>
            <FormField label="Purchase unit">
              <SelectInput
                onChange={(event) => updateForm('purchaseUom', event.target.value)}
                options={uomOptions}
                placeholderOption="Same as base unit"
                value={form.purchaseUom}
              />
            </FormField>
            <FormField
              hint={form.purchaseUom ? 'Base ' + form.unitOfMeasure + ' per purchase unit' : 'Choose a separate purchase unit first.'}
              label="Purchase conversion"
            >
              <NumberInput
                disabled={!form.purchaseUom}
                min="0.0001"
                onChange={(event) => updateForm('purchaseUomConversion', event.target.value)}
                step="0.0001"
                value={form.purchaseUomConversion}
              />
            </FormField>
            <FormField label="Price per purchase unit">
              <NumberInput
                currencyPrefix
                disabled={!form.purchaseUom}
                min={0}
                onChange={(event) => updateForm('purchasePricePerUom', event.target.value)}
                step="0.01"
                value={form.purchasePricePerUom}
              />
            </FormField>
          </FormGrid>
        </FormCard>

        <FormCard
          description="Optional pack, box, or other transaction units with a conversion and custom price."
          headerAction={
            <Button onClick={addSecondaryUnit} type="button" variant="secondary">
              <Plus aria-hidden="true" size={16} />
              Add unit
            </Button>
          }
          title="Additional selling units"
        >

          {form.secondaryUnits.length === 0 ? (
            <div className="directory-state">No additional selling units. The base unit price remains in use.</div>
          ) : (
            <div className="form-lines-card">
              <div className="form-lines-table-wrap">
                <table className="form-lines-table">
                  <thead>
                    <tr>
                      <th scope="col">Unit</th>
                      <th className="numeric-col" scope="col">Base-unit conversion</th>
                      <th className="numeric-col" scope="col">Custom sale price</th>
                      <th aria-label="Actions" className="action-col" scope="col" />
                    </tr>
                  </thead>
                  <tbody>
                    {form.secondaryUnits.map((unit) => (
                      <tr key={unit.id}>
                        <td>
                          <SelectInput
                            onChange={(event) => updateSecondaryUnit(unit.id, { uomAbbreviation: event.target.value })}
                            options={uomOptions}
                            placeholderOption="Select unit"
                            value={unit.uomAbbreviation}
                          />
                        </td>
                        <td className="numeric-col">
                          <NumberInput
                            min="0.0001"
                            onChange={(event) => updateSecondaryUnit(unit.id, { conversionFactor: event.target.value })}
                            step="0.0001"
                            value={unit.conversionFactor}
                          />
                        </td>
                        <td className="numeric-col">
                          <NumberInput
                            currencyPrefix
                            min={0}
                            onChange={(event) => updateSecondaryUnit(unit.id, { customPrice: event.target.value })}
                            step="0.01"
                            value={unit.customPrice}
                          />
                        </td>
                        <td className="action-col">
                          <Button aria-label="Remove additional unit" onClick={() => removeSecondaryUnit(unit.id)} type="button" variant="ghost">
                            <Trash2 aria-hidden="true" size={16} />
                          </Button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </FormCard>

       <FormCard
          description="Set replenishment thresholds, stock tracking, batch control, and the preferred purchasing partner."
          stepNumber={3}
          title="Inventory and purchasing controls"
        >
          <FormGrid columns={3}>
            <FormField label="Reorder level">
              <NumberInput
                disabled={!tracksStock}
                min={0}
                onChange={(event) => updateForm('reorderLevel', event.target.value)}
                step="0.01"
                unitSuffix={form.unitOfMeasure}
                value={form.reorderLevel}
              />
            </FormField>
            <FormField label="Reorder quantity">
              <NumberInput
                disabled={!tracksStock}
                min={0}
                onChange={(event) => updateForm('reorderQuantity', event.target.value)}
                step="0.01"
                unitSuffix={form.unitOfMeasure}
                value={form.reorderQuantity}
              />
            </FormField>
            <FormField label="Manufacturer">
              <TextInput
                onChange={(event) => updateForm('manufacturer', event.target.value)}
                placeholder="Optional manufacturer"
                value={form.manufacturer}
              />
            </FormField>
            <FormField hint="Only vendor-role contacts are selectable." label="Preferred vendor" span={2}>
              <EntityPicker<Contact>
                ariaLabel="Search preferred vendor"
                getOptionBadge={(vendor) => vendor.supplierEnabled ? 'Supplier' : 'Vendor'}
                getOptionDescription={describeVendor}
                getOptionId={(vendor) => vendor.id}
                getOptionLabel={(vendor) => vendor.displayName}
                onChange={(vendorId, vendor) => {
                  setForm((current) => ({
                    ...current,
                    preferredVendorId: vendorId ?? '',
                    preferredVendorName: vendor?.displayName ?? '',
                  }))
                }}
                onSearch={searchVendors}
                placeholder="Search vendor by name, company, phone, or GSTIN"
                selectedLabel={form.preferredVendorName || null}
                value={form.preferredVendorId || null}
              />
            </FormField>
          </FormGrid>

          <FormGrid columns={2}>
            <CheckboxInput
              checked={tracksStock}
              description={form.itemType === 'GOODS' ? 'Record stock movements, warehouse balances, and reorder alerts.' : 'Only goods can hold stock in this product model.'}
              disabled={form.itemType !== 'GOODS'}
              onChange={(event) => {
                const trackInventory = event.target.checked
                setForm((current) => ({
                  ...current,
                  trackInventory,
                  trackBatches: trackInventory ? current.trackBatches : false,
                }))
              }}
              title="Track inventory"
            />
            <CheckboxInput
              checked={supportsBatchTracking && form.trackBatches}
              description="Require batches on incoming and outgoing stock movements. Expiry is stored per batch."
              disabled={!supportsBatchTracking}
              onChange={(event) => updateForm('trackBatches', event.target.checked)}
              title="Track batches and expiry"
            />
          </FormGrid>
       </FormCard>

        {!isEditing && tracksStock && (
          <FormCard
            description="A positive quantity posts one OPENING stock movement and, if required, its opening batch. This cannot be edited later from the item form."
            stepNumber={4}
            title="Opening stock"
          >
            <FormGrid columns={3}>
              <FormField label={'Opening quantity (' + form.unitOfMeasure + ')'}>
                <NumberInput
                  min={0}
                  onChange={(event) => updateForm('openingStock', event.target.value)}
                  step="0.01"
                  value={form.openingStock}
                />
              </FormField>
              <FormField hint="Leave empty to use the organisation default warehouse." label="Opening warehouse" span={2}>
                <SelectInput
                  onChange={(event) => updateForm('openingWarehouseId', event.target.value)}
                  options={activeWarehouses.map((warehouse) => ({
                    value: warehouse.id,
                    label: warehouse.code + ' - ' + warehouse.name + (warehouse.isDefault ? ' (Default)' : ''),
                  }))}
                  placeholderOption={warehousesQuery.isLoading ? 'Loading warehouses...' : 'Use default warehouse'}
                  value={form.openingWarehouseId}
                />
              </FormField>
              {form.trackBatches && (
                <>
                  <FormField label="Opening batch number" required={Boolean(optionalNumber(form.openingStock))}>
                    <TextInput
                      maxLength={100}
                      onChange={(event) => updateForm('openingBatchNumber', event.target.value)}
                      placeholder="e.g. TUM-SEP-26-A"
                      value={form.openingBatchNumber}
                    />
                  </FormField>
                  <FormField label="Manufacturing date">
                    <TextInput
                      onChange={(event) => updateForm('openingMfgDate', event.target.value)}
                      type="date"
                      value={form.openingMfgDate}
                    />
                  </FormField>
                  <FormField label="Expiry date">
                    <TextInput
                      onChange={(event) => updateForm('openingExpiryDate', event.target.value)}
                      type="date"
                      value={form.openingExpiryDate}
                    />
                  </FormField>
                </>
              )}
            </FormGrid>
          </FormCard>
        )}

        {isEditing && (
          <FormCard
            description="Opening stock is locked after creation. Use a dedicated stock adjustment flow so every quantity change remains traceable in the stock ledger."
            stepNumber={4}
            title="Lifecycle and stock audit"
          >
            <CheckboxInput
              checked={form.active}
              description="Inactive items remain in historical documents but are excluded from active catalog selections."
              onChange={(event) => updateForm('active', event.target.checked)}
              title="Item is active"
            />
          </FormCard>
        )}

        <div className="form-actions-bar">
          <Button onClick={() => navigate(isEditing ? appRoutes.itemDetail(itemId!) : appRoutes.items)} type="button" variant="secondary">
            Cancel
          </Button>
          <Button disabled={saveMutation.isPending || !form.name.trim()} loading={saveMutation.isPending} type="submit">
            <Save aria-hidden="true" size={16} />
            {saveMutation.isPending ? 'Saving item...' : isEditing ? 'Save item' : 'Create item'}
          </Button>
        </div>
      </form>
    </section>
  )
}

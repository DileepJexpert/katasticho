import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  Play,
  PackageCheck,
  DollarSign,
  XCircle,
  ShieldAlert,
  Sparkles,
  CheckCircle2,
  FileCheck,
  FileText,
  AlertTriangle,
  Download,
  Plus,
} from 'lucide-react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { FormField } from '@/design-system/form-field'
import { FormGrid } from '@/design-system/form-grid'
import { Modal } from '@/design-system/modal'
import { NumberInput } from '@/design-system/number-input'
import { SelectInput } from '@/design-system/select-input'
import { TextAreaInput } from '@/design-system/textarea-input'
import { TextInput } from '@/design-system/text-input'
import { EntityPicker } from '@/design-system'
import { listItems, type Item } from '@/features/items/items-api'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatDateTime, formatStatusLabel } from '@/shared/format/format'
import {
  getJobCardsForWorkOrder,
  getWorkOrder,
  issueToProduction,
  receiveFinishedGoods,
  updateWorkOrderCosts,
  cancelWorkOrder,
  createSubAssemblyWos,
  listChildWorkOrders,
  getScrapForWorkOrder,
  startJobCard,
  completeJobCard,
  recordProductionScrap,
} from '@/features/work-orders/work-orders-api'
import {
  listBmrStepRecords,
  recordBmrStep,
  listBmrSignoffs,
  signoffBmr,
  listBmrDeviations,
  raiseBmrDeviation,
  resolveBmrDeviation,
  getYieldReconciliation,
  downloadBmrPdf,
} from '@/features/manufacturing/bmr-api'

export function WorkOrderDetailPage() {
  const { workOrderId, orderId } = useParams()
  const id = workOrderId || orderId
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  // Tab State
  const [activeTab, setActiveTab] = useState<'details' | 'bmr'>('details')
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; message: string } | null>(null)

  // Standard Modals
  const [isReceiveOpen, setIsReceiveOpen] = useState(false)
  const [receiveQty, setReceiveQty] = useState('100')
  const [batchNo, setBatchNo] = useState('')
  const [expiryDate, setExpiryDate] = useState('')

  const [isCostOpen, setIsCostOpen] = useState(false)
  const [laborCost, setLaborCost] = useState('500')
  const [overheadCost, setOverheadCost] = useState('200')

  const [isScrapOpen, setIsScrapOpen] = useState(false)
  const [selectedScrapItem, setSelectedScrapItem] = useState<Item | null>(null)
  const [scrapItemId, setScrapItemId] = useState('')
  const [scrapQty, setScrapQty] = useState('1')
  const [scrapNotes, setScrapNotes] = useState('')

  const [isCompleteJobCardOpen, setIsCompleteJobCardOpen] = useState(false)
  const [activeJobCardId, setActiveJobCardId] = useState<string | null>(null)
  const [jcCompletedQty, setJcCompletedQty] = useState('100')
  const [jcScrapQty, setJcScrapQty] = useState('0')
  const [jcTimeLogged, setJcTimeLogged] = useState(30)

  // BMR Modals
  const [isStepRecordOpen, setIsStepRecordOpen] = useState(false)
  const [bmrStepNum, setBmrStepNum] = useState(1)
  const [bmrOpName, setBmrOpName] = useState('Granulation & Blending')
  const [bmrParamName, setBmrParamName] = useState('Moisture Content (LOD)')
  const [bmrTargetVal, setBmrTargetVal] = useState('2.5')
  const [bmrMinVal, setBmrMinVal] = useState('2.0')
  const [bmrMaxVal, setBmrMaxVal] = useState('3.0')
  const [bmrMeasuredVal, setBmrMeasuredVal] = useState('2.45')
  const [bmrUnit, setBmrUnit] = useState('%')
  const [bmrStepNotes, setBmrStepNotes] = useState('')

  const [isSignoffOpen, setIsSignoffOpen] = useState(false)
  const [bmrStageName, setBmrStageName] = useState('Compression & In-Process Audit')
  const [bmrRole, setBmrRole] = useState('SUPERVISOR')
  const [bmrSignoffRemarks, setBmrSignoffRemarks] = useState('')

  const [isDeviationOpen, setIsDeviationOpen] = useState(false)
  const [devTitle, setDevTitle] = useState('')
  const [devSeverity, setDevSeverity] = useState('MAJOR')
  const [devDescription, setDevDescription] = useState('')
  const [devImmediateAction, setDevImmediateAction] = useState('')

  const [isResolveDevOpen, setIsResolveDevOpen] = useState(false)
  const [selectedDevId, setSelectedDevId] = useState<string | null>(null)
  const [devRootCause, setDevRootCause] = useState('')
  const [devCapPlan, setDevCapPlan] = useState('')
  const [devResolutionNotes, setDevResolutionNotes] = useState('')

  // Queries
  const workOrderQuery = useQuery({
    queryKey: ['work-orders', id],
    queryFn: () => getWorkOrder(id!),
    enabled: Boolean(id),
  })

  const jobCardsQuery = useQuery({
    queryKey: ['work-orders', id, 'job-cards'],
    queryFn: () => getJobCardsForWorkOrder(id!),
    enabled: Boolean(id),
  })

  const childrenQuery = useQuery({
    queryKey: ['work-orders', id, 'children'],
    queryFn: () => listChildWorkOrders(id!),
    enabled: Boolean(id),
  })

  const scrapQuery = useQuery({
    queryKey: ['work-orders', id, 'scrap'],
    queryFn: () => getScrapForWorkOrder(id!),
    enabled: Boolean(id),
  })

  // BMR Queries
  const bmrStepsQuery = useQuery({
    queryKey: ['bmr-steps', id],
    queryFn: () => listBmrStepRecords(id!),
    enabled: Boolean(id),
  })

  const bmrSignoffsQuery = useQuery({
    queryKey: ['bmr-signoffs', id],
    queryFn: () => listBmrSignoffs(id!),
    enabled: Boolean(id),
  })

  const bmrDeviationsQuery = useQuery({
    queryKey: ['bmr-deviations', id],
    queryFn: () => listBmrDeviations(id!),
    enabled: Boolean(id),
  })

  const yieldQuery = useQuery({
    queryKey: ['bmr-yield', id],
    queryFn: () => getYieldReconciliation(id!),
    enabled: Boolean(id),
  })

  // Standard Mutations
  const issueMutation = useMutation({
    mutationFn: () => issueToProduction(id!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['work-orders', id] })
      setFeedback({ type: 'success', message: 'Raw materials successfully issued to production floor.' })
    },
  })

  const receiveMutation = useMutation({
    mutationFn: () => receiveFinishedGoods(id!, {
      quantityReceived: Number(receiveQty),
      batchNumber: batchNo || undefined,
      expiryDate: expiryDate || undefined,
    }),
    onSuccess: () => {
      setIsReceiveOpen(false)
      queryClient.invalidateQueries({ queryKey: ['work-orders', id] })
      queryClient.invalidateQueries({ queryKey: ['bmr-yield', id] })
      setFeedback({ type: 'success', message: 'Finished goods batch successfully received into inventory.' })
    },
  })

  const costMutation = useMutation({
    mutationFn: () => updateWorkOrderCosts(id!, {
      directLaborCost: Number(laborCost),
      overheadCost: Number(overheadCost),
    }),
    onSuccess: () => {
      setIsCostOpen(false)
      queryClient.invalidateQueries({ queryKey: ['work-orders', id] })
      setFeedback({ type: 'success', message: 'Manufacturing direct labor and overhead costs updated.' })
    },
  })

  const cancelMutation = useMutation({
    mutationFn: () => cancelWorkOrder(id!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['work-orders', id] })
      setFeedback({ type: 'success', message: 'Work order cancelled.' })
    },
  })

  const cascadeSubAssembliesMutation = useMutation({
    mutationFn: () => createSubAssemblyWos(id!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['work-orders', id] })
      queryClient.invalidateQueries({ queryKey: ['work-orders', id, 'children'] })
      setFeedback({ type: 'success', message: 'Sub-assembly child work orders generated successfully.' })
    },
  })

  const startJcMutation = useMutation({
    mutationFn: (jcId: string) => startJobCard(jcId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['work-orders', id, 'job-cards'] })
      setFeedback({ type: 'success', message: 'Floor Job Card started.' })
    },
  })

  const completeJcMutation = useMutation({
    mutationFn: () => completeJobCard(activeJobCardId!, {
      completedQty: Number(jcCompletedQty),
      scrapQty: Number(jcScrapQty),
      timeLoggedMinutes: jcTimeLogged,
    }),
    onSuccess: () => {
      setIsCompleteJobCardOpen(false)
      queryClient.invalidateQueries({ queryKey: ['work-orders', id, 'job-cards'] })
      queryClient.invalidateQueries({ queryKey: ['work-orders', id] })
      setFeedback({ type: 'success', message: 'Job Card completed with logged quantities.' })
    },
  })

  const recordScrapMutation = useMutation({
    mutationFn: () => recordProductionScrap(id!, {
      itemId: scrapItemId,
      scrapQty: Number(scrapQty),
      notes: scrapNotes,
    }),
    onSuccess: () => {
      setIsScrapOpen(false)
      setSelectedScrapItem(null)
      setScrapItemId('')
      setScrapNotes('')
      queryClient.invalidateQueries({ queryKey: ['work-orders', id, 'scrap'] })
      queryClient.invalidateQueries({ queryKey: ['work-orders', id] })
      setFeedback({ type: 'success', message: 'Production scrap logged against work order.' })
    },
  })

  // BMR Mutations
  const recordStepMutation = useMutation({
    mutationFn: () => recordBmrStep({
      workOrderId: id!,
      stepNumber: bmrStepNum,
      operationName: bmrOpName,
      parameterName: bmrParamName,
      targetValue: bmrTargetVal,
      minValue: bmrMinVal,
      maxValue: bmrMaxVal,
      measuredValue: bmrMeasuredVal,
      unit: bmrUnit,
      notes: bmrStepNotes,
    }),
    onSuccess: () => {
      setIsStepRecordOpen(false)
      setBmrStepNotes('')
      queryClient.invalidateQueries({ queryKey: ['bmr-steps', id] })
      setFeedback({ type: 'success', message: 'GMP in-process parameter step recorded successfully.' })
    },
  })

  const signoffMutation = useMutation({
    mutationFn: () => signoffBmr({
      workOrderId: id!,
      stageName: bmrStageName,
      role: bmrRole,
      remarks: bmrSignoffRemarks,
    }),
    onSuccess: () => {
      setIsSignoffOpen(false)
      setBmrSignoffRemarks('')
      queryClient.invalidateQueries({ queryKey: ['bmr-signoffs', id] })
      setFeedback({ type: 'success', message: 'Stage sign-off approved and logged in BMR audit trail.' })
    },
  })

  const raiseDevMutation = useMutation({
    mutationFn: () => raiseBmrDeviation({
      workOrderId: id!,
      title: devTitle,
      severity: devSeverity,
      description: devDescription,
      immediateActionTaken: devImmediateAction,
    }),
    onSuccess: () => {
      setIsDeviationOpen(false)
      setDevTitle('')
      setDevDescription('')
      setDevImmediateAction('')
      queryClient.invalidateQueries({ queryKey: ['bmr-deviations', id] })
      setFeedback({ type: 'success', message: 'Deviation / OOS incident logged in BMR record.' })
    },
  })

  const resolveDevMutation = useMutation({
    mutationFn: () => resolveBmrDeviation(selectedDevId!, {
      rootCause: devRootCause,
      correctiveActionPlan: devCapPlan,
      resolutionNotes: devResolutionNotes,
    }),
    onSuccess: () => {
      setIsResolveDevOpen(false)
      setSelectedDevId(null)
      setDevRootCause('')
      setDevCapPlan('')
      setDevResolutionNotes('')
      queryClient.invalidateQueries({ queryKey: ['bmr-deviations', id] })
      setFeedback({ type: 'success', message: 'Deviation resolved with root cause & CAPA plan.' })
    },
  })

  const handleDownloadPdf = async () => {
    try {
      await downloadBmrPdf(id!)
      setFeedback({ type: 'success', message: 'Downloading WHO-GMP BMR Document PDF...' })
    } catch {
      setFeedback({ type: 'error', message: 'Failed to download BMR PDF.' })
    }
  }

  if (!id) return <div className="directory-state">No Work Order ID provided.</div>
  if (workOrderQuery.isLoading) return <div className="directory-state">Loading work order details...</div>
  if (workOrderQuery.isError || !workOrderQuery.data) {
    return (
      <div className="directory-state directory-state--error">
        <strong>Unable to load work order.</strong>
        <Button onClick={() => navigate('/work-orders')} variant="secondary">Back to work orders</Button>
      </div>
    )
  }

  const document = workOrderQuery.data
  const jobCards = jobCardsQuery.data ?? []
  const children = childrenQuery.data ?? []
  const scrapList = scrapQuery.data ?? []

  const bmrSteps = bmrStepsQuery.data ?? []
  const bmrSignoffs = bmrSignoffsQuery.data ?? []
  const bmrDeviations = bmrDeviationsQuery.data ?? []
  const bmrYield = yieldQuery.data

  const plannedNum = Number(document.quantityToProduce ?? 0)
  const producedNum = Number(document.quantityProduced ?? 0)
  const progressPct = plannedNum > 0 ? Math.min(100, Math.round((producedNum / plannedNum) * 100)) : 0

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Manufacturing / Work Orders"
        title={document.workOrderNumber}
        description={`Produce: ${document.finishedGoodName || `FG ${document.finishedGoodId.slice(0, 8)}`} · Target: ${document.quantityToProduce} units`}
        actions={
          <div className="table-actions">
            <span
              className={
                document.priority === 'URGENT'
                  ? 'status-badge status-badge--danger'
                  : document.priority === 'HIGH'
                  ? 'status-badge status-badge--warning'
                  : 'status-badge'
              }
            >
              {document.priority || 'NORMAL'}
            </span>
            <StatusChip status={formatStatusLabel(document.status)} />
          </div>
        }
      />

      {feedback && (
        <div className={`feedback-alert feedback-alert--${feedback.type}`} role="status">
          {feedback.type === 'success' ? <CheckCircle2 size={16} /> : <ShieldAlert size={16} />}
          <span>{feedback.message}</span>
          <button className="feedback-alert__close" onClick={() => setFeedback(null)} type="button">×</button>
        </div>
      )}

      <div className="document-actions">
        <Button onClick={() => navigate('/work-orders')} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to work orders
        </Button>

        {document.status === 'DRAFT' && (
          <>
            <Button
              disabled={issueMutation.isPending}
              onClick={() => issueMutation.mutate()}
              variant="primary"
            >
              <Play size={16} />
              Issue to Production
            </Button>
            <Button
              disabled={cascadeSubAssembliesMutation.isPending}
              onClick={() => cascadeSubAssembliesMutation.mutate()}
              variant="secondary"
            >
              <Sparkles size={16} />
              Cascade Sub-Assembly WOs
            </Button>
          </>
        )}

        {document.status === 'IN_PROGRESS' && (
          <>
            <Button onClick={() => setIsReceiveOpen(true)} variant="primary">
              <PackageCheck size={16} />
              Receive Finished Goods
            </Button>
            <Button onClick={() => setIsCostOpen(true)} variant="secondary">
              <DollarSign size={16} />
              Update Costs
            </Button>
            <Button onClick={() => setIsScrapOpen(true)} variant="secondary">
              <ShieldAlert size={16} />
              Record Scrap
            </Button>
          </>
        )}

        <Button onClick={handleDownloadPdf} variant="secondary">
          <Download size={16} />
          Export BMR PDF
        </Button>

        {document.status !== 'CANCELLED' && document.status !== 'COMPLETED' && (
          <Button
            disabled={cancelMutation.isPending}
            onClick={() => cancelMutation.mutate()}
            variant="destructive"
          >
            <XCircle size={16} />
            Cancel Work Order
          </Button>
        )}
      </div>

      <div className="list-tabs" role="tablist" style={{ marginTop: '16px', marginBottom: '16px' }}>
        <button
          aria-selected={activeTab === 'details'}
          className={activeTab === 'details' ? 'list-tab list-tab--active' : 'list-tab'}
          onClick={() => setActiveTab('details')}
          role="tab"
          type="button"
        >
          <FileText size={15} style={{ marginRight: '6px' }} />
          Production & BOM Overview
        </button>
        <button
          aria-selected={activeTab === 'bmr'}
          className={activeTab === 'bmr' ? 'list-tab list-tab--active' : 'list-tab'}
          onClick={() => setActiveTab('bmr')}
          role="tab"
          type="button"
        >
          <FileCheck size={15} style={{ marginRight: '6px' }} />
          Pharma BMR & Quality Records ({bmrSteps.length} params · {bmrSignoffs.length} signoffs)
        </button>
      </div>

      {activeTab === 'details' && (
        <>
          <div className="document-layout">
            <section className="document-card">
              <h2>Production Order Facts</h2>
              <dl className="document-facts">
                <div className="document-fact"><dt>Finished Good</dt><dd>{document.finishedGoodName || document.finishedGoodId}</dd></div>
                <div className="document-fact"><dt>Target Quantity</dt><dd><Quantity unit="units" value={document.quantityToProduce} /></dd></div>
                <div className="document-fact"><dt>BOM Version</dt><dd>{document.bomVersion ? `Version ${document.bomVersion}` : 'Default active BOM'}</dd></div>
                <div className="document-fact"><dt>Backflush Mode</dt><dd>{document.backflushMode ? 'Enabled' : 'Manual RM Issue'}</dd></div>
                <div className="document-fact"><dt>Order Type</dt><dd>{document.disassembly ? 'Disassembly Order' : 'Standard Build Order'}</dd></div>
                <div className="document-fact"><dt>Timeline</dt><dd>{document.plannedStartDate ? formatDate(document.plannedStartDate) : 'Open'} → {document.plannedEndDate ? formatDate(document.plannedEndDate) : 'Open'}</dd></div>
                <div className="document-fact"><dt>Approval Status</dt><dd>{document.approvalStatus || 'None'}</dd></div>
              </dl>
            </section>

            <aside className="document-card document-card--summary">
              <h2>Production & Cost Summary</h2>
              <div className="progress-row">
                <span>Progress ({progressPct}%)</span>
                <strong>{producedNum} / {plannedNum} units</strong>
              </div>
              <div className="progress-row">
                <span>Scrap Loss</span>
                <span className={Number(document.scrapQty) > 0 ? 'text-danger' : undefined}>
                  <Quantity unit="units" value={document.scrapQty ?? 0} />
                </span>
              </div>
              <div className="progress-row">
                <span>Raw Material Cost</span>
                <Money amount={document.rawMaterialCost} />
              </div>
              <div className="progress-row">
                <span>Direct Labor Cost</span>
                <Money amount={document.directLaborCost} />
              </div>
              <div className="progress-row">
                <span>Overhead Cost</span>
                <Money amount={document.overheadCost} />
              </div>
              <div className="progress-row progress-row--total">
                <span>Total Production Cost</span>
                <Money amount={document.totalCost} />
              </div>
              <div className="progress-row">
                <span>Estimated Unit Cost</span>
                <Money amount={document.unitCost} />
              </div>
            </aside>
          </div>

          <section className="document-card document-card--lines" style={{ marginTop: '16px' }}>
            <h2>BOM Component Requirements & Issues</h2>
            {document.lines && document.lines.length > 0 ? (
              <DataTable caption="BOM raw material items required for assembly">
                <thead>
                  <tr>
                    <th scope="col">Component Item</th>
                    <th className="numeric-cell" scope="col">Required Qty</th>
                    <th className="numeric-cell" scope="col">Issued Qty</th>
                    <th className="numeric-cell" scope="col">Unit Cost</th>
                    <th className="numeric-cell" scope="col">Total Cost</th>
                  </tr>
                </thead>
                <tbody>
                  {document.lines.map((line) => (
                    <tr key={line.id}>
                      <td>{line.itemName || line.itemId}</td>
                      <td className="numeric-cell"><Quantity unit={line.uom || 'units'} value={line.requiredQuantity} /></td>
                      <td className="numeric-cell"><Quantity unit={line.uom || 'units'} value={line.issuedQuantity} /></td>
                      <td className="numeric-cell"><Money amount={line.unitCost} /></td>
                      <td className="numeric-cell"><Money amount={line.totalCost} /></td>
                    </tr>
                  ))}
                </tbody>
              </DataTable>
            ) : (
              <p className="empty-message">No bill of materials components attached to this order.</p>
            )}
          </section>

          <section className="document-card" style={{ marginTop: '16px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
              <h2>Floor Job Cards ({jobCards.length})</h2>
            </div>
            {jobCards.length > 0 ? (
              <DataTable caption="Routing operations and job cards">
                <thead>
                  <tr>
                    <th scope="col">Job Card #</th>
                    <th scope="col">Operation</th>
                    <th scope="col">Workstation</th>
                    <th scope="col">Status</th>
                    <th className="numeric-cell" scope="col">Completed Qty</th>
                    <th scope="col">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {jobCards.map((jc) => (
                    <tr key={jc.id}>
                      <td className="cell-id">{jc.jobCardNumber}</td>
                      <td>{jc.operationName} (Seq {jc.sequence})</td>
                      <td>{jc.workstationName || jc.workstationId || 'Floor Workstation'}</td>
                      <td><StatusChip status={formatStatusLabel(jc.status)} /></td>
                      <td className="numeric-cell"><Quantity unit="units" value={jc.completedQty} /></td>
                      <td>
                        {jc.status === 'PENDING' && (
                          <Button
                            disabled={startJcMutation.isPending}
                            onClick={() => startJcMutation.mutate(jc.id)}
                            variant="secondary"
                          >
                            <Play size={14} />
                            Start Operation
                          </Button>
                        )}
                        {jc.status === 'IN_PROGRESS' && (
                          <Button
                            onClick={() => {
                              setActiveJobCardId(jc.id)
                              setJcCompletedQty(String(document.quantityToProduce))
                              setIsCompleteJobCardOpen(true)
                            }}
                            variant="primary"
                          >
                            <CheckCircle2 size={14} />
                            Complete Job Card
                          </Button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </DataTable>
            ) : (
              <p className="empty-message">No floor job cards generated for this work order.</p>
            )}
          </section>

          {children.length > 0 && (
            <section className="document-card" style={{ marginTop: '16px' }}>
              <h2>Sub-Assembly Child Work Orders ({children.length})</h2>
              <DataTable caption="Child sub-assembly work orders">
                <thead>
                  <tr>
                    <th scope="col">Order #</th>
                    <th scope="col">Sub-Assembly Item</th>
                    <th className="numeric-cell" scope="col">Target Qty</th>
                    <th className="numeric-cell" scope="col">Produced Qty</th>
                    <th scope="col">Status</th>
                    <th scope="col">Action</th>
                  </tr>
                </thead>
                <tbody>
                  {children.map((c) => (
                    <tr key={c.id}>
                      <td className="cell-id">{c.workOrderNumber}</td>
                      <td>{c.finishedGoodName || c.finishedGoodId}</td>
                      <td className="numeric-cell"><Quantity unit="units" value={c.quantityToProduce} /></td>
                      <td className="numeric-cell"><Quantity unit="units" value={c.quantityProduced} /></td>
                      <td><StatusChip status={formatStatusLabel(c.status)} /></td>
                      <td>
                        <Link to={`/work-orders/${c.id}`}>
                          <Button variant="ghost">View WO</Button>
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </DataTable>
            </section>
          )}

          {scrapList.length > 0 && (
            <section className="document-card" style={{ marginTop: '16px' }}>
              <h2>Production Scrap & Wastage Log</h2>
              <DataTable caption="Logged scrap records">
                <thead>
                  <tr>
                    <th scope="col">Item</th>
                    <th className="numeric-cell" scope="col">Scrap Qty</th>
                    <th className="numeric-cell" scope="col">Scrap Cost</th>
                    <th scope="col">Notes</th>
                    <th scope="col">Logged Date</th>
                  </tr>
                </thead>
                <tbody>
                  {scrapList.map((s) => (
                    <tr key={s.id}>
                      <td>{s.itemName || s.itemId}</td>
                      <td className="numeric-cell"><Quantity unit="units" value={s.scrapQty} /></td>
                      <td className="numeric-cell"><Money amount={s.scrapCost} /></td>
                      <td>{s.notes || '—'}</td>
                      <td>{s.createdAt ? formatDate(s.createdAt) : '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </DataTable>
            </section>
          )}
        </>
      )}

      {activeTab === 'bmr' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          {/* Yield Reconciliation Card */}
          <section className="document-card">
            <h2>Batch Yield & Material Reconciliation (WHO-GMP Compliance)</h2>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px', marginTop: '12px' }}>
              <div style={{ background: 'var(--bg-subtle)', padding: '12px 16px', borderRadius: '6px' }}>
                <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Theoretical Yield</span>
                <div style={{ fontSize: '18px', fontWeight: 600, marginTop: '4px' }}>
                  <Quantity unit="units" value={bmrYield?.theoreticalYield ?? document.quantityToProduce} />
                </div>
              </div>
              <div style={{ background: 'var(--bg-subtle)', padding: '12px 16px', borderRadius: '6px' }}>
                <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Actual Produced Yield</span>
                <div style={{ fontSize: '18px', fontWeight: 600, marginTop: '4px' }}>
                  <Quantity unit="units" value={bmrYield?.actualYield ?? document.quantityProduced} />
                </div>
              </div>
              <div style={{ background: 'var(--bg-subtle)', padding: '12px 16px', borderRadius: '6px' }}>
                <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Reconciliation Recovery %</span>
                <div style={{ fontSize: '18px', fontWeight: 600, marginTop: '4px', color: (bmrYield?.yieldPercentage ?? progressPct) >= 95 ? 'var(--color-success)' : 'var(--color-warning)' }}>
                  {(bmrYield?.yieldPercentage ?? progressPct).toFixed(1)}%
                </div>
              </div>
              <div style={{ background: 'var(--bg-subtle)', padding: '12px 16px', borderRadius: '6px' }}>
                <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Standard Yield Acceptance Limit</span>
                <div style={{ fontSize: '18px', fontWeight: 600, marginTop: '4px' }}>
                  {bmrYield?.minAcceptableYieldPercentage ?? 95.0}% - {bmrYield?.maxAcceptableYieldPercentage ?? 102.0}%
                </div>
              </div>
            </div>
          </section>

          {/* In-Process Step Records */}
          <section className="document-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
              <div>
                <h2>In-Process Parameter Records ({bmrSteps.length})</h2>
                <p style={{ fontSize: '13px', color: 'var(--text-muted)', margin: 0 }}>
                  Critical control parameters recorded during batch manufacturing stages.
                </p>
              </div>
              <Button onClick={() => setIsStepRecordOpen(true)} variant="secondary">
                <Plus size={16} />
                Record Parameter
              </Button>
            </div>
            {bmrSteps.length > 0 ? (
              <DataTable caption="BMR in-process parameter checks">
                <thead>
                  <tr>
                    <th scope="col">Step #</th>
                    <th scope="col">Operation</th>
                    <th scope="col">Parameter</th>
                    <th className="numeric-cell" scope="col">Target</th>
                    <th className="numeric-cell" scope="col">Min - Max Limit</th>
                    <th className="numeric-cell" scope="col">Measured Value</th>
                    <th scope="col">Recorded At</th>
                  </tr>
                </thead>
                <tbody>
                  {bmrSteps.map((s) => (
                    <tr key={s.id}>
                      <td className="cell-id">Step {s.stepNumber}</td>
                      <td>{s.operationName}</td>
                      <td><strong>{s.parameterName}</strong></td>
                      <td className="numeric-cell">{s.targetValue} {s.unit}</td>
                      <td className="numeric-cell">{s.minValue} - {s.maxValue} {s.unit}</td>
                      <td className="numeric-cell" style={{ fontWeight: 600, color: 'var(--color-primary)' }}>
                        {s.measuredValue} {s.unit}
                      </td>
                      <td>{s.createdAt ? formatDateTime(s.createdAt) : '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </DataTable>
            ) : (
              <p className="empty-message">No in-process parameter steps recorded yet.</p>
            )}
          </section>

          {/* Supervisor & QA Signoffs */}
          <section className="document-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
              <div>
                <h2>Stage Approvals & QA Sign-Offs ({bmrSignoffs.length})</h2>
                <p style={{ fontSize: '13px', color: 'var(--text-muted)', margin: 0 }}>
                  Multi-tier digital signoffs required by GMP / 21 CFR Part 11 before batch release.
                </p>
              </div>
              <Button onClick={() => setIsSignoffOpen(true)} variant="secondary">
                <FileCheck size={16} />
                Sign Off Stage
              </Button>
            </div>
            {bmrSignoffs.length > 0 ? (
              <DataTable caption="BMR stage sign-offs">
                <thead>
                  <tr>
                    <th scope="col">Manufacturing Stage</th>
                    <th scope="col">Role</th>
                    <th scope="col">Sign-Off Status</th>
                    <th scope="col">Remarks</th>
                    <th scope="col">Timestamp</th>
                  </tr>
                </thead>
                <tbody>
                  {bmrSignoffs.map((sig) => (
                    <tr key={sig.id}>
                      <td><strong>{sig.stageName}</strong></td>
                      <td><span className="status-badge status-badge--info">{sig.role}</span></td>
                      <td><StatusChip status="APPROVED" /></td>
                      <td>{sig.remarks || 'Standard GMP signoff verified.'}</td>
                      <td>{sig.signedAt ? formatDateTime(sig.signedAt) : '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </DataTable>
            ) : (
              <p className="empty-message">No stage sign-offs logged yet.</p>
            )}
          </section>

          {/* Deviations & OOS Log */}
          <section className="document-card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
              <div>
                <h2>Deviations & Out-Of-Specification (OOS) Incidents ({bmrDeviations.length})</h2>
                <p style={{ fontSize: '13px', color: 'var(--text-muted)', margin: 0 }}>
                  Process deviations, physical defects, or equipment alarms investigated for this batch.
                </p>
              </div>
              <Button onClick={() => setIsDeviationOpen(true)} variant="secondary">
                <AlertTriangle size={16} />
                Log Deviation
              </Button>
            </div>
            {bmrDeviations.length > 0 ? (
              <DataTable caption="BMR deviations and investigations">
                <thead>
                  <tr>
                    <th scope="col">Deviation #</th>
                    <th scope="col">Title</th>
                    <th scope="col">Severity</th>
                    <th scope="col">Status</th>
                    <th scope="col">Immediate Action</th>
                    <th scope="col">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {bmrDeviations.map((dev) => (
                    <tr key={dev.id}>
                      <td className="cell-id">{dev.deviationNumber}</td>
                      <td>{dev.title}</td>
                      <td>
                        <span className={dev.severity === 'CRITICAL' ? 'status-badge status-badge--danger' : 'status-badge status-badge--warning'}>
                          {dev.severity}
                        </span>
                      </td>
                      <td><StatusChip status={formatStatusLabel(dev.status)} /></td>
                      <td>{dev.immediateActionTaken || '—'}</td>
                      <td>
                        {dev.status !== 'RESOLVED' && (
                          <Button
                            onClick={() => {
                              setSelectedDevId(dev.id)
                              setIsResolveDevOpen(true)
                            }}
                            variant="secondary"
                          >
                            Resolve / CAPA
                          </Button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </DataTable>
            ) : (
              <p className="empty-message">No deviations or OOS incidents recorded for this batch.</p>
            )}
          </section>
        </div>
      )}

      {/* Receive Finished Goods Modal */}
      <Modal
        isOpen={isReceiveOpen}
        onClose={() => setIsReceiveOpen(false)}
        title="Receive Finished Goods Batch"
        footer={
          <>
            <Button onClick={() => setIsReceiveOpen(false)} variant="secondary">Cancel</Button>
            <Button
              disabled={receiveMutation.isPending}
              onClick={() => receiveMutation.mutate()}
              variant="primary"
            >
              Receive Batch
            </Button>
          </>
        }
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <FormField label="Quantity Received" required>
            <NumberInput
              onChange={(e) => setReceiveQty(e.target.value)}
              value={receiveQty}
            />
          </FormField>
          <FormField label="Batch / Lot Number" required>
            <TextInput
              onChange={(e) => setBatchNo(e.target.value)}
              placeholder="e.g. BT-2026-09A"
              value={batchNo}
            />
          </FormField>
          <FormField label="Expiry Date" required>
            <TextInput
              onChange={(e) => setExpiryDate(e.target.value)}
              type="date"
              value={expiryDate}
            />
          </FormField>
        </div>
      </Modal>

      {/* Update Costs Modal */}
      <Modal
        isOpen={isCostOpen}
        onClose={() => setIsCostOpen(false)}
        title="Update Manufacturing Costs"
        footer={
          <>
            <Button onClick={() => setIsCostOpen(false)} variant="secondary">Cancel</Button>
            <Button
              disabled={costMutation.isPending}
              onClick={() => costMutation.mutate()}
              variant="primary"
            >
              Update Costs
            </Button>
          </>
        }
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <FormField label="Direct Labor Cost (₹)">
            <NumberInput
              onChange={(e) => setLaborCost(e.target.value)}
              value={laborCost}
            />
          </FormField>
          <FormField label="Manufacturing Overhead Cost (₹)">
            <NumberInput
              onChange={(e) => setOverheadCost(e.target.value)}
              value={overheadCost}
            />
          </FormField>
        </div>
      </Modal>

      {/* Record Scrap Modal */}
      <Modal
        isOpen={isScrapOpen}
        onClose={() => setIsScrapOpen(false)}
        title="Record Production Scrap / Wastage"
        footer={
          <>
            <Button onClick={() => setIsScrapOpen(false)} variant="secondary">Cancel</Button>
            <Button
              disabled={recordScrapMutation.isPending || !scrapItemId.trim()}
              onClick={() => recordScrapMutation.mutate()}
              variant="destructive"
            >
              Record Scrap
            </Button>
          </>
        }
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <FormField label="Scrapped Item" required>
            <EntityPicker<Item>
              ariaLabel="Scrapped Item"
              getOptionDescription={(item) => `${item.sku || 'No SKU'} · ${item.unitOfMeasure || 'unit'}`}
              getOptionId={(item) => item.id}
              getOptionLabel={(item) => item.name}
              onChange={(_id, item) => {
                setSelectedScrapItem(item ?? null)
                setScrapItemId(item?.id ?? '')
              }}
              onSearch={async (query) => {
                const res = await listItems({ search: query, activeOnly: true, size: 25 })
                return res.content
              }}
              placeholder="Search component to record scrap..."
              selectedEntity={selectedScrapItem}
              value={selectedScrapItem?.id ?? null}
            />
          </FormField>
          <FormField label="Scrap Quantity" required>
            <NumberInput
              onChange={(e) => setScrapQty(e.target.value)}
              value={scrapQty}
            />
          </FormField>
          <FormField label="Reason / Notes">
            <TextInput
              onChange={(e) => setScrapNotes(e.target.value)}
              placeholder="Defective mold, packaging tear..."
              value={scrapNotes}
            />
          </FormField>
        </div>
      </Modal>

      {/* Complete Job Card Modal */}
      <Modal
        isOpen={isCompleteJobCardOpen}
        onClose={() => setIsCompleteJobCardOpen(false)}
        title="Complete Floor Job Card"
        footer={
          <>
            <Button onClick={() => setIsCompleteJobCardOpen(false)} variant="secondary">Cancel</Button>
            <Button
              disabled={completeJcMutation.isPending}
              onClick={() => completeJcMutation.mutate()}
              variant="primary"
            >
              Complete Job Card
            </Button>
          </>
        }
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <FormField label="Completed Quantity" required>
            <NumberInput
              onChange={(e) => setJcCompletedQty(e.target.value)}
              value={jcCompletedQty}
            />
          </FormField>
          <FormField label="Scrap Quantity">
            <NumberInput
              onChange={(e) => setJcScrapQty(e.target.value)}
              value={jcScrapQty}
            />
          </FormField>
          <FormField label="Time Logged (minutes)">
            <NumberInput
              onChange={(e) => setJcTimeLogged(Number(e.target.value))}
              value={jcTimeLogged}
            />
          </FormField>
        </div>
      </Modal>

      {/* BMR Record Parameter Step Modal */}
      <Modal
        isOpen={isStepRecordOpen}
        onClose={() => setIsStepRecordOpen(false)}
        title="Record In-Process Parameter Check"
        footer={
          <>
            <Button onClick={() => setIsStepRecordOpen(false)} variant="secondary">Cancel</Button>
            <Button
              disabled={recordStepMutation.isPending || !bmrParamName.trim()}
              onClick={() => recordStepMutation.mutate()}
              variant="primary"
            >
              Save Record
            </Button>
          </>
        }
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <FormGrid columns={2}>
            <FormField label="Step Number" required>
              <NumberInput
                onChange={(e) => setBmrStepNum(Number(e.target.value))}
                value={bmrStepNum}
              />
            </FormField>
            <FormField label="Operation Name" required>
              <TextInput
                onChange={(e) => setBmrOpName(e.target.value)}
                value={bmrOpName}
              />
            </FormField>
          </FormGrid>
          <FormField label="Parameter Name" required>
            <TextInput
              onChange={(e) => setBmrParamName(e.target.value)}
              placeholder="e.g. Dissolution rate, Blend uniformity, pH, Hardness"
              value={bmrParamName}
            />
          </FormField>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '8px' }}>
            <FormField label="Target">
              <TextInput
                onChange={(e) => setBmrTargetVal(e.target.value)}
                value={bmrTargetVal}
              />
            </FormField>
            <FormField label="Min Limit">
              <TextInput
                onChange={(e) => setBmrMinVal(e.target.value)}
                value={bmrMinVal}
              />
            </FormField>
            <FormField label="Max Limit">
              <TextInput
                onChange={(e) => setBmrMaxVal(e.target.value)}
                value={bmrMaxVal}
              />
            </FormField>
            <FormField label="Unit">
              <TextInput
                onChange={(e) => setBmrUnit(e.target.value)}
                value={bmrUnit}
              />
            </FormField>
          </div>
          <FormField label="Actual Measured Value" required>
            <TextInput
              onChange={(e) => setBmrMeasuredVal(e.target.value)}
              style={{ fontWeight: 600, color: 'var(--color-primary)' }}
              value={bmrMeasuredVal}
            />
          </FormField>
          <FormField label="Notes / Observations">
            <TextInput
              onChange={(e) => setBmrStepNotes(e.target.value)}
              placeholder="Calibration verified, instrument ID..."
              value={bmrStepNotes}
            />
          </FormField>
        </div>
      </Modal>

      {/* BMR Sign-Off Modal */}
      <Modal
        isOpen={isSignoffOpen}
        onClose={() => setIsSignoffOpen(false)}
        title="Digital Stage Sign-Off (21 CFR Part 11)"
        footer={
          <>
            <Button onClick={() => setIsSignoffOpen(false)} variant="secondary">Cancel</Button>
            <Button
              disabled={signoffMutation.isPending}
              onClick={() => signoffMutation.mutate()}
              variant="primary"
            >
              Sign Off & Approve
            </Button>
          </>
        }
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <FormField label="Manufacturing Stage" required>
            <TextInput
              onChange={(e) => setBmrStageName(e.target.value)}
              value={bmrStageName}
            />
          </FormField>
          <FormField label="Approver Role" required>
            <SelectInput
              onChange={(e) => setBmrRole(e.target.value)}
              value={bmrRole}
            >
              <option value="OPERATOR">Operator / Technician</option>
              <option value="SUPERVISOR">Production Supervisor</option>
              <option value="QA_MANAGER">Quality Assurance (QA) Head</option>
            </SelectInput>
          </FormField>
          <FormField label="Approval Remarks">
            <TextInput
              onChange={(e) => setBmrSignoffRemarks(e.target.value)}
              placeholder="All parameters within acceptable pharmacopoeial limits."
              value={bmrSignoffRemarks}
            />
          </FormField>
        </div>
      </Modal>

      {/* BMR Log Deviation Modal */}
      <Modal
        isOpen={isDeviationOpen}
        onClose={() => setIsDeviationOpen(false)}
        title="Log Deviation / OOS Incident"
        footer={
          <>
            <Button onClick={() => setIsDeviationOpen(false)} variant="secondary">Cancel</Button>
            <Button
              disabled={raiseDevMutation.isPending || !devTitle.trim()}
              onClick={() => raiseDevMutation.mutate()}
              variant="destructive"
            >
              Log Deviation
            </Button>
          </>
        }
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <FormField label="Incident Title" required>
            <TextInput
              onChange={(e) => setDevTitle(e.target.value)}
              placeholder="e.g. Temperature spike during drying stage"
              value={devTitle}
            />
          </FormField>
          <FormField label="Severity" required>
            <SelectInput
              onChange={(e) => setDevSeverity(e.target.value)}
              value={devSeverity}
            >
              <option value="MINOR">Minor Deviation</option>
              <option value="MAJOR">Major Deviation</option>
              <option value="CRITICAL">Critical Out-of-Specification</option>
            </SelectInput>
          </FormField>
          <FormField label="Description" required>
            <TextAreaInput
              onChange={(e) => setDevDescription(e.target.value)}
              placeholder="Detailed description of the non-conformance..."
              rows={3}
              value={devDescription}
            />
          </FormField>
          <FormField label="Immediate Action Taken">
            <TextInput
              onChange={(e) => setDevImmediateAction(e.target.value)}
              placeholder="e.g. Paused granulation bed and notified QA."
              value={devImmediateAction}
            />
          </FormField>
        </div>
      </Modal>

      {/* BMR Resolve Deviation Modal */}
      <Modal
        isOpen={isResolveDevOpen}
        onClose={() => setIsResolveDevOpen(false)}
        title="Resolve Deviation & Log CAPA Plan"
        footer={
          <>
            <Button onClick={() => setIsResolveDevOpen(false)} variant="secondary">Cancel</Button>
            <Button
              disabled={resolveDevMutation.isPending}
              onClick={() => resolveDevMutation.mutate()}
              variant="primary"
            >
              Resolve Deviation
            </Button>
          </>
        }
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <FormField label="Root Cause" required>
            <TextInput
              onChange={(e) => setDevRootCause(e.target.value)}
              placeholder="e.g. Thermocouple calibration drift."
              value={devRootCause}
            />
          </FormField>
          <FormField label="Corrective & Preventive Action (CAPA)" required>
            <TextInput
              onChange={(e) => setDevCapPlan(e.target.value)}
              placeholder="e.g. Replace sensor and recalibrate weekly."
              value={devCapPlan}
            />
          </FormField>
          <FormField label="Resolution Summary Notes">
            <TextAreaInput
              onChange={(e) => setDevResolutionNotes(e.target.value)}
              placeholder="QA review confirms no impact on product safety."
              rows={2}
              value={devResolutionNotes}
            />
          </FormField>
        </div>
      </Modal>
    </section>
  )
}

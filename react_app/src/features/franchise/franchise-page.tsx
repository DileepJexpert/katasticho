import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
    Plus,
  Search,
  RefreshCw,
  Coins,
  Settings,
  CheckCircle2,
  Store,
  DollarSign,
  Tag,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import {
  Button,
  DataTable,
  FormField,
  FormGrid,
  Modal,
  Money,
  NumberInput,
  PageHeader,
  SelectInput,
  StatusChip,
  TextInput,
} from '@/design-system'
import {
  listFranchiseNodes,
  createFranchiseNode,
  getFranchisePolicy,
  saveFranchisePolicy,
  pushCatalogToBranches,
  listRoyaltySettlements,
  calculateRoyaltySettlement,
  postSettlementJournal,
  type FranchiseCatalogPolicy,
} from '@/features/franchise/franchise-api'

type TabKey = 'nodes' | 'sync' | 'royalties' | 'policy'

export function FranchisePage() {
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<TabKey>('nodes')
  const [search, setSearch] = useState('')
  const [feedback, setFeedback] = useState<string | null>(null)

  // Node Create Modal State
  const [isCreateOpen, setIsCreateOpen] = useState(false)
  const [nodeCode, setNodeCode] = useState('')
  const [nodeName, setNodeName] = useState('')
  const [nodeType, setNodeType] = useState('FRANCHISE_FOFO')
  const [contactPerson, setContactPerson] = useState('')
  const [phone, setPhone] = useState('')
  const [city, setCity] = useState('')
  const [royaltyPct, setRoyaltyPct] = useState('5.0')

  // Royalty Calculation Modal
  const [isRoyaltyModalOpen, setIsRoyaltyModalOpen] = useState(false)
  const [selectedNodeId, setSelectedNodeId] = useState('')
  const [settlementPeriod, setSettlementPeriod] = useState(new Date().toISOString().slice(0, 7))
  const [grossSales, setGrossSales] = useState('500000')

  // Queries
  const nodesQuery = useQuery({
    queryKey: ['franchise-nodes'],
    queryFn: () => listFranchiseNodes(),
  })

  const policyQuery = useQuery({
    queryKey: ['franchise-policy'],
    queryFn: () => getFranchisePolicy(),
    enabled: activeTab === 'policy',
  })

  const settlementsQuery = useQuery({
    queryKey: ['franchise-settlements'],
    queryFn: () => listRoyaltySettlements(),
    enabled: activeTab === 'royalties',
  })

  // Mutations
  const createNodeMutation = useMutation({
    mutationFn: () => createFranchiseNode({
      nodeCode,
      name: nodeName,
      nodeType,
      contactPerson,
      phone,
      city,
      royaltyPercentage: Number(royaltyPct),
      active: true,
    }),
    onSuccess: () => {
      setIsCreateOpen(false)
      setNodeCode('')
      setNodeName('')
      queryClient.invalidateQueries({ queryKey: ['franchise-nodes'] })
      setFeedback('Franchise branch store added successfully.')
    },
  })

  const pushCatalogMutation = useMutation({
    mutationFn: () => pushCatalogToBranches({}),
    onSuccess: (res) => {
      setFeedback(`Master catalog synced to ${res.syncedNodesCount} franchise store branches (${res.syncedItemsCount} items pushed).`)
    },
  })

  const calculateRoyaltyMutation = useMutation({
    mutationFn: () => calculateRoyaltySettlement({
      nodeId: selectedNodeId,
      period: settlementPeriod,
      grossSalesAmount: Number(grossSales),
    }),
    onSuccess: () => {
      setIsRoyaltyModalOpen(false)
      queryClient.invalidateQueries({ queryKey: ['franchise-settlements'] })
      setFeedback('Royalty calculation recorded for settlement period.')
    },
  })

  const postJournalMutation = useMutation({
    mutationFn: (id: string) => postSettlementJournal(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['franchise-settlements'] })
      setFeedback('Royalty settlement journal posted to General Ledger.')
    },
  })

  const savePolicyMutation = useMutation({
    mutationFn: (data: FranchiseCatalogPolicy) => saveFranchisePolicy(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['franchise-policy'] })
      setFeedback('Franchise governance policy updated.')
    },
  })

  const nodes = nodesQuery.data ?? []
  const filteredNodes = nodes.filter((n) => {
    if (!search.trim()) return true
    const q = search.toLowerCase()
    return n.nodeCode.toLowerCase().includes(q) || n.name.toLowerCase().includes(q) || (n.city && n.city.toLowerCase().includes(q))
  })

  const settlements = settlementsQuery.data ?? []
  const policy = policyQuery.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Enterprise / Multi-Entity"
        title="Franchise Operations & Multi-Store Network"
        description="Franchise store registry (FOFO/COCO), master catalog distribution, branch price overrides, and royalty settlement journals."
        actions={
          <div className="table-actions">
            <Button
              disabled={pushCatalogMutation.isPending}
              onClick={() => pushCatalogMutation.mutate()}
              variant="secondary"
            >
              <RefreshCw size={15} />
              Push Catalog to Branches
            </Button>
            <Button onClick={() => setIsCreateOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Add Franchise Store
            </Button>
          </div>
        }
      />

      {feedback && (
        <div className="feedback-alert feedback-alert--success" role="status">
          <CheckCircle2 size={16} />
          <span>{feedback}</span>
          <button className="feedback-alert__close" onClick={() => setFeedback(null)} type="button">×</button>
        </div>
      )}

      <div className="list-tabs" role="tablist">
        <button
          aria-selected={activeTab === 'nodes'}
          className={activeTab === 'nodes' ? 'list-tab list-tab--active' : 'list-tab'}
          onClick={() => setActiveTab('nodes')}
          role="tab"
          type="button"
        >
          <Store size={15} style={{ marginRight: '6px' }} />
          Franchise Stores ({nodes.length})
        </button>
        <button
          aria-selected={activeTab === 'royalties'}
          className={activeTab === 'royalties' ? 'list-tab list-tab--active' : 'list-tab'}
          onClick={() => setActiveTab('royalties')}
          role="tab"
          type="button"
        >
          <Coins size={15} style={{ marginRight: '6px' }} />
          Royalty Settlements ({settlements.length})
        </button>
        <button
          aria-selected={activeTab === 'policy'}
          className={activeTab === 'policy' ? 'list-tab list-tab--active' : 'list-tab'}
          onClick={() => setActiveTab('policy')}
          role="tab"
          type="button"
        >
          <Settings size={15} style={{ marginRight: '6px' }} />
          Catalog Governance Policy
        </button>
      </div>

      {activeTab === 'nodes' && (
        <>
          <div className="list-toolbar">
            <label className="directory-search">
              <Search aria-hidden="true" size={18} />
              <span className="sr-only">Search franchise stores</span>
              <input
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search by store code, name, city..."
                type="search"
                value={search}
              />
            </label>
          </div>

          {nodesQuery.isLoading ? (
            <div className="directory-state">Loading franchise network...</div>
          ) : filteredNodes.length === 0 ? (
            <div className="directory-state">
              <Store size={24} />
              <strong>No franchise stores registered.</strong>
            </div>
          ) : (
            <DataTable caption="Franchise store directory">
              <thead>
                <tr>
                  <th scope="col">Store Code</th>
                  <th scope="col">Store Name</th>
                  <th scope="col">Model</th>
                  <th scope="col">Contact Person</th>
                  <th scope="col">City</th>
                  <th className="numeric-cell" scope="col">Royalty %</th>
                  <th scope="col">Status</th>
                  <th scope="col">Action</th>
                </tr>
              </thead>
              <tbody>
                {filteredNodes.map((node) => (
                  <tr key={node.id}>
                    <td className="cell-id">
                      <Link to={`/franchise/${node.id}`}>{node.nodeCode}</Link>
                    </td>
                    <td><strong>{node.name}</strong></td>
                    <td><span className="status-badge status-badge--info">{node.nodeType}</span></td>
                    <td>{node.contactPerson || '—'} {node.phone ? `(${node.phone})` : ''}</td>
                    <td>{node.city || '—'}</td>
                    <td className="numeric-cell">{node.royaltyPercentage ?? 5}%</td>
                    <td><StatusChip status={node.active ? 'ACTIVE' : 'INACTIVE'} /></td>
                    <td>
                      <Link to={`/franchise/${node.id}`}>
                        <Button variant="secondary">
                          <Tag size={14} />
                          Price Overrides
                        </Button>
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </>
      )}

      {activeTab === 'royalties' && (
        <div style={{ marginTop: '16px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h2>Franchise Royalty Settlements</h2>
              <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
                Periodic brand royalty calculation based on audited gross branch turnover.
              </p>
            </div>
            <Button onClick={() => setIsRoyaltyModalOpen(true)} variant="primary">
              <DollarSign size={15} />
              Calculate Settlement
            </Button>
          </div>

          {settlements.length > 0 ? (
            <DataTable caption="Royalty settlements">
              <thead>
                <tr>
                  <th scope="col">Period</th>
                  <th scope="col">Store</th>
                  <th className="numeric-cell" scope="col">Gross Sales</th>
                  <th className="numeric-cell" scope="col">Royalty %</th>
                  <th className="numeric-cell" scope="col">Royalty Amount</th>
                  <th scope="col">Status</th>
                  <th scope="col">Action</th>
                </tr>
              </thead>
              <tbody>
                {settlements.map((s) => (
                  <tr key={s.id}>
                    <td className="cell-id"><strong>{s.settlementPeriod}</strong></td>
                    <td>{s.nodeName || s.nodeId.slice(0, 8)}</td>
                    <td className="numeric-cell"><Money amount={s.grossSalesAmount} /></td>
                    <td className="numeric-cell">{s.royaltyPercentage}%</td>
                    <td className="numeric-cell" style={{ fontWeight: 600, color: 'var(--color-primary)' }}>
                      <Money amount={s.royaltyAmount} />
                    </td>
                    <td><StatusChip status={s.status} /></td>
                    <td>
                      {s.status !== 'POSTED' && (
                        <Button
                          disabled={postJournalMutation.isPending}
                          onClick={() => postJournalMutation.mutate(s.id)}
                          variant="secondary"
                        >
                          Post Journal
                        </Button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="directory-state">
              <Coins size={24} />
              <strong>No royalty settlements logged.</strong>
            </div>
          )}
        </div>
      )}

      {activeTab === 'policy' && (
        <section className="document-card" style={{ maxWidth: '650px', marginTop: '16px' }}>
          <h2>Catalog Governance & Pricing Policy</h2>
          <form
            onSubmit={(e) => {
              e.preventDefault()
              const fd = new FormData(e.currentTarget)
              savePolicyMutation.mutate({
                allowLocalItemAdditions: fd.get('allowLocalItemAdditions') === 'on',
                allowPriceOverrides: fd.get('allowPriceOverrides') === 'on',
                defaultRoyaltyPercentage: Number(fd.get('defaultRoyaltyPercentage') || 5.0),
                priceOverrideMaxDiscountPct: Number(fd.get('priceOverrideMaxDiscountPct') || 20.0),
                priceOverrideMaxMarkupPct: Number(fd.get('priceOverrideMaxMarkupPct') || 30.0),
                autoSyncCatalogOnItemCreate: fd.get('autoSyncCatalogOnItemCreate') === 'on',
              })
            }}
          >
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                <input
                  defaultChecked={policy?.allowPriceOverrides ?? true}
                  name="allowPriceOverrides"
                  type="checkbox"
                />
                <span style={{ fontSize: '14px', fontWeight: 600 }}>Allow Franchise Branches to Set Local Price Overrides</span>
              </label>

              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                <input
                  defaultChecked={policy?.allowLocalItemAdditions ?? false}
                  name="allowLocalItemAdditions"
                  type="checkbox"
                />
                <span style={{ fontSize: '14px', fontWeight: 600 }}>Allow Local Store Items (Outside Master Catalog)</span>
              </label>

              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                <input
                  defaultChecked={policy?.autoSyncCatalogOnItemCreate ?? true}
                  name="autoSyncCatalogOnItemCreate"
                  type="checkbox"
                />
                <span style={{ fontSize: '14px', fontWeight: 600 }}>Automatically Broadcast New Items to Franchise Stores</span>
              </label>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <label>
                  <span style={{ fontSize: '13px', fontWeight: 600 }}>Max Permitted Discount (%):</span>
                  <input
                    className="search-input"
                    defaultValue={policy?.priceOverrideMaxDiscountPct ?? 20}
                    name="priceOverrideMaxDiscountPct"
                    style={{ width: '100%', marginTop: '4px' }}
                    type="number"
                  />
                </label>
                <label>
                  <span style={{ fontSize: '13px', fontWeight: 600 }}>Max Permitted Markup (%):</span>
                  <input
                    className="search-input"
                    defaultValue={policy?.priceOverrideMaxMarkupPct ?? 30}
                    name="priceOverrideMaxMarkupPct"
                    style={{ width: '100%', marginTop: '4px' }}
                    type="number"
                  />
                </label>
              </div>

              <div>
                <Button disabled={savePolicyMutation.isPending} type="submit" variant="primary">
                  Save Policy
                </Button>
              </div>
            </div>
          </form>
        </section>
      )}

      {/* Add Franchise Node Modal */}
      <Modal
        footer={
          <>
            <Button onClick={() => setIsCreateOpen(false)} variant="secondary">Cancel</Button>
            <Button
              disabled={createNodeMutation.isPending || !nodeCode.trim() || !nodeName.trim()}
              onClick={() => createNodeMutation.mutate()}
              variant="primary"
            >
              {createNodeMutation.isPending ? 'Creating...' : 'Create Store'}
            </Button>
          </>
        }
        isOpen={isCreateOpen}
        onClose={() => setIsCreateOpen(false)}
        size="lg"
        title="Add Franchise Store Branch"
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <FormGrid columns={2}>
            <FormField label="Store Code" required>
              <TextInput
                onChange={(e) => setNodeCode(e.target.value)}
                placeholder="e.g. FR-MUM-01"
                required
                value={nodeCode}
              />
            </FormField>
            <FormField label="Store Name" required>
              <TextInput
                onChange={(e) => setNodeName(e.target.value)}
                placeholder="e.g. Katasticho Express Bandra"
                required
                value={nodeName}
              />
            </FormField>
          </FormGrid>

          <FormGrid columns={2}>
            <FormField label="Franchise Model">
              <SelectInput
                onChange={(e) => setNodeType(e.target.value)}
                value={nodeType}
              >
                <option value="FRANCHISE_FOFO">FOFO (Franchise Owned & Operated)</option>
                <option value="FRANCHISE_COCO">COCO (Company Owned & Operated)</option>
                <option value="COMPANY_OWNED">Company Owned Branch</option>
              </SelectInput>
            </FormField>
            <FormField label="Royalty %">
              <NumberInput
                min={0}
                onChange={(e) => setRoyaltyPct(e.target.value)}
                value={royaltyPct}
              />
            </FormField>
          </FormGrid>

          <FormGrid columns={2}>
            <FormField label="Contact Person">
              <TextInput
                onChange={(e) => setContactPerson(e.target.value)}
                value={contactPerson}
              />
            </FormField>
            <FormField label="Phone">
              <TextInput
                onChange={(e) => setPhone(e.target.value)}
                value={phone}
              />
            </FormField>
          </FormGrid>

          <FormField label="City / Region">
            <TextInput
              onChange={(e) => setCity(e.target.value)}
              placeholder="e.g. Mumbai, Maharashtra"
              value={city}
            />
          </FormField>
        </div>
      </Modal>

      {/* Calculate Royalty Modal */}
      <Modal
        footer={
          <>
            <Button onClick={() => setIsRoyaltyModalOpen(false)} variant="secondary">Cancel</Button>
            <Button
              disabled={calculateRoyaltyMutation.isPending || !selectedNodeId}
              onClick={() => calculateRoyaltyMutation.mutate()}
              variant="primary"
            >
              {calculateRoyaltyMutation.isPending ? 'Calculating...' : 'Calculate & Draft'}
            </Button>
          </>
        }
        isOpen={isRoyaltyModalOpen}
        onClose={() => setIsRoyaltyModalOpen(false)}
        size="md"
        title="Calculate Monthly Royalty Settlement"
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <FormField label="Select Store" required>
            <SelectInput
              onChange={(e) => setSelectedNodeId(e.target.value)}
              value={selectedNodeId}
            >
              <option value="">Select Franchise Store</option>
              {nodes.map((n) => (
                <option key={n.id} value={n.id}>
                  {n.nodeCode} - {n.name} ({n.royaltyPercentage ?? 5}%)
                </option>
              ))}
            </SelectInput>
          </FormField>

          <FormField label="Settlement Period (YYYY-MM)">
            <TextInput
              onChange={(e) => setSettlementPeriod(e.target.value)}
              type="month"
              value={settlementPeriod}
            />
          </FormField>

          <FormField label="Audited Gross Branch Sales (₹)">
            <NumberInput
              min={0}
              onChange={(e) => setGrossSales(e.target.value)}
              step="0.01"
              value={grossSales}
            />
          </FormField>
        </div>
      </Modal>
    </section>
  )
}

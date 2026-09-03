import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Plus, Workflow, Cpu } from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { listRoutings, listOperations, createRouting, createOperation } from '@/features/routings/routings-api'

export function RoutingsPage() {
  const queryClient = useQueryClient()
  const [isCreateRoutingOpen, setIsCreateRoutingOpen] = useState(false)
  const [isCreateOpOpen, setIsCreateOpOpen] = useState(false)
  const [newRoutingName, setNewRoutingName] = useState('')
  const [newOpCode, setNewOpCode] = useState('')
  const [newOpName, setNewOpName] = useState('')
  const [newOpSetup, setNewOpSetup] = useState(15)
  const [newOpRun, setNewOpRun] = useState('2.5')

  const routingsQuery = useQuery({
    queryKey: ['routings'],
    queryFn: listRoutings,
  })

  const operationsQuery = useQuery({
    queryKey: ['operations'],
    queryFn: listOperations,
  })

  const createRoutingMutation = useMutation({
    mutationFn: () => createRouting({ name: newRoutingName, isDefault: true }),
    onSuccess: () => {
      setIsCreateRoutingOpen(false)
      setNewRoutingName('')
      queryClient.invalidateQueries({ queryKey: ['routings'] })
    },
  })

  const createOpMutation = useMutation({
    mutationFn: () => createOperation({
      code: newOpCode,
      name: newOpName,
      setupTimeMinutes: newOpSetup,
      runTimeMinutesPerUnit: newOpRun,
    }),
    onSuccess: () => {
      setIsCreateOpOpen(false)
      setNewOpCode('')
      setNewOpName('')
      queryClient.invalidateQueries({ queryKey: ['operations'] })
    },
  })

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Manufacturing / Engineering"
        title="Routings & Operations"
        description="Production stage sequences, standard operational runtimes, workstation assignments, and DAG precedence."
        actions={
          <div className="table-actions">
            <Button onClick={() => setIsCreateOpOpen(true)} variant="secondary">
              <Plus aria-hidden="true" size={16} />
              Add Operation
            </Button>
            <Button onClick={() => setIsCreateRoutingOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Create Routing
            </Button>
          </div>
        }
      />

      <div className="document-layout">
        <section className="document-card" style={{ flex: 1.5 }}>
          <h2>Production Routings</h2>
          {routingsQuery.isLoading ? (
            <div className="directory-state">Loading routings...</div>
          ) : routingsQuery.data && routingsQuery.data.length > 0 ? (
            <DataTable caption="Standard manufacturing routings">
              <thead>
                <tr>
                  <th scope="col">Routing Name</th>
                  <th scope="col">Item</th>
                  <th className="numeric-cell" scope="col">Operations</th>
                  <th scope="col">Default</th>
                </tr>
              </thead>
              <tbody>
                {routingsQuery.data.map((r) => (
                  <tr key={r.id}>
                    <td><strong>{r.name}</strong></td>
                    <td>{r.itemName || '--'}</td>
                    <td className="numeric-cell">{r.operations?.length ?? 0} steps</td>
                    <td><StatusChip status={r.isDefault ? 'Default Routing' : 'Custom'} /></td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="directory-state">
              <Workflow size={24} />
              <strong>No routings configured yet.</strong>
            </div>
          )}
        </section>

        <section className="document-card" style={{ flex: 1 }}>
          <h2>Floor Operations Library</h2>
          {operationsQuery.isLoading ? (
            <div className="directory-state">Loading operations...</div>
          ) : operationsQuery.data && operationsQuery.data.length > 0 ? (
            <DataTable caption="Master operations library">
              <thead>
                <tr>
                  <th scope="col">Code</th>
                  <th scope="col">Operation</th>
                  <th className="numeric-cell" scope="col">Setup</th>
                  <th className="numeric-cell" scope="col">Run/Unit</th>
                </tr>
              </thead>
              <tbody>
                {operationsQuery.data.map((op) => (
                  <tr key={op.id}>
                    <td><code>{op.code}</code></td>
                    <td><strong>{op.name}</strong></td>
                    <td className="numeric-cell">{op.setupTimeMinutes}m</td>
                    <td className="numeric-cell">{op.runTimeMinutesPerUnit ?? 0}m</td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="directory-state">
              <Cpu size={24} />
              <strong>No operations defined yet.</strong>
            </div>
          )}
        </section>
      </div>

      {isCreateRoutingOpen && (
        <div className="modal-backdrop">
          <div className="modal-card">
            <h3>Create Production Routing</h3>
            <label style={{ display: 'block', margin: '16px 0' }}>
              <span style={{ fontSize: '13px', fontWeight: 600 }}>Routing Name:</span>
              <input
                className="search-input"
                onChange={(e) => setNewRoutingName(e.target.value)}
                placeholder="e.g. Standard 500ml Bottling & Packaging Sequence"
                style={{ width: '100%', marginTop: '4px' }}
                value={newRoutingName}
              />
            </label>
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
              <Button onClick={() => setIsCreateRoutingOpen(false)} variant="secondary">Cancel</Button>
              <Button
                disabled={createRoutingMutation.isPending || !newRoutingName.trim()}
                onClick={() => createRoutingMutation.mutate()}
                variant="primary"
              >
                Create Routing
              </Button>
            </div>
          </div>
        </div>
      )}

      {isCreateOpOpen && (
        <div className="modal-backdrop">
          <div className="modal-card">
            <h3>Add Operation Master</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '12px' }}>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Operation Code:</span>
                <input
                  className="search-input"
                  onChange={(e) => setNewOpCode(e.target.value)}
                  placeholder="e.g. OP-MIX-01"
                  style={{ width: '100%', marginTop: '4px' }}
                  value={newOpCode}
                />
              </label>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Operation Name:</span>
                <input
                  className="search-input"
                  onChange={(e) => setNewOpName(e.target.value)}
                  placeholder="e.g. High Shear Granulation & Blending"
                  style={{ width: '100%', marginTop: '4px' }}
                  value={newOpName}
                />
              </label>
              <div style={{ display: 'flex', gap: '12px' }}>
                <label style={{ flex: 1 }}>
                  <span style={{ fontSize: '13px', fontWeight: 600 }}>Setup Time (min):</span>
                  <input
                    className="search-input"
                    onChange={(e) => setNewOpSetup(Number(e.target.value))}
                    style={{ width: '100%', marginTop: '4px' }}
                    type="number"
                    value={newOpSetup}
                  />
                </label>
                <label style={{ flex: 1 }}>
                  <span style={{ fontSize: '13px', fontWeight: 600 }}>Run Time (min/unit):</span>
                  <input
                    className="search-input"
                    onChange={(e) => setNewOpRun(e.target.value)}
                    style={{ width: '100%', marginTop: '4px' }}
                    value={newOpRun}
                  />
                </label>
              </div>
            </div>
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '16px' }}>
              <Button onClick={() => setIsCreateOpOpen(false)} variant="secondary">Cancel</Button>
              <Button
                disabled={createOpMutation.isPending || !newOpCode.trim() || !newOpName.trim()}
                onClick={() => createOpMutation.mutate()}
                variant="primary"
              >
                Save Operation
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}
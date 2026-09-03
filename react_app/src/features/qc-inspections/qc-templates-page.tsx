import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Plus, ShieldCheck } from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { listQcTemplates, createQcTemplate } from '@/features/qc-inspections/qc-inspections-api'

export function QcTemplatesPage() {
  const queryClient = useQueryClient()
  const [isCreateOpen, setIsCreateOpen] = useState(false)
  const [name, setName] = useState('')
  const [inspectionType, setInspectionType] = useState('INBOUND_GRN')

  const query = useQuery({
    queryKey: ['qc-templates'],
    queryFn: listQcTemplates,
  })

  const createMutation = useMutation({
    mutationFn: () => createQcTemplate({
      name,
      inspectionType,
      parameters: [
        { name: 'Appearance & Color', parameterType: 'TEXT', acceptableValues: 'White powder, odorless', isMandatory: true },
        { name: 'Moisture Content %', parameterType: 'NUMERIC', minValue: 0.1, maxValue: 2.5, unit: '%', isMandatory: true },
      ],
    }),
    onSuccess: () => {
      setIsCreateOpen(false)
      setName('')
      queryClient.invalidateQueries({ queryKey: ['qc-templates'] })
    },
  })

  const templates = query.data ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Quality & Compliance"
        title="Quality Control Templates"
        description="Standard testing parameter definitions, numeric tolerance thresholds, and acceptance criteria."
        actions={
          <div className="table-actions">
            <Button onClick={() => setIsCreateOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Create QC Template
            </Button>
          </div>
        }
      />

      {query.isLoading ? (
        <div className="directory-state">Loading QC templates...</div>
      ) : templates.length === 0 ? (
        <div className="directory-state">
          <ShieldCheck size={24} />
          <strong>No QC templates created yet.</strong>
        </div>
      ) : (
        <DataTable caption="Master QC inspection templates">
          <thead>
            <tr>
              <th scope="col">Template Name</th>
              <th scope="col">Inspection Stage</th>
              <th className="numeric-cell" scope="col">Test Parameters</th>
            </tr>
          </thead>
          <tbody>
            {templates.map((tpl) => (
              <tr key={tpl.id}>
                <td><strong>{tpl.name}</strong></td>
                <td><code>{tpl.inspectionType}</code></td>
                <td className="numeric-cell">{tpl.parameters?.length ?? 0} parameters</td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}

      {isCreateOpen && (
        <div className="modal-backdrop">
          <div className="modal-card">
            <h3>Create Quality Inspection Template</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '12px' }}>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Template Name:</span>
                <input
                  className="search-input"
                  onChange={(e) => setName(e.target.value)}
                  placeholder="e.g. Raw Material Chemical Assay Template"
                  style={{ width: '100%', marginTop: '4px' }}
                  value={name}
                />
              </label>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Inspection Stage:</span>
                <select
                  className="search-input"
                  onChange={(e) => setInspectionType(e.target.value)}
                  style={{ width: '100%', marginTop: '4px' }}
                  value={inspectionType}
                >
                  <option value="INBOUND_GRN">Inbound Goods Receipt (GRN)</option>
                  <option value="IN_PROCESS">In-Process Production Audit</option>
                  <option value="FINAL_RELEASE">Final Finished Goods Release</option>
                </select>
              </label>
            </div>
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '16px' }}>
              <Button onClick={() => setIsCreateOpen(false)} variant="secondary">Cancel</Button>
              <Button
                disabled={createMutation.isPending || !name.trim()}
                onClick={() => createMutation.mutate()}
                variant="primary"
              >
                Save Template
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}
import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Fingerprint,
  Plus,
  X,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate } from '@/shared/format/format'
import {
  listBiometricDevices,
  listPunchLogs,
  registerBiometricDevice,
  testDeviceConnection,
  triggerDeviceSync,
  type BiometricDevice,
} from '@/features/hr/hr-api'

export function BiometricDevicesPage() {
  const [isRegisterOpen, setIsRegisterOpen] = useState(false)
  const queryClient = useQueryClient()

  const devicesQuery = useQuery({
    queryKey: ['hr-biometric-devices'],
    queryFn: () => listBiometricDevices(),
  })

  const logsQuery = useQuery({
    queryKey: ['hr-biometric-logs'],
    queryFn: () => listPunchLogs(0, 30),
  })

  const registerMutation = useMutation({
    mutationFn: (req: Partial<BiometricDevice>) => registerBiometricDevice(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-biometric-devices'] })
      setIsRegisterOpen(false)
    },
  })

  const testMutation = useMutation({
    mutationFn: (id: string) => testDeviceConnection(id),
    onSuccess: (data) => {
      alert(`Connection test result: ${data.reachable ? 'Reachable (Latency: ' + data.latencyMs + 'ms)' : 'Unreachable: ' + data.message}`)
    },
  })

  const syncMutation = useMutation({
    mutationFn: (id: string) => triggerDeviceSync(id),
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ['hr-biometric-logs'] })
      alert(`Synchronized ${data.syncedCount} punch records from hardware terminal.`)
    },
  })

  const devices = devicesQuery.data ?? []
  const punchLogs = logsQuery.data?.content ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Core HR / Hardware Integration"
        title="Biometric Attendance Clocks"
        description="ZKTeco, eSSL, Realtime TCP/IP and ADMS cloud push biometric terminal registry, hardware sync, and punch telemetry."
        actions={
          <div className="table-actions">
            <Button onClick={() => setIsRegisterOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Register Biometric Device
            </Button>
          </div>
        }
      />

      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Hardware Clocks</span>
          <strong className="summary-card__value">{devices.length}</strong>
          <span className="summary-card__hint">Connected terminals</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Online Terminals</span>
          <strong className="summary-card__value text-success">
            {devices.filter((d) => d.status === 'ONLINE').length}
          </strong>
          <span className="summary-card__hint">Active network connection</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Today Punches</span>
          <strong className="summary-card__value text-primary">{punchLogs.length}</strong>
          <span className="summary-card__hint">Synced hardware records</span>
        </div>
      </div>

      <div className="document-section">
        <h2>Registered biometric terminal devices</h2>
        {devicesQuery.isLoading ? (
          <div className="directory-state">Loading biometric devices...</div>
        ) : devices.length === 0 ? (
          <div className="directory-state">
            <Fingerprint aria-hidden="true" size={24} />
            <strong>No biometric devices configured.</strong>
            <p>Click "Register Biometric Device" to connect TCP/IP or ADMS cloud push terminals.</p>
          </div>
        ) : (
          <DataTable caption="Biometric hardware devices and real-time connectivity status">
            <thead>
              <tr>
                <th scope="col">Device Name</th>
                <th scope="col">Protocol</th>
                <th scope="col">IP Address & Port</th>
                <th scope="col">Location</th>
                <th scope="col">Status</th>
                <th scope="col">Last Sync</th>
                <th scope="col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {devices.map((d) => (
                <tr key={d.id}>
                  <td><strong>{d.deviceName}</strong></td>
                  <td><code className="table-code">{d.protocol}</code></td>
                  <td>{d.deviceIp ? `${d.deviceIp}:${d.port}` : 'ADMS Cloud Push'}</td>
                  <td>{d.location || 'Main Reception'}</td>
                  <td><StatusChip status={d.status} /></td>
                  <td>{d.lastSyncAt ? formatDate(d.lastSyncAt) : 'Never'}</td>
                  <td>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <Button
                        disabled={testMutation.isPending}
                        onClick={() => testMutation.mutate(d.id)}
                        variant="secondary"
                      >
                        Ping
                      </Button>
                      <Button
                        disabled={syncMutation.isPending}
                        onClick={() => syncMutation.mutate(d.id)}
                        variant="primary"
                      >
                        Sync
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </div>

      <div className="document-section">
        <h2>Live hardware punch stream</h2>
        {logsQuery.isLoading ? (
          <div className="directory-state">Loading punch logs...</div>
        ) : punchLogs.length === 0 ? (
          <div className="directory-state">No punch logs recorded yet.</div>
        ) : (
          <DataTable caption="Latest biometric punch telemetry stream">
            <thead>
              <tr>
                <th scope="col">Punch Timestamp</th>
                <th scope="col">Employee</th>
                <th scope="col">PIN</th>
                <th scope="col">Terminal Device</th>
                <th scope="col">Punch Type</th>
                <th scope="col">Sync Status</th>
              </tr>
            </thead>
            <tbody>
              {punchLogs.map((log) => (
                <tr key={log.id}>
                  <td><strong>{formatDate(log.punchTime)}</strong></td>
                  <td>{log.employeeName || log.employeeCode || 'Staff Member'}</td>
                  <td><code className="table-code">{log.biometricPin || 'â€”'}</code></td>
                  <td>{log.deviceName || 'Terminal 1'}</td>
                  <td><StatusChip status={log.punchType || 'CHECK_IN'} /></td>
                  <td><StatusChip status={log.syncStatus || 'SYNCED'} /></td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </div>

      {/* Register Device Modal */}
      {isRegisterOpen ? (
        <div className="modal-backdrop" role="presentation">
          <div aria-labelledby="bio-title" aria-modal="true" className="modal-dialog" role="dialog">
            <div className="modal-header">
              <h2 id="bio-title">Register Biometric Attendance Device</h2>
              <button className="icon-button" onClick={() => setIsRegisterOpen(false)} type="button">
                <X aria-hidden="true" size={18} />
              </button>
            </div>
            <form
              onSubmit={(e) => {
                e.preventDefault()
                const fd = new FormData(e.currentTarget)
                registerMutation.mutate({
                  deviceName: String(fd.get('deviceName') ?? '').trim(),
                  protocol: String(fd.get('protocol') ?? 'ZK_TCP'),
                  deviceIp: String(fd.get('deviceIp') ?? '').trim() || undefined,
                  port: Number(fd.get('port') ?? 4370),
                  serialNumber: String(fd.get('serialNumber') ?? '').trim() || undefined,
                  location: String(fd.get('location') ?? '').trim() || undefined,
                  status: 'ONLINE',
                })
              }}
            >
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div>
                  <label className="form-label">Device Name *</label>
                  <input className="text-input" name="deviceName" placeholder="e.g. Main Gate ZKTeco K40" required type="text" />
                </div>
                <div>
                  <label className="form-label">Protocol</label>
                  <select className="select-input" defaultValue="ZK_TCP" name="protocol">
                    <option value="ZK_TCP">ZKTeco TCP/IP (Standard port 4370)</option>
                    <option value="ADMS_PUSH">ADMS Cloud Push (HTTP Webhook)</option>
                  </select>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 12 }}>
                  <div>
                    <label className="form-label">IP Address</label>
                    <input className="text-input" name="deviceIp" placeholder="192.168.1.201" type="text" />
                  </div>
                  <div>
                    <label className="form-label">Port</label>
                    <input className="text-input" defaultValue={4370} name="port" type="number" />
                  </div>
                </div>
                <div>
                  <label className="form-label">Physical Location</label>
                  <input className="text-input" name="location" placeholder="e.g. Factory Floor Entry / Main Reception" type="text" />
                </div>
              </div>
              <div className="modal-footer">
                <Button onClick={() => setIsRegisterOpen(false)} type="button" variant="secondary">Cancel</Button>
                <Button disabled={registerMutation.isPending} type="submit" variant="primary">Register Device</Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </section>
  )
}

import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  FileText,
  Plus,
  Trash2,
  AlertTriangle,
} from 'lucide-react'
import {
  Button,
  DataTable,
  FormField,
  FormGrid,
  Modal,
  PageHeader,
  SelectInput,
  StatusChip,
  TextInput,
  FilterTabs,
} from '@/design-system'
import { formatDate } from '@/shared/format/format'
import {
  getMyDocuments,
  getExpiringDocuments,
  uploadMyDocument,
  deleteEmployeeDocument,
} from '@/features/hr/hr-api'

const CATEGORY_OPTIONS = [
  { value: 'ID_PROOF', label: 'Identity Proof (Aadhaar / Passport / Voter ID)' },
  { value: 'ADDRESS_PROOF', label: 'Address Proof' },
  { value: 'ACADEMIC', label: 'Academic & Degree Certificates' },
  { value: 'CERTIFICATE', label: 'Professional Certifications' },
  { value: 'PREVIOUS_EMPLOYMENT', label: 'Previous Experience & Relieving' },
  { value: 'CONTRACT', label: 'Employment Contract & NDA' },
]

export function EmployeeDocumentsPage() {
  const [activeTab, setActiveTab] = useState<'mine' | 'expiring'>('mine')
  const [isUploadOpen, setIsUploadOpen] = useState(false)
  const [category, setCategory] = useState('ID_PROOF')
  const [title, setTitle] = useState('')
  const [expiryDate, setExpiryDate] = useState('')
  const [selectedFile, setSelectedFile] = useState<File | null>(null)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const queryClient = useQueryClient()

  const myDocsQuery = useQuery({
    queryKey: ['hr-my-documents'],
    queryFn: () => getMyDocuments(),
  })

  const expiringQuery = useQuery({
    queryKey: ['hr-expiring-documents'],
    queryFn: () => getExpiringDocuments(30),
    enabled: activeTab === 'expiring',
  })

  const uploadMutation = useMutation({
    mutationFn: async () => {
      if (!selectedFile) throw new Error('Please select a file to upload')
      if (!title.trim()) throw new Error('Please enter a document title')
      const fd = new FormData()
      fd.append('file', selectedFile)
      fd.append('title', title.trim())
      if (category) fd.append('category', category)
      if (expiryDate) fd.append('expiry', expiryDate)
      return uploadMyDocument(fd)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-my-documents'] })
      queryClient.invalidateQueries({ queryKey: ['hr-expiring-documents'] })
      setIsUploadOpen(false)
      setTitle('')
      setExpiryDate('')
      setSelectedFile(null)
      setErrorMessage(null)
    },
    onError: (err: unknown) => {
      const msg = err instanceof Error ? err.message : 'Upload failed'
      setErrorMessage(msg)
    },
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => deleteEmployeeDocument(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-my-documents'] })
      queryClient.invalidateQueries({ queryKey: ['hr-expiring-documents'] })
    },
  })

  const myDocs = myDocsQuery.data ?? []
  const expiringDocs = expiringQuery.data ?? []

  return (
    <div className="space-y-6">
      <PageHeader
        title="Employee Documents"
        description="Manage employee identification, KYC, qualifications, and monitor expiring certifications."
        actions={
          <Button variant="primary" onClick={() => setIsUploadOpen(true)}>
            <Plus className="mr-2 h-4 w-4" />
            Upload Document
          </Button>
        }
      />

      <FilterTabs<'mine' | 'expiring'>
        items={[
          { value: 'mine', label: 'My Documents', count: myDocs.length },
          { value: 'expiring', label: 'Expiring Watchlist (30 Days)' },
        ]}
        activeValue={activeTab}
        onChange={(tab) => setActiveTab(tab)}
      />

      {activeTab === 'mine' ? (
        myDocsQuery.isLoading ? (
          <div className="p-8 text-center text-sm text-[var(--color-text-muted)]">Loading documents...</div>
        ) : myDocs.length === 0 ? (
          <div className="p-8 text-center text-sm text-[var(--color-text-muted)]">
            No documents uploaded yet. Click &apos;Upload Document&apos; to add KYC or certificates.
          </div>
        ) : (
          <DataTable caption="My uploaded employee documents">
            <thead>
              <tr>
                <th scope="col">Document Title</th>
                <th scope="col">Category</th>
                <th scope="col">Expiry Date</th>
                <th scope="col">Uploaded On</th>
                <th scope="col" className="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {myDocs.map((item) => {
                const opt = CATEGORY_OPTIONS.find((c) => c.value === item.category)
                const isExp = item.expiryDate ? new Date(item.expiryDate) < new Date() : false
                return (
                  <tr key={item.id}>
                    <td>
                      <div className="flex items-center space-x-2">
                        <FileText className="h-4 w-4 text-[var(--color-text-muted)]" />
                        <span className="font-medium text-[var(--color-text-default)]">{item.title}</span>
                      </div>
                    </td>
                    <td>
                      <span className="inline-flex rounded bg-[var(--color-bg-subtle)] px-2 py-0.5 text-xs text-[var(--color-text-muted)]">
                        {opt ? (opt.label.split('(')[0]?.trim() ?? opt.label) : item.category || 'General'}
                      </span>
                    </td>
                    <td>
                      {item.expiryDate ? (
                        <span className={isExp ? 'font-mono text-xs font-semibold text-[var(--color-error)]' : 'font-mono text-xs text-[var(--color-text-default)]'}>
                          {formatDate(item.expiryDate)}
                          {isExp && ' (Expired)'}
                        </span>
                      ) : (
                        <span className="text-xs text-[var(--color-text-muted)]">No Expiry</span>
                      )}
                    </td>
                    <td>
                      <span className="font-mono text-xs text-[var(--color-text-muted)]">
                        {item.uploadedAt ? formatDate(item.uploadedAt) : '--'}
                      </span>
                    </td>
                    <td className="text-right">
                      <Button
                        variant="ghost"
                        className="text-[var(--color-error)]"
                        disabled={deleteMutation.isPending}
                        onClick={() => {
                          if (confirm('Delete document "' + item.title + '"?')) {
                            deleteMutation.mutate(item.id)
                          }
                        }}
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </DataTable>
        )
      ) : (
        expiringQuery.isLoading ? (
          <div className="p-8 text-center text-sm text-[var(--color-text-muted)]">Checking expiring documents...</div>
        ) : expiringDocs.length === 0 ? (
          <div className="p-8 text-center text-sm text-[var(--color-text-muted)]">
            No documents expiring within the next 30 days.
          </div>
        ) : (
          <DataTable caption="Expiring documents watchlist">
            <thead>
              <tr>
                <th scope="col">Document Title</th>
                <th scope="col">Category</th>
                <th scope="col">Expiry Date</th>
                <th scope="col">Status</th>
              </tr>
            </thead>
            <tbody>
              {expiringDocs.map((item) => (
                <tr key={item.id}>
                  <td>
                    <div className="flex items-center space-x-2">
                      <AlertTriangle className="h-4 w-4 text-[var(--color-warning)]" />
                      <span className="font-medium text-[var(--color-text-default)]">{item.title}</span>
                    </div>
                  </td>
                  <td>
                    <span className="inline-flex rounded bg-[var(--color-bg-subtle)] px-2 py-0.5 text-xs text-[var(--color-text-muted)]">
                      {item.category || 'General'}
                    </span>
                  </td>
                  <td>
                    <span className="font-mono text-xs font-semibold text-[var(--color-warning)]">
                      {item.expiryDate ? formatDate(item.expiryDate) : '--'}
                    </span>
                  </td>
                  <td>
                    <StatusChip status="PENDING">Expiring Soon</StatusChip>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )
      )}

      {isUploadOpen && (
        <Modal
          title="Upload Employee Document"
          isOpen={isUploadOpen}
          onClose={() => {
            setIsUploadOpen(false)
            setErrorMessage(null)
          }}
        >
          <form
            onSubmit={(e) => {
              e.preventDefault()
              uploadMutation.mutate()
            }}
            className="space-y-4"
          >
            {errorMessage && (
              <div className="rounded border border-[var(--color-error)] bg-[var(--color-bg-subtle)] p-3 text-sm text-[var(--color-error)]">
                {errorMessage}
              </div>
            )}

            <FormField label="Document Title *" htmlFor="docTitle">
              <TextInput
                id="docTitle"
                required
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="e.g. Aadhaar Card Front & Back"
              />
            </FormField>

            <FormGrid columns={2}>
              <FormField label="Category" htmlFor="docCategory">
                <SelectInput
                  id="docCategory"
                  value={category}
                  onChange={(e) => setCategory(e.target.value)}
                  options={CATEGORY_OPTIONS}
                />
              </FormField>

              <FormField label="Expiry Date (optional)" htmlFor="docExpiry">
                <TextInput
                  id="docExpiry"
                  type="date"
                  value={expiryDate}
                  onChange={(e) => setExpiryDate(e.target.value)}
                />
              </FormField>
            </FormGrid>

            <FormField label="Select File *" htmlFor="docFile">
              <input
                id="docFile"
                type="file"
                required
                className="block w-full text-sm text-[var(--color-text-default)] file:mr-4 file:rounded file:border-0 file:bg-[var(--color-brand)] file:px-4 file:py-2 file:text-sm file:font-semibold file:text-white hover:file:opacity-90"
                onChange={(e) => {
                  const f = e.target.files?.[0]
                  if (f) setSelectedFile(f)
                }}
              />
            </FormField>

            <div className="mt-6 flex justify-end space-x-3">
              <Button
                type="button"
                variant="secondary"
                onClick={() => {
                  setIsUploadOpen(false)
                  setErrorMessage(null)
                }}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                variant="primary"
                disabled={uploadMutation.isPending || !selectedFile || !title.trim()}
              >
                {uploadMutation.isPending ? 'Uploading...' : 'Upload'}
              </Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  )
}

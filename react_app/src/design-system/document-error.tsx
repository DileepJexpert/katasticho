import { ArrowLeft, AlertCircle } from 'lucide-react'
import { Button } from './button'

export interface DocumentErrorProps {
  onBack: () => void
  backLabel?: string
  title?: string
  message?: string
}

export function DocumentError({
  onBack,
  backLabel = 'Back to list',
  title = 'Document could not be loaded',
  message = 'The requested document does not exist, may have been removed, or you do not have permission to view it.',
}: DocumentErrorProps) {
  return (
    <section className="workspace-page">
      <div className="document-error__back">
        <Button onClick={onBack} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          {backLabel}
        </Button>
      </div>
      <div className="directory-state directory-state--error" role="alert">
        <AlertCircle size={32} className="document-error__icon" />
        <strong>{title}</strong>
        <p>{message}</p>
      </div>
    </section>
  )
}

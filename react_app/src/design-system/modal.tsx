import { useEffect, useId, useRef, type ReactNode } from 'react'
import { AlertCircle, X } from 'lucide-react'
import clsx from 'clsx'

export interface ModalProps {
  isOpen: boolean
  onClose: () => void
  title: string
  description?: string
  error?: string | null
  size?: 'sm' | 'md' | 'lg' | 'xl'
  children: ReactNode
  footer?: ReactNode
}

export function Modal({
  isOpen,
  onClose,
  title,
  description,
  error,
  size = 'md',
  children,
  footer,
}: ModalProps) {
  const titleId = useId()
  const descId = useId()
  const dialogRef = useRef<HTMLDivElement>(null)
  const previousActiveElement = useRef<HTMLElement | null>(null)

  useEffect(() => {
    if (!isOpen) return

    previousActiveElement.current = document.activeElement as HTMLElement | null

    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === 'Escape') {
        onClose()
        return
      }

      if (e.key === 'Tab' && dialogRef.current) {
        const focusableElements = dialogRef.current.querySelectorAll<HTMLElement>(
          'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
        )
        if (focusableElements.length === 0) return

        const firstElement = focusableElements[0]
        const lastElement = focusableElements[focusableElements.length - 1]

        if (e.shiftKey) {
          if (document.activeElement === firstElement) {
            e.preventDefault()
            lastElement.focus()
          }
        } else {
          if (document.activeElement === lastElement) {
            e.preventDefault()
            firstElement.focus()
          }
        }
      }
    }

    document.addEventListener('keydown', handleKeyDown)
    document.body.style.overflow = 'hidden'

    // Initial focus: find first input or close button
    const initialFocusable = dialogRef.current?.querySelector<HTMLElement>(
      'input:not([disabled]), select:not([disabled]), textarea:not([disabled]), button.modal-close-btn'
    )
    initialFocusable?.focus()

    return () => {
      document.removeEventListener('keydown', handleKeyDown)
      document.body.style.overflow = ''
      previousActiveElement.current?.focus?.()
    }
  }, [isOpen, onClose])

  if (!isOpen) return null

  const sizeClass =
    size === 'sm'
      ? 'modal-dialog--sm'
      : size === 'lg'
      ? 'modal-dialog--lg'
      : size === 'xl'
      ? 'modal-dialog--xl'
      : 'modal-dialog--md'

  return (
    <div
      aria-describedby={description ? descId : undefined}
      aria-labelledby={titleId}
      aria-modal="true"
      className="modal-backdrop"
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose()
      }}
      role="dialog"
    >
      <div ref={dialogRef} className={clsx('modal-dialog', sizeClass)} tabIndex={-1}>
        <header className="modal-header">
          <div>
            <h3 id={titleId}>{title}</h3>
            {description && (
              <p
                id={descId}
                style={{ fontSize: 'var(--text-xs)', color: 'var(--text-secondary)', marginTop: '2px' }}
              >
                {description}
              </p>
            )}
          </div>
          <button
            aria-label="Close dialog"
            className="modal-close-btn"
            onClick={onClose}
            type="button"
          >
            <X size={16} />
          </button>
        </header>
        <div className="modal-body">
          {error && (
            <div
              role="alert"
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                padding: '10px 14px',
                borderRadius: 'var(--radius)',
                backgroundColor: 'rgba(190, 58, 52, 0.08)',
                border: '1px solid var(--color-danger, #BE3A34)',
                color: 'var(--color-danger, #BE3A34)',
                fontSize: '0.875rem',
              }}
            >
              <AlertCircle size={16} />
              <span>{error}</span>
            </div>
          )}
          {children}
        </div>
        {footer && <footer className="modal-footer">{footer}</footer>}
      </div>
    </div>
  )
}

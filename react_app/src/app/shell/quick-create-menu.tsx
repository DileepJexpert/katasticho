import {
  Boxes,
  Briefcase,
  ChevronDown,
  ClipboardList,
  FileSpreadsheet,
  FileText,
  Landmark,
  Plus,
  ReceiptText,
  ShoppingBag,
  Truck,
  UsersRound,
} from 'lucide-react'
import { useState, useRef, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'

export interface QuickCreateAction {
  label: string
  to: string
  icon: typeof Plus
  group: 'Sales' | 'Purchases' | 'Operations' | 'Finance'
}

const actions: readonly QuickCreateAction[] = [
  { label: 'New Invoice', to: appRoutes.invoiceCreate, icon: ReceiptText, group: 'Sales' },
  { label: 'New Estimate / Quote', to: appRoutes.estimateCreate, icon: FileSpreadsheet, group: 'Sales' },
  { label: 'New Sales Order', to: appRoutes.salesOrderCreate, icon: ClipboardList, group: 'Sales' },
  { label: 'New Delivery Challan', to: appRoutes.deliveryChallanCreate, icon: Truck, group: 'Sales' },

  { label: 'New Purchase Order', to: appRoutes.purchaseOrderCreate, icon: ShoppingBag, group: 'Purchases' },
  { label: 'New Stock Receipt (GRN)', to: appRoutes.stockReceiptCreate, icon: Boxes, group: 'Purchases' },
  { label: 'New Vendor Bill', to: appRoutes.billCreate, icon: FileSpreadsheet, group: 'Purchases' },
  { label: 'New Debit Note', to: appRoutes.debitNoteCreate, icon: FileText, group: 'Purchases' },

  { label: 'New Item', to: appRoutes.items, icon: Boxes, group: 'Operations' },
  { label: 'New Contact', to: appRoutes.contactCreate, icon: UsersRound, group: 'Operations' },
  { label: 'New Work Order', to: appRoutes.workOrders, icon: Briefcase, group: 'Operations' },
  { label: 'New Journal Entry', to: appRoutes.journals, icon: Landmark, group: 'Finance' },
]

export function QuickCreateMenu({ expanded = false }: { expanded?: boolean }) {
  const [open, setOpen] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)
  const navigate = useNavigate()

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setOpen(false)
      }
    }
    if (open) {
      document.addEventListener('mousedown', handleClickOutside)
    }
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [open])

  function handleSelect(to: string) {
    setOpen(false)
    navigate(to)
  }

  return (
    <div className="quick-create-container" ref={menuRef}>
      {expanded ? (
        <Button
          className="quick-create-btn--expanded"
          onClick={() => setOpen((prev) => !prev)}
          variant="primary"
        >
          <Plus size={16} aria-hidden="true" />
          <span>Quick Create</span>
          <ChevronDown size={14} aria-hidden="true" />
        </Button>
      ) : (
        <button
          aria-label="Quick Create"
          className="quick-create-btn--icon"
          onClick={() => setOpen((prev) => !prev)}
          title="Quick Create"
          type="button"
        >
          <Plus size={18} aria-hidden="true" />
        </button>
      )}

      {open && (
        <div className="quick-create-dropdown" role="menu">
          <div className="quick-create-dropdown__header">
            <span>Quick Create Actions</span>
          </div>
          <div className="quick-create-dropdown__grid">
            {actions.map((action) => {
              const Icon = action.icon
              return (
                <button
                  className="quick-create-item"
                  key={action.label}
                  onClick={() => handleSelect(action.to)}
                  type="button"
                >
                  <span className="quick-create-item__icon">
                    <Icon size={14} aria-hidden="true" />
                  </span>
                  <span className="quick-create-item__label">{action.label}</span>
                </button>
              )
            })}
          </div>
        </div>
      )}
    </div>
  )
}

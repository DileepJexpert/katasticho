import { useMutation } from '@tanstack/react-query'
import { Button, Modal } from '@/design-system'

export function ConfirmedAction({ title, description, run, onClose, onDone, destructive = false }: {
  title: string; description: string; run: () => Promise<unknown>; onClose: () => void
  onDone: () => void; destructive?: boolean
}) {
  const mutation = useMutation({ mutationFn: run, onSuccess: onDone })
  return <Modal isOpen title={title} onClose={() => { if (!mutation.isPending) onClose() }} error={mutation.error?.message}
    footer={<><Button variant="secondary" disabled={mutation.isPending} onClick={onClose}>Cancel</Button>
      <Button variant={destructive ? 'destructive' : 'primary'} disabled={mutation.isPending} onClick={() => mutation.mutate()}>{mutation.isPending ? 'Working...' : 'Confirm'}</Button></>}>
    <p>{description}</p>
  </Modal>
}

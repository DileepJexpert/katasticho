import { useQuery } from '@tanstack/react-query'
import { Link, useParams } from 'react-router-dom'
import { Button, FactList, Money, PageHeader, StatusChip } from '@/design-system'
import { useSessionStore } from '@/shared/session/session-store'
import { franchiseIntegrationNotice, listFranchiseNodes } from './franchise-api'

export function FranchiseNodeDetailPage() {
  const { nodeId = '' } = useParams<{ nodeId: string }>()
  const orgId = useSessionStore((s) => s.user?.orgId)
  const query = useQuery({ queryKey: ['franchise-nodes', orgId], queryFn: listFranchiseNodes })
  const node = query.data?.find((n) => n.id === nodeId)
  return <section className="workspace-page">
    <PageHeader eyebrow="Franchise / Store management" title={node?.nodeName ?? 'Franchise store'} description={node?.nodeCode} actions={<Link to="/franchise">Back to stores</Link>} />
    {query.isPending ? <p role="status">Loading store...</p> : query.isError ? <div role="alert">{query.error.message}<Button onClick={() => query.refetch()}>Retry</Button></div> : !node ? <p role="alert">Store not found in this organisation.</p> : <div className="document-card">
      <FactList>
        <div><dt>Code</dt><dd className="table-code">{node.nodeCode}</dd></div>
        <div><dt>Ownership model</dt><dd>{node.nodeType}</dd></div>
        <div><dt>City</dt><dd>{node.city || '--'}</dd></div>
        <div><dt>Email</dt><dd>{node.contactEmail || '--'}</dd></div>
        <div><dt>Phone</dt><dd>{node.phone || '--'}</dd></div>
        <div><dt>Royalty rate</dt><dd>{node.royaltyRatePercent}%</dd></div>
        <div><dt>Fixed monthly fee</dt><dd><Money amount={node.fixedMonthlyFee} /></dd></div>
        <div><dt>Status</dt><dd><StatusChip status={node.active ? 'ACTIVE' : 'INACTIVE'} /></dd></div>
      </FactList>
    </div>}
    <p className="banner" role="note">{franchiseIntegrationNotice}</p>
  </section>
}

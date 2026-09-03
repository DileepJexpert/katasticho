export function PickProgress({ pickedCount, totalCount }: { pickedCount: number; totalCount: number }) {
  const value = totalCount > 0 ? Math.min(pickedCount / totalCount, 1) : 0
  const isComplete = totalCount > 0 && pickedCount === totalCount

  return (
    <div className={isComplete ? 'pick-progress pick-progress--complete' : 'pick-progress'} title="A line is counted after a picked quantity is recorded; individual quantities can still be partial.">
      <div className="pick-progress__meta"><span>{pickedCount} / {totalCount} lines</span><span>{Math.round(value * 100)}%</span></div>
      <progress aria-label={`${pickedCount} of ${totalCount} pick lines have a quantity recorded`} max={totalCount || 1} value={pickedCount} />
    </div>
  )
}

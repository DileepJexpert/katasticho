export function regularizationTime(workDate: string, inTime: string, outTime: string) {
  const start = inTime ? new Date(`${workDate}T${inTime}`).getTime() : undefined
  const end = outTime ? new Date(`${workDate}T${outTime}`).getTime() : undefined
  if (!workDate || (start === undefined && end === undefined) || (start !== undefined && !Number.isFinite(start)) || (end !== undefined && !Number.isFinite(end)) || (start !== undefined && end !== undefined && end < start)) throw new Error('Enter a valid work date and at least one punch. Punch-out must not precede punch-in.')
  return { ...(start === undefined ? {} : { punchIn: new Date(start).toISOString() }), ...(end === undefined ? {} : { punchOut: new Date(end).toISOString() }) }
}

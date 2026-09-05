export function shipmentSchedule(departure: string, arrival: string): { valid: boolean; estimatedDeparture?: string; estimatedArrival?: string } {
  const start = departure ? new Date(departure).getTime() : undefined
  const end = arrival ? new Date(arrival).getTime() : undefined
  if ((start !== undefined && !Number.isFinite(start)) || (end !== undefined && !Number.isFinite(end)) || (start !== undefined && end !== undefined && end < start)) return { valid: false }
  return { valid: true, ...(start === undefined ? {} : { estimatedDeparture: new Date(start).toISOString() }), ...(end === undefined ? {} : { estimatedArrival: new Date(end).toISOString() }) }
}

type ProductMetadata = {
  sku: string | null
  hsnCode: string | null
  rackLocationCode: string | null
  batchNumber: string | null
}

/** Keeps statutory and operational identifiers visible in fast POS search. */
export function formatPosProductMetadata(product: ProductMetadata): string {
  return [
    product.sku,
    product.hsnCode ? `HSN ${product.hsnCode}` : null,
    product.rackLocationCode ? `Rack ${product.rackLocationCode}` : null,
    product.batchNumber ? `Batch ${product.batchNumber}` : null,
  ].filter(Boolean).join(' / ')
}

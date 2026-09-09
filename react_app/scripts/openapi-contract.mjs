import { createHash } from 'node:crypto'
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import openapiTS, { astToString } from 'openapi-typescript'

const scriptDirectory = dirname(fileURLToPath(import.meta.url))
const reactRoot = resolve(scriptDirectory, '..')
const repositoryRoot = resolve(reactRoot, '..')
const snapshotPath = resolve(repositoryRoot, 'docs', 'contracts', 'openapi.json')
const metadataPath = resolve(repositoryRoot, 'docs', 'contracts', 'openapi-metadata.json')
const ledgerPath = resolve(repositoryRoot, 'docs', 'contracts', 'openapi-endpoints.csv')
const typesPath = resolve(reactRoot, 'src', 'api', 'generated', 'schema.d.ts')
const sourceUrl = process.env.OPENAPI_URL ?? 'http://127.0.0.1:8080/v3/api-docs'
const methods = ['get', 'post', 'put', 'patch', 'delete', 'options', 'head', 'trace']

function sortDeep(value) {
  if (Array.isArray(value)) return value.map(sortDeep)
  if (value === null || typeof value !== 'object') return value

  return Object.fromEntries(
    Object.entries(value)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, child]) => [key, sortDeep(child)]),
  )
}

function validateContract(contract) {
  if (!contract || typeof contract !== 'object') throw new Error('OpenAPI response must be a JSON object.')
  if (typeof contract.openapi !== 'string' || !contract.openapi.startsWith('3.')) {
    throw new Error(`Expected an OpenAPI 3.x document, received ${String(contract.openapi ?? 'no version')}.`)
  }
  if (!contract.info || typeof contract.info.title !== 'string' || typeof contract.info.version !== 'string') {
    throw new Error('OpenAPI info.title and info.version are required.')
  }
  if (!contract.paths || typeof contract.paths !== 'object' || Object.keys(contract.paths).length === 0) {
    throw new Error('OpenAPI document does not contain any paths.')
  }
}

function contractText(contract) {
  return `${JSON.stringify(sortDeep(contract), null, 2)}\n`
}

function sha256(text) {
  return createHash('sha256').update(text).digest('hex')
}

function csvCell(value) {
  const text = String(value ?? '')
  return /[",\r\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text
}

function securityLabel(security) {
  if (!Array.isArray(security) || security.length === 0) return 'PUBLIC'
  return security
    .map((alternative) => Object.keys(alternative).sort().join(' + '))
    .filter(Boolean)
    .join(' OR ')
}

function endpointRows(contract) {
  const rows = []
  for (const [path, pathItem] of Object.entries(contract.paths)) {
    if (!pathItem || typeof pathItem !== 'object') continue
    for (const method of methods) {
      const operation = pathItem[method]
      if (!operation || typeof operation !== 'object') continue
      rows.push({
        operationId: operation.operationId ?? '',
        method: method.toUpperCase(),
        path,
        tags: Array.isArray(operation.tags) ? operation.tags.join(' | ') : '',
        summary: operation.summary ?? '',
        security: securityLabel(operation.security ?? contract.security),
        deprecated: operation.deprecated === true ? 'true' : 'false',
      })
    }
  }
  return rows.sort((left, right) => left.path.localeCompare(right.path) || left.method.localeCompare(right.method))
}

function ledgerText(rows) {
  const headings = ['operationId', 'method', 'path', 'tags', 'summary', 'security', 'deprecated']
  return `${[
    headings.join(','),
    ...rows.map((row) => headings.map((heading) => csvCell(row[heading])).join(',')),
  ].join('\n')}\n`
}

async function generatedArtifacts(contract) {
  validateContract(contract)
  const snapshot = contractText(contract)
  const hash = sha256(snapshot)
  const rows = endpointRows(contract)
  const ast = await openapiTS(contract)
  const types = `// Generated from docs/contracts/openapi.json. Do not edit.\n// Contract SHA-256: ${hash}\n${astToString(ast)}`
  const metadata = `${JSON.stringify({
    openapi: contract.openapi,
    title: contract.info.title,
    version: contract.info.version,
    sha256: hash,
    operationCount: rows.length,
  }, null, 2)}\n`

  return { snapshot, metadata, ledger: ledgerText(rows), types, operationCount: rows.length, hash }
}

async function readSnapshot() {
  try {
    return JSON.parse(await readFile(snapshotPath, 'utf8'))
  } catch (error) {
    if (error && error.code === 'ENOENT') {
      throw new Error(`OpenAPI snapshot is missing at ${snapshotPath}. Start Spring Boot and run npm run contract:sync.`, { cause: error })
    }
    throw error
  }
}

async function fetchSnapshot() {
  let response
  try {
    response = await fetch(sourceUrl, { headers: { Accept: 'application/json' } })
  } catch (error) {
    throw new Error(`Could not reach ${sourceUrl}: ${error instanceof Error ? error.message : String(error)}`, { cause: error })
  }
  if (!response.ok) throw new Error(`OpenAPI export failed: HTTP ${response.status} ${response.statusText}`)
  return response.json()
}

async function writeArtifacts(artifacts) {
  await mkdir(dirname(snapshotPath), { recursive: true })
  await mkdir(dirname(typesPath), { recursive: true })
  await Promise.all([
    writeFile(snapshotPath, artifacts.snapshot),
    writeFile(metadataPath, artifacts.metadata),
    writeFile(ledgerPath, artifacts.ledger),
    writeFile(typesPath, artifacts.types),
  ])
}

async function checkArtifacts(artifacts) {
  const expected = [
    [snapshotPath, artifacts.snapshot],
    [metadataPath, artifacts.metadata],
    [ledgerPath, artifacts.ledger],
    [typesPath, artifacts.types],
  ]
  const drift = []
  for (const [path, content] of expected) {
    let current
    try {
      current = await readFile(path, 'utf8')
    } catch (error) {
      if (error && error.code === 'ENOENT') {
        drift.push(`${path} is missing`)
        continue
      }
      throw error
    }
    if (current !== content) drift.push(`${path} is stale`)
  }
  if (drift.length > 0) throw new Error(`Generated OpenAPI artifacts are not synchronized:\n- ${drift.join('\n- ')}`)
}

async function main() {
  const mode = process.argv[2] ?? 'check'
  if (!['sync', 'generate', 'check', 'self-test'].includes(mode)) {
    throw new Error('Usage: node scripts/openapi-contract.mjs <sync|generate|check|self-test>')
  }

  if (mode === 'self-test') {
    const sample = {
      openapi: '3.1.0',
      info: { title: 'Contract workflow test', version: '1.0.0' },
      paths: {
        '/api/v1/public': {
          get: { operationId: 'publicRead', responses: { 200: { description: 'OK' } }, security: [] },
        },
        '/api/v1/secured': {
          post: {
            operationId: 'securedWrite',
            responses: { 200: { description: 'OK' } },
            security: [{ BearerAuth: [] }, { ApiKeyAuth: [] }],
          },
        },
      },
    }
    const artifacts = await generatedArtifacts(sample)
    if (artifacts.operationCount !== 2
        || !artifacts.ledger.includes('PUBLIC')
        || !artifacts.ledger.includes('BearerAuth OR ApiKeyAuth')
        || !artifacts.types.includes('publicRead')) {
      throw new Error('OpenAPI contract workflow self-test failed.')
    }
    console.log('OpenAPI contract workflow self-test passed.')
    return
  }

  const contract = mode === 'sync' ? await fetchSnapshot() : await readSnapshot()
  const artifacts = await generatedArtifacts(contract)
  if (mode === 'check') await checkArtifacts(artifacts)
  else await writeArtifacts(artifacts)

  console.log(`OpenAPI ${mode} complete: ${artifacts.operationCount} operations, SHA-256 ${artifacts.hash}`)
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error)
  process.exitCode = 1
})

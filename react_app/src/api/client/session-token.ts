let accessToken: string | null = null
let organisationId: string | null = null

export function getAccessToken() {
  return accessToken
}

export function getOrganisationId() {
  return organisationId
}

export function setSessionToken(token: string, orgId: string) {
  accessToken = token
  organisationId = orgId
}

export function clearSessionToken() {
  accessToken = null
  organisationId = null
}

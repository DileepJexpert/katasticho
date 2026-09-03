export type UserInfo = {
  id: string
  orgId: string
  fullName: string
  email: string | null
  phone: string | null
  role: string
  orgName: string
  industry: string | null
  businessType: string | null
  industryCode: string | null
  onboardingCompleted: boolean
  defaultLandingPage: string | null
}

export type WebAuthResponse = {
  accessToken: string
  user: UserInfo
}

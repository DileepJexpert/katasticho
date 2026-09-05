import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  User,
  Plus,
  Trash2,
  CheckCircle,
} from 'lucide-react'
import {
  Button,
  DataTable,
  FormField,
  FormGrid,
  Modal,
  PageHeader,
  SelectInput,
  TextInput,
  FilterTabs,
  StatusChip,
} from '@/design-system'
import { formatDate } from '@/shared/format/format'
import {
  getMyProfile,
  claimMyProfile,
  updateMyProfile,
  addMyFamily,
  deleteMyFamily,
  addMyEducation,
  deleteMyEducation,
  addMyExperience,
  deleteMyExperience,
} from '@/features/hr/hr-api'

type TabKey = 'personal' | 'statutory' | 'family' | 'education' | 'experience'

export function MyProfilePage() {
  const [activeTab, setActiveTab] = useState<TabKey>('personal')
  const [isFamilyModalOpen, setIsFamilyModalOpen] = useState(false)
  const [isEduModalOpen, setIsEduModalOpen] = useState(false)
  const [isExpModalOpen, setIsExpModalOpen] = useState(false)
  const [saveSuccessMsg, setSaveSuccessMsg] = useState(false)

  const queryClient = useQueryClient()

  const { data, isLoading, error, refetch } = useQuery({
    queryKey: ['hr-my-profile'],
    queryFn: () => getMyProfile(),
    retry: false,
  })

  const claimMutation = useMutation({
    mutationFn: () => claimMyProfile(),
    onSuccess: () => {
      refetch()
    },
  })

  // Update personal details mutation
  const updateMutation = useMutation({
    mutationFn: (form: Record<string, string>) =>
      updateMyProfile({
        phone: form.phone,
        personalEmail: form.personalEmail,
        dateOfBirth: form.dateOfBirth || null,
        gender: form.gender,
        maritalStatus: form.maritalStatus,
        bloodGroup: form.bloodGroup,
        nationality: form.nationality,
        currentAddressLine1: form.currentAddressLine1,
        currentCity: form.currentCity,
        currentState: form.currentState,
        currentPincode: form.currentPincode,
        emergencyContactName: form.emergencyContactName,
        emergencyContactPhone: form.emergencyContactPhone,
        emergencyContactRelationship: form.emergencyContactRelationship,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-my-profile'] })
      setSaveSuccessMsg(true)
      setTimeout(() => setSaveSuccessMsg(false), 3000)
    },
  })

  // Family mutation
  const [familyForm, setFamilyForm] = useState({ name: '', relationship: 'SPOUSE', dateOfBirth: '', dependent: true })
  const addFamilyMutation = useMutation({
    mutationFn: () => addMyFamily(familyForm),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-my-profile'] })
      setIsFamilyModalOpen(false)
      setFamilyForm({ name: '', relationship: 'SPOUSE', dateOfBirth: '', dependent: true })
    },
  })
  const deleteFamilyMutation = useMutation({
    mutationFn: (id: string) => deleteMyFamily(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['hr-my-profile'] }),
  })

  // Education mutation
  const [eduForm, setEduForm] = useState({ degree: '', institution: '', passingYear: '', scorePercentage: '' })
  const addEduMutation = useMutation({
    mutationFn: () =>
      addMyEducation({
        degree: eduForm.degree,
        institution: eduForm.institution,
        passingYear: eduForm.passingYear ? parseInt(eduForm.passingYear) : undefined,
        scorePercentage: eduForm.scorePercentage || undefined,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-my-profile'] })
      setIsEduModalOpen(false)
      setEduForm({ degree: '', institution: '', passingYear: '', scorePercentage: '' })
    },
  })
  const deleteEduMutation = useMutation({
    mutationFn: (id: string) => deleteMyEducation(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['hr-my-profile'] }),
  })

  // Experience mutation
  const [expForm, setExpForm] = useState({ companyName: '', designation: '', fromDate: '', toDate: '', lastSalary: '' })
  const addExpMutation = useMutation({
    mutationFn: () =>
      addMyExperience({
        companyName: expForm.companyName,
        designation: expForm.designation,
        fromDate: expForm.fromDate || undefined,
        toDate: expForm.toDate || undefined,
        lastSalary: expForm.lastSalary ? parseFloat(expForm.lastSalary) : undefined,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-my-profile'] })
      setIsExpModalOpen(false)
      setExpForm({ companyName: '', designation: '', fromDate: '', toDate: '', lastSalary: '' })
    },
  })
  const deleteExpMutation = useMutation({
    mutationFn: (id: string) => deleteMyExperience(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['hr-my-profile'] }),
  })

  if (isLoading) {
    return <div className="p-8 text-center text-[var(--color-text-muted)]">Loading your employee profile...</div>
  }

  // If user is not linked to an employee row yet
  if (error || !data?.employee) {
    return (
      <div className="space-y-6">
        <PageHeader
          title="My Profile & Self-Service"
          description="View and manage your employee profile, family dependents, education credentials, and prior experience."
        />
        <div className="mx-auto max-w-lg rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-8 text-center shadow-sm">
          <User className="mx-auto h-12 w-12 text-[var(--color-text-muted)]" />
          <h3 className="mt-4 text-lg font-semibold text-[var(--color-text-default)]">Employee Profile Not Linked</h3>
          <p className="mt-2 text-sm text-[var(--color-text-muted)]">
            Your login account is not yet associated with an employee master record. You can create and link your profile now.
          </p>
          <div className="mt-6">
            <Button
              variant="primary"
              disabled={claimMutation.isPending}
              onClick={() => claimMutation.mutate()}
            >
              {claimMutation.isPending ? 'Linking Profile...' : 'Claim / Create My Profile'}
            </Button>
          </div>
        </div>
      </div>
    )
  }

  const employee = data.employee

  return (
    <div className="space-y-6">
      <PageHeader
        title="My Profile & Self-Service"
        description="Manage your personal information, address, family dependents, and employment credentials."
      />

      {/* Header Profile Badge */}
      <div className="flex flex-col gap-4 rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-6 shadow-sm md:flex-row md:items-center md:justify-between">
        <div className="flex items-center space-x-4">
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-[var(--color-brand)]/10 text-xl font-bold text-[var(--color-brand)]">
            {employee.fullName.slice(0, 2).toUpperCase()}
          </div>
          <div>
            <div className="flex items-center space-x-2">
              <h2 className="text-xl font-bold text-[var(--color-text-default)]">{employee.fullName}</h2>
              <StatusChip status={employee.employmentStatus || 'ACTIVE'}>{employee.employmentStatus || 'Active'}</StatusChip>
            </div>
            <div className="mt-1 flex flex-wrap items-center gap-3 text-sm text-[var(--color-text-muted)]">
              <span className="font-mono text-xs font-semibold text-[var(--color-brand)]">
                {employee.employeeCode || 'NO CODE'}
              </span>
              <span>·</span>
              <span>{employee.designation || 'Staff Member'}</span>
              <span>·</span>
              <span>{employee.department || 'General'}</span>
            </div>
          </div>
        </div>
        <div className="text-xs text-[var(--color-text-muted)] md:text-right">
          <div>Joining Date: <span className="font-mono">{employee.dateOfJoining ? formatDate(employee.dateOfJoining) : '--'}</span></div>
          <div>Work Email: <span className="font-mono">{employee.email || '--'}</span></div>
        </div>
      </div>

      <FilterTabs<TabKey>
        items={[
          { value: 'personal', label: 'Personal & Contact' },
          { value: 'statutory', label: 'Employment & Statutory' },
          { value: 'family', label: 'Family', count: data.family.length },
          { value: 'education', label: 'Education', count: data.education.length },
          { value: 'experience', label: 'Experience', count: data.experience.length },
        ]}
        activeValue={activeTab}
        onChange={(tab) => setActiveTab(tab)}
      />

      {/* TAB 1: Personal & Contact */}
      {activeTab === 'personal' && (
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-6 shadow-sm">
          <form
            onSubmit={(e) => {
              e.preventDefault()
              const fd = new FormData(e.currentTarget)
              const payload: Record<string, string> = {}
              fd.forEach((val, key) => {
                payload[key] = val.toString()
              })
              updateMutation.mutate(payload)
            }}
            className="space-y-6"
          >
            {saveSuccessMsg && (
              <div className="flex items-center space-x-2 rounded border border-[var(--color-brand)] bg-[var(--color-brand)]/10 p-3 text-sm font-medium text-[var(--color-brand)]">
                <CheckCircle className="h-4 w-4" />
                <span>Profile updated successfully!</span>
              </div>
            )}

            <div>
              <h4 className="mb-4 text-sm font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
                Contact Information
              </h4>
              <FormGrid columns={2}>
                <FormField label="Mobile Phone" htmlFor="phone">
                  <TextInput
                    id="phone"
                    name="phone"
                    defaultValue={employee.phone || ''}
                    placeholder="+91 98765 43210"
                  />
                </FormField>
                <FormField label="Personal Email" htmlFor="personalEmail">
                  <TextInput
                    id="personalEmail"
                    name="personalEmail"
                    type="email"
                    defaultValue={employee.personalEmail || ''}
                    placeholder="you@example.com"
                  />
                </FormField>
              </FormGrid>
            </div>

            <div>
              <h4 className="mb-4 text-sm font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
                Personal Demographics
              </h4>
              <FormGrid columns={3}>
                <FormField label="Date of Birth" htmlFor="dateOfBirth">
                  <TextInput
                    id="dateOfBirth"
                    name="dateOfBirth"
                    type="date"
                    defaultValue={employee.dateOfBirth || ''}
                  />
                </FormField>
                <FormField label="Gender" htmlFor="gender">
                  <SelectInput
                    id="gender"
                    name="gender"
                    defaultValue={employee.gender || 'MALE'}
                    options={[
                      { value: 'MALE', label: 'Male' },
                      { value: 'FEMALE', label: 'Female' },
                      { value: 'OTHER', label: 'Other' },
                    ]}
                  />
                </FormField>
                <FormField label="Blood Group" htmlFor="bloodGroup">
                  <TextInput
                    id="bloodGroup"
                    name="bloodGroup"
                    defaultValue={employee.bloodGroup || ''}
                    placeholder="e.g. O+, B+, A-"
                  />
                </FormField>
              </FormGrid>
            </div>

            <div>
              <h4 className="mb-4 text-sm font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
                Current Residential Address
              </h4>
              <FormGrid columns={2}>
                <FormField label="Address Line" htmlFor="currentAddressLine1">
                  <TextInput
                    id="currentAddressLine1"
                    name="currentAddressLine1"
                    defaultValue={employee.currentAddressLine1 || ''}
                    placeholder="Flat / House / Street"
                  />
                </FormField>
                <FormField label="City" htmlFor="currentCity">
                  <TextInput
                    id="currentCity"
                    name="currentCity"
                    defaultValue={employee.currentCity || ''}
                  />
                </FormField>
                <FormField label="State" htmlFor="currentState">
                  <TextInput
                    id="currentState"
                    name="currentState"
                    defaultValue={employee.currentState || ''}
                  />
                </FormField>
                <FormField label="PIN Code" htmlFor="currentPincode">
                  <TextInput
                    id="currentPincode"
                    name="currentPincode"
                    defaultValue={employee.currentPincode || ''}
                  />
                </FormField>
              </FormGrid>
            </div>

            <div>
              <h4 className="mb-4 text-sm font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
                Emergency Contact
              </h4>
              <FormGrid columns={3}>
                <FormField label="Contact Person Name" htmlFor="emergencyContactName">
                  <TextInput
                    id="emergencyContactName"
                    name="emergencyContactName"
                    defaultValue={employee.emergencyContactName || ''}
                  />
                </FormField>
                <FormField label="Relationship" htmlFor="emergencyContactRelationship">
                  <TextInput
                    id="emergencyContactRelationship"
                    name="emergencyContactRelationship"
                    defaultValue={employee.emergencyContactRelationship || ''}
                    placeholder="Spouse, Parent, Sibling"
                  />
                </FormField>
                <FormField label="Emergency Phone" htmlFor="emergencyContactPhone">
                  <TextInput
                    id="emergencyContactPhone"
                    name="emergencyContactPhone"
                    defaultValue={employee.emergencyContactPhone || ''}
                  />
                </FormField>
              </FormGrid>
            </div>

            <div className="flex justify-end">
              <Button type="submit" variant="primary" disabled={updateMutation.isPending}>
                {updateMutation.isPending ? 'Saving...' : 'Save Profile Changes'}
              </Button>
            </div>
          </form>
        </div>
      )}

      {/* TAB 2: Employment & Statutory (Read Only) */}
      {activeTab === 'statutory' && (
        <div className="space-y-6 rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-6 shadow-sm">
          <div>
            <h4 className="mb-2 text-sm font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
              Official Employment Credentials
            </h4>
            <p className="mb-4 text-xs text-[var(--color-text-muted)]">
              These details are managed centrally by the HR / Payroll administration team.
            </p>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
              <div className="rounded border border-[var(--color-border)] p-3">
                <span className="text-xs text-[var(--color-text-muted)]">Official Designation</span>
                <div className="mt-1 font-medium text-[var(--color-text-default)]">{employee.designation || '--'}</div>
              </div>
              <div className="rounded border border-[var(--color-border)] p-3">
                <span className="text-xs text-[var(--color-text-muted)]">Department</span>
                <div className="mt-1 font-medium text-[var(--color-text-default)]">{employee.department || '--'}</div>
              </div>
              <div className="rounded border border-[var(--color-border)] p-3">
                <span className="text-xs text-[var(--color-text-muted)]">Date of Joining</span>
                <div className="mt-1 font-mono text-sm text-[var(--color-text-default)]">
                  {employee.dateOfJoining ? formatDate(employee.dateOfJoining) : '--'}
                </div>
              </div>
            </div>
          </div>

          <div>
            <h4 className="mb-4 text-sm font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
              Statutory KYC & Registrations
            </h4>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-4">
              <div className="rounded border border-[var(--color-border)] p-3">
                <span className="text-xs text-[var(--color-text-muted)]">Income Tax PAN</span>
                <div className="mt-1 font-mono text-sm font-semibold text-[var(--color-text-default)]">
                  {employee.pan || 'NOT PROVIDED'}
                </div>
              </div>
              <div className="rounded border border-[var(--color-border)] p-3">
                <span className="text-xs text-[var(--color-text-muted)]">PF UAN Number</span>
                <div className="mt-1 font-mono text-sm font-semibold text-[var(--color-text-default)]">
                  {employee.uan || 'NOT APPLICABLE'}
                </div>
              </div>
              <div className="rounded border border-[var(--color-border)] p-3">
                <span className="text-xs text-[var(--color-text-muted)]">ESI Insurance Number</span>
                <div className="mt-1 font-mono text-sm font-semibold text-[var(--color-text-default)]">
                  {employee.esiNumber || 'NOT APPLICABLE'}
                </div>
              </div>
              <div className="rounded border border-[var(--color-border)] p-3">
                <span className="text-xs text-[var(--color-text-muted)]">Aadhaar (Last 4 digits)</span>
                <div className="mt-1 font-mono text-sm font-semibold text-[var(--color-text-default)]">
                  {employee.aadhaarLast4 ? 'XXXX-XXXX-' + employee.aadhaarLast4 : 'NOT PROVIDED'}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* TAB 3: Family Dependents */}
      {activeTab === 'family' && (
        <div className="space-y-4">
          <div className="flex justify-end">
            <Button variant="primary" onClick={() => setIsFamilyModalOpen(true)}>
              <Plus className="mr-2 h-4 w-4" /> Add Family Member
            </Button>
          </div>
          {data.family.length === 0 ? (
            <div className="p-8 text-center text-sm text-[var(--color-text-muted)]">
              No family members or dependents added yet.
            </div>
          ) : (
            <DataTable caption="Family dependents list">
              <thead>
                <tr>
                  <th scope="col">Full Name</th>
                  <th scope="col">Relationship</th>
                  <th scope="col">Date of Birth</th>
                  <th scope="col">Dependent</th>
                  <th scope="col" className="text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {data.family.map((f) => (
                  <tr key={f.id}>
                    <td><span className="font-medium text-[var(--color-text-default)]">{f.name}</span></td>
                    <td><span className="text-xs text-[var(--color-text-muted)]">{f.relationship}</span></td>
                    <td>
                      <span className="font-mono text-xs text-[var(--color-text-muted)]">
                        {f.dateOfBirth ? formatDate(f.dateOfBirth) : '--'}
                      </span>
                    </td>
                    <td>
                      <span className={f.dependent ? 'inline-flex rounded bg-[var(--color-brand)]/10 px-2 py-0.5 text-xs font-semibold text-[var(--color-brand)]' : 'inline-flex rounded bg-[var(--color-bg-subtle)] px-2 py-0.5 text-xs font-semibold text-[var(--color-text-muted)]'}>
                        {f.dependent ? 'Yes' : 'No'}
                      </span>
                    </td>
                    <td className="text-right">
                      <Button
                        variant="ghost"
                        className="text-[var(--color-error)]"
                        disabled={deleteFamilyMutation.isPending}
                        onClick={() => {
                          if (confirm('Remove ' + f.name + '?')) deleteFamilyMutation.mutate(f.id)
                        }}
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </div>
      )}

      {/* TAB 4: Education */}
      {activeTab === 'education' && (
        <div className="space-y-4">
          <div className="flex justify-end">
            <Button variant="primary" onClick={() => setIsEduModalOpen(true)}>
              <Plus className="mr-2 h-4 w-4" /> Add Qualification
            </Button>
          </div>
          {data.education.length === 0 ? (
            <div className="p-8 text-center text-sm text-[var(--color-text-muted)]">
              No academic records or qualifications added yet.
            </div>
          ) : (
            <DataTable caption="Academic qualification list">
              <thead>
                <tr>
                  <th scope="col">Degree / Course</th>
                  <th scope="col">Institution / Board</th>
                  <th scope="col">Passing Year</th>
                  <th scope="col">Score / Grade</th>
                  <th scope="col" className="text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {data.education.map((e) => (
                  <tr key={e.id}>
                    <td><span className="font-medium text-[var(--color-text-default)]">{e.degree}</span></td>
                    <td><span className="text-sm text-[var(--color-text-muted)]">{e.institution}</span></td>
                    <td><span className="font-mono text-xs text-[var(--color-text-default)]">{e.passingYear || '--'}</span></td>
                    <td><span className="font-mono text-xs text-[var(--color-text-default)]">{e.scorePercentage ? e.scorePercentage + '%' : '--'}</span></td>
                    <td className="text-right">
                      <Button
                        variant="ghost"
                        className="text-[var(--color-error)]"
                        disabled={deleteEduMutation.isPending}
                        onClick={() => {
                          if (confirm('Remove ' + e.degree + '?')) deleteEduMutation.mutate(e.id)
                        }}
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </div>
      )}

      {/* TAB 5: Work Experience */}
      {activeTab === 'experience' && (
        <div className="space-y-4">
          <div className="flex justify-end">
            <Button variant="primary" onClick={() => setIsExpModalOpen(true)}>
              <Plus className="mr-2 h-4 w-4" /> Add Prior Experience
            </Button>
          </div>
          {data.experience.length === 0 ? (
            <div className="p-8 text-center text-sm text-[var(--color-text-muted)]">
              No prior work experience records added yet.
            </div>
          ) : (
            <DataTable caption="Prior employment history">
              <thead>
                <tr>
                  <th scope="col">Company Name</th>
                  <th scope="col">Designation</th>
                  <th scope="col">Duration</th>
                  <th scope="col" className="text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {data.experience.map((x) => (
                  <tr key={x.id}>
                    <td><span className="font-medium text-[var(--color-text-default)]">{x.companyName}</span></td>
                    <td><span className="text-sm text-[var(--color-text-muted)]">{x.designation}</span></td>
                    <td>
                      <span className="font-mono text-xs text-[var(--color-text-muted)]">
                        {x.fromDate ? formatDate(x.fromDate) : '--'} → {x.toDate ? formatDate(x.toDate) : 'Present'}
                      </span>
                    </td>
                    <td className="text-right">
                      <Button
                        variant="ghost"
                        className="text-[var(--color-error)]"
                        disabled={deleteExpMutation.isPending}
                        onClick={() => {
                          if (confirm('Remove experience at ' + x.companyName + '?')) deleteExpMutation.mutate(x.id)
                        }}
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </div>
      )}

      {/* Family Modal */}
      {isFamilyModalOpen && (
        <Modal title="Add Family Member" isOpen={isFamilyModalOpen} onClose={() => setIsFamilyModalOpen(false)}>
          <form
            onSubmit={(e) => {
              e.preventDefault()
              addFamilyMutation.mutate()
            }}
            className="space-y-4"
          >
            <FormField label="Full Name *" htmlFor="famName">
              <TextInput
                id="famName"
                required
                value={familyForm.name}
                onChange={(e) => setFamilyForm({ ...familyForm, name: e.target.value })}
              />
            </FormField>
            <FormGrid columns={2}>
              <FormField label="Relationship" htmlFor="famRel">
                <SelectInput
                  id="famRel"
                  value={familyForm.relationship}
                  onChange={(e) => setFamilyForm({ ...familyForm, relationship: e.target.value })}
                  options={[
                    { value: 'SPOUSE', label: 'Spouse' },
                    { value: 'CHILD', label: 'Child / Dependent' },
                    { value: 'PARENT', label: 'Parent' },
                    { value: 'SIBLING', label: 'Sibling' },
                  ]}
                />
              </FormField>
              <FormField label="Date of Birth" htmlFor="famDob">
                <TextInput
                  id="famDob"
                  type="date"
                  value={familyForm.dateOfBirth}
                  onChange={(e) => setFamilyForm({ ...familyForm, dateOfBirth: e.target.value })}
                />
              </FormField>
            </FormGrid>
            <div className="flex justify-end space-x-3">
              <Button type="button" variant="secondary" onClick={() => setIsFamilyModalOpen(false)}>
                Cancel
              </Button>
              <Button type="submit" variant="primary" disabled={addFamilyMutation.isPending || !familyForm.name.trim()}>
                Add Member
              </Button>
            </div>
          </form>
        </Modal>
      )}

      {/* Education Modal */}
      {isEduModalOpen && (
        <Modal title="Add Academic Qualification" isOpen={isEduModalOpen} onClose={() => setIsEduModalOpen(false)}>
          <form
            onSubmit={(e) => {
              e.preventDefault()
              addEduMutation.mutate()
            }}
            className="space-y-4"
          >
            <FormField label="Degree / Diploma *" htmlFor="eduDegree">
              <TextInput
                id="eduDegree"
                required
                placeholder="e.g. B.Tech Computer Science"
                value={eduForm.degree}
                onChange={(e) => setEduForm({ ...eduForm, degree: e.target.value })}
              />
            </FormField>
            <FormField label="Institution / University *" htmlFor="eduInst">
              <TextInput
                id="eduInst"
                required
                placeholder="e.g. Mumbai University"
                value={eduForm.institution}
                onChange={(e) => setEduForm({ ...eduForm, institution: e.target.value })}
              />
            </FormField>
            <FormGrid columns={2}>
              <FormField label="Passing Year" htmlFor="eduYear">
                <TextInput
                  id="eduYear"
                  type="number"
                  placeholder="2022"
                  value={eduForm.passingYear}
                  onChange={(e) => setEduForm({ ...eduForm, passingYear: e.target.value })}
                />
              </FormField>
              <FormField label="Percentage / CGPA" htmlFor="eduScore">
                <TextInput
                  id="eduScore"
                  placeholder="82.5"
                  value={eduForm.scorePercentage}
                  onChange={(e) => setEduForm({ ...eduForm, scorePercentage: e.target.value })}
                />
              </FormField>
            </FormGrid>
            <div className="flex justify-end space-x-3">
              <Button type="button" variant="secondary" onClick={() => setIsEduModalOpen(false)}>
                Cancel
              </Button>
              <Button type="submit" variant="primary" disabled={addEduMutation.isPending || !eduForm.degree.trim()}>
                Add Qualification
              </Button>
            </div>
          </form>
        </Modal>
      )}

      {/* Experience Modal */}
      {isExpModalOpen && (
        <Modal title="Add Prior Experience" isOpen={isExpModalOpen} onClose={() => setIsExpModalOpen(false)}>
          <form
            onSubmit={(e) => {
              e.preventDefault()
              addExpMutation.mutate()
            }}
            className="space-y-4"
          >
            <FormField label="Company / Employer *" htmlFor="expCompany">
              <TextInput
                id="expCompany"
                required
                placeholder="e.g. Acme Corp"
                value={expForm.companyName}
                onChange={(e) => setExpForm({ ...expForm, companyName: e.target.value })}
              />
            </FormField>
            <FormField label="Designation *" htmlFor="expDesig">
              <TextInput
                id="expDesig"
                required
                placeholder="e.g. Senior Representative"
                value={expForm.designation}
                onChange={(e) => setExpForm({ ...expForm, designation: e.target.value })}
              />
            </FormField>
            <FormGrid columns={2}>
              <FormField label="Start Date" htmlFor="expFrom">
                <TextInput
                  id="expFrom"
                  type="date"
                  value={expForm.fromDate}
                  onChange={(e) => setExpForm({ ...expForm, fromDate: e.target.value })}
                />
              </FormField>
              <FormField label="End Date" htmlFor="expTo">
                <TextInput
                  id="expTo"
                  type="date"
                  value={expForm.toDate}
                  onChange={(e) => setExpForm({ ...expForm, toDate: e.target.value })}
                />
              </FormField>
            </FormGrid>
            <div className="flex justify-end space-x-3">
              <Button type="button" variant="secondary" onClick={() => setIsExpModalOpen(false)}>
                Cancel
              </Button>
              <Button type="submit" variant="primary" disabled={addExpMutation.isPending || !expForm.companyName.trim()}>
                Add Experience
              </Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  )
}

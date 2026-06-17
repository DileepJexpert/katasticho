package com.katasticho.erp.hr.service;

import com.katasticho.erp.common.context.TenantContext;
import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.hr.entity.EmployeeEducation;
import com.katasticho.erp.hr.entity.EmployeeExperience;
import com.katasticho.erp.hr.entity.EmployeeFamily;
import com.katasticho.erp.hr.repository.EmployeeEducationRepository;
import com.katasticho.erp.hr.repository.EmployeeExperienceRepository;
import com.katasticho.erp.hr.repository.EmployeeFamilyRepository;
import com.katasticho.erp.payroll.entity.Employee;
import com.katasticho.erp.payroll.repository.EmployeeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Owns the employee subresources for HR module 2: family / dependents,
 * education history, and prior work experience. Every operation is
 * org-scoped via TenantContext and validates that the parent payroll
 * employee exists in the same org.
 */
@Service
@RequiredArgsConstructor
public class HrEmployeeService {

    private final EmployeeRepository employeeRepository;
    private final EmployeeFamilyRepository familyRepository;
    private final EmployeeEducationRepository educationRepository;
    private final EmployeeExperienceRepository experienceRepository;

    // ───── Family ─────

    public List<EmployeeFamily> listFamily(UUID employeeId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        ensureEmployee(employeeId, orgId);
        return familyRepository.findByOrgIdAndEmployeeIdAndIsDeletedFalseOrderByCreatedAtAsc(orgId, employeeId);
    }

    @Transactional
    public EmployeeFamily addFamily(UUID employeeId, EmployeeFamily input) {
        UUID orgId = TenantContext.getCurrentOrgId();
        ensureEmployee(employeeId, orgId);
        input.setOrgId(orgId);
        input.setEmployeeId(employeeId);
        input.setId(null);
        input.setDeleted(false);
        return familyRepository.save(input);
    }

    @Transactional
    public EmployeeFamily updateFamily(UUID id, EmployeeFamily updates) {
        UUID orgId = TenantContext.getCurrentOrgId();
        EmployeeFamily existing = familyRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("EmployeeFamily", id));
        existing.setName(updates.getName());
        existing.setRelationship(updates.getRelationship());
        existing.setDateOfBirth(updates.getDateOfBirth());
        existing.setDependent(updates.isDependent());
        existing.setPhone(updates.getPhone());
        existing.setNotes(updates.getNotes());
        return familyRepository.save(existing);
    }

    @Transactional
    public void deleteFamily(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        EmployeeFamily existing = familyRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("EmployeeFamily", id));
        existing.setDeleted(true);
        familyRepository.save(existing);
    }

    // ───── Education ─────

    public List<EmployeeEducation> listEducation(UUID employeeId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        ensureEmployee(employeeId, orgId);
        return educationRepository.findByOrgIdAndEmployeeIdAndIsDeletedFalseOrderByStartYearDesc(orgId, employeeId);
    }

    @Transactional
    public EmployeeEducation addEducation(UUID employeeId, EmployeeEducation input) {
        UUID orgId = TenantContext.getCurrentOrgId();
        ensureEmployee(employeeId, orgId);
        input.setOrgId(orgId);
        input.setEmployeeId(employeeId);
        input.setId(null);
        input.setDeleted(false);
        return educationRepository.save(input);
    }

    @Transactional
    public EmployeeEducation updateEducation(UUID id, EmployeeEducation updates) {
        UUID orgId = TenantContext.getCurrentOrgId();
        EmployeeEducation existing = educationRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("EmployeeEducation", id));
        existing.setDegree(updates.getDegree());
        existing.setFieldOfStudy(updates.getFieldOfStudy());
        existing.setInstitution(updates.getInstitution());
        existing.setStartYear(updates.getStartYear());
        existing.setEndYear(updates.getEndYear());
        existing.setGrade(updates.getGrade());
        existing.setNotes(updates.getNotes());
        return educationRepository.save(existing);
    }

    @Transactional
    public void deleteEducation(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        EmployeeEducation existing = educationRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("EmployeeEducation", id));
        existing.setDeleted(true);
        educationRepository.save(existing);
    }

    // ───── Experience ─────

    public List<EmployeeExperience> listExperience(UUID employeeId) {
        UUID orgId = TenantContext.getCurrentOrgId();
        ensureEmployee(employeeId, orgId);
        return experienceRepository.findByOrgIdAndEmployeeIdAndIsDeletedFalseOrderByFromDateDesc(orgId, employeeId);
    }

    @Transactional
    public EmployeeExperience addExperience(UUID employeeId, EmployeeExperience input) {
        UUID orgId = TenantContext.getCurrentOrgId();
        ensureEmployee(employeeId, orgId);
        input.setOrgId(orgId);
        input.setEmployeeId(employeeId);
        input.setId(null);
        input.setDeleted(false);
        return experienceRepository.save(input);
    }

    @Transactional
    public EmployeeExperience updateExperience(UUID id, EmployeeExperience updates) {
        UUID orgId = TenantContext.getCurrentOrgId();
        EmployeeExperience existing = experienceRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("EmployeeExperience", id));
        existing.setCompanyName(updates.getCompanyName());
        existing.setDesignation(updates.getDesignation());
        existing.setFromDate(updates.getFromDate());
        existing.setToDate(updates.getToDate());
        existing.setLocation(updates.getLocation());
        existing.setResponsibilities(updates.getResponsibilities());
        return experienceRepository.save(existing);
    }

    @Transactional
    public void deleteExperience(UUID id) {
        UUID orgId = TenantContext.getCurrentOrgId();
        EmployeeExperience existing = experienceRepository.findByIdAndOrgIdAndIsDeletedFalse(id, orgId)
                .orElseThrow(() -> BusinessException.notFound("EmployeeExperience", id));
        existing.setDeleted(true);
        experienceRepository.save(existing);
    }

    // ───── Self-service /me ─────

    /** Resolve the payroll Employee linked to the current app-user, or throw. */
    public Employee me() {
        UUID orgId = TenantContext.getCurrentOrgId();
        UUID userId = TenantContext.getCurrentUserId();
        return employeeRepository.findByOrgIdAndUserIdAndIsDeletedFalse(orgId, userId)
                .orElseThrow(() -> new BusinessException(
                        "No employee profile is linked to your account. Ask HR to link your employee record.",
                        "HR_EMPLOYEE_NOT_LINKED", HttpStatus.NOT_FOUND));
    }

    /** Full self-service view: profile + family + education + experience. */
    public Map<String, Object> myProfile() {
        Employee employee = me();
        Map<String, Object> out = new HashMap<>();
        out.put("employee", employee);
        out.put("family", familyRepository
                .findByOrgIdAndEmployeeIdAndIsDeletedFalseOrderByCreatedAtAsc(employee.getOrgId(), employee.getId()));
        out.put("education", educationRepository
                .findByOrgIdAndEmployeeIdAndIsDeletedFalseOrderByStartYearDesc(employee.getOrgId(), employee.getId()));
        out.put("experience", experienceRepository
                .findByOrgIdAndEmployeeIdAndIsDeletedFalseOrderByFromDateDesc(employee.getOrgId(), employee.getId()));
        return out;
    }

    /**
     * Self-service profile update. Writes ONLY the fields an employee is
     * allowed to edit themselves — personal info, addresses, emergency contact,
     * personal email, profile photo. All other fields (designation, department,
     * salary IDs, statutory IDs, employment status, etc.) stay locked and must
     * go through the admin endpoints.
     */
    @Transactional
    public Employee updateMe(Employee input) {
        Employee me = me();
        me.setDateOfBirth(input.getDateOfBirth());
        me.setGender(input.getGender());
        me.setMaritalStatus(input.getMaritalStatus());
        me.setBloodGroup(input.getBloodGroup());
        me.setNationality(input.getNationality());
        me.setPersonalEmail(input.getPersonalEmail());
        me.setPhone(input.getPhone());
        me.setCurrentAddressLine1(input.getCurrentAddressLine1());
        me.setCurrentAddressLine2(input.getCurrentAddressLine2());
        me.setCurrentCity(input.getCurrentCity());
        me.setCurrentState(input.getCurrentState());
        me.setCurrentPincode(input.getCurrentPincode());
        me.setPermanentAddressLine1(input.getPermanentAddressLine1());
        me.setPermanentAddressLine2(input.getPermanentAddressLine2());
        me.setPermanentCity(input.getPermanentCity());
        me.setPermanentState(input.getPermanentState());
        me.setPermanentPincode(input.getPermanentPincode());
        me.setEmergencyContactName(input.getEmergencyContactName());
        me.setEmergencyContactRelationship(input.getEmergencyContactRelationship());
        me.setEmergencyContactPhone(input.getEmergencyContactPhone());
        me.setPhotoAttachmentId(input.getPhotoAttachmentId());
        return employeeRepository.save(me);
    }

    // ───── Helpers ─────

    private Employee ensureEmployee(UUID employeeId, UUID orgId) {
        return employeeRepository.findByIdAndOrgIdAndIsDeletedFalse(employeeId, orgId)
                .orElseThrow(() -> BusinessException.notFound("Employee", employeeId));
    }
}

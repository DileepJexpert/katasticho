# Payroll Implementation Specification

## 1. Product Goal

Payroll should support Indian SMBs without forcing every shop into a formal HR/payroll workflow.

The system must support three levels:

- No staff: payroll stays hidden.
- Simple salary expense: owner records staff wages as normal expenses.
- Formal payroll: business manages employees, payslips, payroll runs, deductions, and statutory liabilities.

Payroll must integrate with accounting through the existing journal posting flow. Payroll services must not write directly to ledger tables.

## 2. Scope

Version 1 includes:

- Payroll module gating.
- Payroll settings per organisation.
- Employee master.
- Salary structure.
- Payroll run and payslip generation.
- Simple statutory toggles for PF, ESI, PT, LWF, and TDS.
- Accounting posting for payroll.
- Basic payroll reports.

Version 1 does not include:

- Direct PF/ESI/PT filing.
- Bank salary file generation.
- Attendance device integration.
- HR leave management.
- Complex income tax regime calculation.
- Contractor compliance.

## 3. Module Gating

Add module code:

```text
PAYROLL
```

Rules:

- `PAYROLL` is disabled by default unless onboarding selects formal payroll.
- Payroll APIs must enforce module access.
- Simple salary expense does not require the payroll module.
- Staff salary expense account must exist even when payroll is disabled.

## 4. Onboarding

After business vertical selection, ask:

```text
How do you handle staff salaries?

A. No staff
B. Pay cash to workers, no formal payroll needed
C. Formal employees, need payslips and PF/ESI
```

Store the answer on `organisation.salary_handling_mode`.

Values:

```text
NONE
SIMPLE_EXPENSE
FORMAL_PAYROLL
```

Effects:

- `NONE`: payroll disabled, no payroll wizard.
- `SIMPLE_EXPENSE`: payroll disabled, salary expense category highlighted in expense/create transaction flow.
- `FORMAL_PAYROLL`: payroll enabled, payroll settings wizard starts.

## 5. Database Tables

### 5.1 payroll_settings

One row per organisation.

Fields:

```text
id UUID PK
org_id UUID NOT NULL UNIQUE
payroll_start_month DATE
pay_frequency VARCHAR(20) DEFAULT 'MONTHLY'
default_salary_expense_account_id UUID
default_salary_payable_account_id UUID
default_pf_payable_account_id UUID
default_esi_payable_account_id UUID
default_pt_payable_account_id UUID
default_lwf_payable_account_id UUID
default_tds_payable_account_id UUID
pf_enabled BOOLEAN NOT NULL DEFAULT false
esi_enabled BOOLEAN NOT NULL DEFAULT false
pt_enabled BOOLEAN NOT NULL DEFAULT false
lwf_enabled BOOLEAN NOT NULL DEFAULT false
tds_enabled BOOLEAN NOT NULL DEFAULT false
created_at TIMESTAMPTZ DEFAULT NOW()
updated_at TIMESTAMPTZ DEFAULT NOW()
```

### 5.2 employee

Fields:

```text
id UUID PK
org_id UUID NOT NULL
employee_code VARCHAR(50)
full_name VARCHAR(255) NOT NULL
phone VARCHAR(30)
email VARCHAR(255)
designation VARCHAR(100)
department VARCHAR(100)
date_of_joining DATE
date_of_exit DATE
employment_status VARCHAR(20) DEFAULT 'ACTIVE'
payment_mode VARCHAR(20)
bank_account_name VARCHAR(255)
bank_account_number VARCHAR(50)
bank_ifsc VARCHAR(20)
pan VARCHAR(20)
aadhaar_last4 VARCHAR(4)
uan VARCHAR(50)
esi_number VARCHAR(50)
is_pf_applicable BOOLEAN NOT NULL DEFAULT false
is_esi_applicable BOOLEAN NOT NULL DEFAULT false
is_pt_applicable BOOLEAN NOT NULL DEFAULT false
is_lwf_applicable BOOLEAN NOT NULL DEFAULT false
created_at TIMESTAMPTZ DEFAULT NOW()
updated_at TIMESTAMPTZ DEFAULT NOW()
is_deleted BOOLEAN DEFAULT false
```

### 5.3 salary_component

Defines earning and deduction components.

```text
id UUID PK
org_id UUID NOT NULL
code VARCHAR(50) NOT NULL
name VARCHAR(100) NOT NULL
component_type VARCHAR(20) NOT NULL
taxability VARCHAR(30)
is_statutory BOOLEAN DEFAULT false
is_active BOOLEAN DEFAULT true
created_at TIMESTAMPTZ DEFAULT NOW()
```

Component types:

```text
EARNING
DEDUCTION
EMPLOYER_CONTRIBUTION
```

### 5.4 employee_salary_structure

Current salary definition for an employee.

```text
id UUID PK
org_id UUID NOT NULL
employee_id UUID NOT NULL
effective_from DATE NOT NULL
effective_to DATE
ctc_monthly NUMERIC(14,2)
gross_monthly NUMERIC(14,2)
status VARCHAR(20) DEFAULT 'ACTIVE'
created_at TIMESTAMPTZ DEFAULT NOW()
```

### 5.5 employee_salary_component

Line items under salary structure.

```text
id UUID PK
org_id UUID NOT NULL
salary_structure_id UUID NOT NULL
salary_component_id UUID NOT NULL
calculation_type VARCHAR(20) NOT NULL
amount NUMERIC(14,2)
percentage NUMERIC(7,4)
base_component_code VARCHAR(50)
created_at TIMESTAMPTZ DEFAULT NOW()
```

Calculation types:

```text
FIXED
PERCENTAGE
FORMULA
```

### 5.6 payroll_run

Represents monthly payroll processing.

```text
id UUID PK
org_id UUID NOT NULL
period_start DATE NOT NULL
period_end DATE NOT NULL
status VARCHAR(20) DEFAULT 'DRAFT'
employee_count INT DEFAULT 0
gross_total NUMERIC(14,2) DEFAULT 0
deduction_total NUMERIC(14,2) DEFAULT 0
employer_contribution_total NUMERIC(14,2) DEFAULT 0
net_pay_total NUMERIC(14,2) DEFAULT 0
journal_entry_id UUID
created_by UUID
approved_by UUID
approved_at TIMESTAMPTZ
posted_at TIMESTAMPTZ
created_at TIMESTAMPTZ DEFAULT NOW()
updated_at TIMESTAMPTZ DEFAULT NOW()
```

Statuses:

```text
DRAFT
CALCULATED
APPROVED
POSTED
CANCELLED
```

### 5.7 payslip

One row per employee per payroll run.

```text
id UUID PK
org_id UUID NOT NULL
payroll_run_id UUID NOT NULL
employee_id UUID NOT NULL
gross_pay NUMERIC(14,2) DEFAULT 0
total_deductions NUMERIC(14,2) DEFAULT 0
employer_contributions NUMERIC(14,2) DEFAULT 0
net_pay NUMERIC(14,2) DEFAULT 0
status VARCHAR(20) DEFAULT 'DRAFT'
pdf_url TEXT
created_at TIMESTAMPTZ DEFAULT NOW()
updated_at TIMESTAMPTZ DEFAULT NOW()
```

### 5.8 payslip_line

Line items for earnings, deductions, and employer contributions.

```text
id UUID PK
org_id UUID NOT NULL
payslip_id UUID NOT NULL
salary_component_id UUID NOT NULL
component_type VARCHAR(20) NOT NULL
amount NUMERIC(14,2) NOT NULL
created_at TIMESTAMPTZ DEFAULT NOW()
```

### 5.9 payroll_payment

Tracks payment of net salary.

```text
id UUID PK
org_id UUID NOT NULL
payroll_run_id UUID NOT NULL
payment_date DATE NOT NULL
payment_account_id UUID NOT NULL
amount NUMERIC(14,2) NOT NULL
payment_mode VARCHAR(30)
reference_number VARCHAR(100)
journal_entry_id UUID
created_at TIMESTAMPTZ DEFAULT NOW()
```

### 5.10 statutory_payment

Tracks payment of PF, ESI, PT, LWF, and TDS liabilities.

```text
id UUID PK
org_id UUID NOT NULL
statutory_type VARCHAR(20) NOT NULL
period_label VARCHAR(20)
due_date DATE
payment_date DATE
amount NUMERIC(14,2) NOT NULL
payment_account_id UUID
reference_number VARCHAR(100)
status VARCHAR(20) DEFAULT 'PENDING'
journal_entry_id UUID
created_at TIMESTAMPTZ DEFAULT NOW()
```

### 5.11 payroll_audit_log

Audit events for payroll changes.

```text
id UUID PK
org_id UUID NOT NULL
entity_type VARCHAR(50) NOT NULL
entity_id UUID NOT NULL
action VARCHAR(50) NOT NULL
old_value JSONB
new_value JSONB
performed_by UUID
performed_at TIMESTAMPTZ DEFAULT NOW()
```

### 5.12 payroll_document_snapshot

Immutable snapshot after posting payroll.

```text
id UUID PK
org_id UUID NOT NULL
payroll_run_id UUID NOT NULL
snapshot_json JSONB NOT NULL
snapshot_hash VARCHAR(128)
created_at TIMESTAMPTZ DEFAULT NOW()
```

## 6. Accounting Posting

Payroll posting must use the existing accounting posting flow and `JournalService`.

Formal payroll journal:

```text
DR Staff Salaries
DR Employer PF Expense
DR Employer ESI Expense
CR Salary Payable
CR PF Payable
CR ESI Payable
CR PT Payable
CR LWF Payable
CR TDS Payable
```

Only enabled statutory components should appear.

If all statutory flags are false, payroll posting is simple:

```text
DR Staff Salaries
CR Salary Payable
```

Salary payment journal:

```text
DR Salary Payable
CR Cash / Bank
```

Statutory payment journal:

```text
DR PF/ESI/PT/LWF/TDS Payable
CR Cash / Bank
```

## 7. Backend APIs

Base path:

```text
/api/v1/payroll
```

Endpoints:

```text
GET    /settings
PUT    /settings

GET    /employees
POST   /employees
GET    /employees/{id}
PUT    /employees/{id}
DELETE /employees/{id}

GET    /salary-components
POST   /salary-components
PUT    /salary-components/{id}

GET    /employees/{id}/salary-structure
POST   /employees/{id}/salary-structure

GET    /runs
POST   /runs
GET    /runs/{id}
POST   /runs/{id}/calculate
POST   /runs/{id}/approve
POST   /runs/{id}/post
POST   /runs/{id}/cancel

GET    /runs/{id}/payslips
GET    /payslips/{id}
POST   /payslips/{id}/generate-pdf

POST   /runs/{id}/payment
POST   /statutory-payments

GET    /reports/summary
GET    /reports/employee-ledger
GET    /reports/statutory-liabilities
```

## 8. Flutter Screens

Payroll module screens:

- Payroll Dashboard
- Payroll Settings Wizard
- Employee List
- Employee Detail
- Salary Structure Editor
- Payroll Run List
- Payroll Run Detail
- Payslip Preview
- Salary Payment Screen
- Statutory Liability Screen
- Payroll Reports

UI rules:

- Hide statutory sections when corresponding org setting is disabled.
- Hide employee statutory fields unless payroll setting enables that statutory feature.
- For simple salary expense users, show salary through existing Expenses/Create Transaction flow instead of Payroll menu.

## 9. Business Rules

- Payroll run period cannot overlap another posted payroll run.
- Posted payroll cannot be edited.
- Correction after posting must use reversal or adjustment.
- Payslips must be generated from posted payroll snapshot.
- Payroll posting must fail if required accounts are missing.
- Payroll posting must fail if period is closed.
- Payroll must preserve `org_id` isolation everywhere.
- No payroll service may directly insert journal lines.
- Salary expense must always land in the same account whether entered through Expenses or Payroll.

## 10. Reports

Payroll reports:

- Monthly Payroll Summary
- Employee Salary Register
- Payslip Register
- Salary Payment Register
- Statutory Liability Summary
- Payroll Journal Summary

## 11. Optionality and Simplicity Rules

### 11.1 Onboarding Question for Salary Handling

During org onboarding, after business vertical is selected, ask:

```text
How do you handle staff salaries?

A -> No staff (sole proprietor)
     Action: PAYROLL module stays disabled, nothing changes

B -> Pay cash to workers, no formal payroll needed
     Action: PAYROLL module stays disabled
             Seed "Salary & Wages" as default expense category
             Show tip in Create Transaction screen pointing to this category

C -> Formal employees, need payslips and PF/ESI
     Action: Enable PAYROLL module
             Take owner through payroll settings wizard
```

Store choice as `salary_handling_mode VARCHAR(20)` on `organisation`.

Allowed values:

```text
NONE
SIMPLE_EXPENSE
FORMAL_PAYROLL
```

### 11.2 Payroll Settings Statutory Flags

Add these columns to `payroll_settings`:

```sql
ALTER TABLE payroll_settings
  ADD COLUMN pf_enabled  BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN esi_enabled BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN pt_enabled  BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN lwf_enabled BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN tds_enabled BOOLEAN NOT NULL DEFAULT false;
```

All default to false.

Owner enables only what their business actually uses. If all five remain false, payroll runs as a simple salary tracker with no statutory columns in the UI or journal.

### 11.3 Employee Statutory Flags Default False

In the employee table, all statutory flags must default to false:

```sql
is_pf_applicable  BOOLEAN NOT NULL DEFAULT false,
is_esi_applicable BOOLEAN NOT NULL DEFAULT false,
is_pt_applicable  BOOLEAN NOT NULL DEFAULT false,
is_lwf_applicable BOOLEAN NOT NULL DEFAULT false
```

Employee gets statutory deductions only if explicitly opted in.

### 11.4 Salary Expense Accounts Seeded for All Orgs

When any org is created, regardless of whether `PAYROLL` is enabled, seed these accounts in the chart of accounts:

```text
5001 - Staff Salaries - Expense
5002 - Owner Drawings - Equity
```

When the owner uses Create Transaction -> Record Expense for cash salary payment, it posts to account `5001`.

When formal payroll posts its journal, it also posts to account `5001`.

Both paths show in P&L under the same account. This prevents double counting and avoids a historical gap when the business upgrades from simple expense handling to formal payroll.

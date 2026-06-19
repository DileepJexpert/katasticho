-- ============================================================================
-- V25: Production-to-payroll bridge (manufacturing tracker #57).
--
-- Today's payroll only supports fixed-monthly SALARY employees — their
-- earnings come from the salary-structure components. Manufacturing
-- has many hourly + piece-rate workers whose actual pay should come
-- from the production data the system already records on job cards
-- (timeLoggedMinutes, completedQty).
--
-- We extend employee_salary_structure with three columns:
--   pay_type     SALARY (default) | HOURLY | PIECE_RATE
--   hourly_rate  ₹/hour when pay_type=HOURLY
--   piece_rate   ₹/piece when pay_type=PIECE_RATE
--
-- When the calc runs and the structure is HOURLY/PIECE_RATE, an extra
-- LABOR_PAY earning line is added based on the period's completed job
-- cards for that employee's linked app user. SALARY rows behave
-- exactly as before — no change in behaviour for legacy structures.
-- ============================================================================

ALTER TABLE public.employee_salary_structure
    ADD COLUMN pay_type     varchar(20) DEFAULT 'SALARY' NOT NULL;

ALTER TABLE public.employee_salary_structure
    ADD COLUMN hourly_rate  numeric(12, 2);

ALTER TABLE public.employee_salary_structure
    ADD COLUMN piece_rate   numeric(12, 2);

ALTER TABLE public.employee_salary_structure
    ADD CONSTRAINT employee_salary_structure_pay_type_chk
        CHECK (pay_type IN ('SALARY', 'HOURLY', 'PIECE_RATE'));

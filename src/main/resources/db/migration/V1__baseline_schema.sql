-- V1: Consolidated baseline schema (re-squashed 2026-06-20).
--
-- The migration chain had diverged into two parallel V18-V27 lines — a documented
-- feature stream (HR depth, maintenance, manufacturing, pharma BMR, ...) and an
-- undocumented transport/fixed-assets stream (fixed assets, amortization, courier,
-- lorry receipt, vehicle log, ...). Flyway rejected the duplicate version numbers
-- ("Found more than one migration with version 18"). Because the database is
-- disposable (Docker-only, never deployed), every historical migration was applied
-- to a throwaway PostgreSQL 16 instance and the resulting schema dumped here.
-- CREATE-only, guaranteed to match what the full chain produced.
--
-- De-duplication during the squash: proof_of_delivery was created twice (V21 sales
-- shape + V27 transport shape). The V21 sales shape was kept (its JPA entity is the
-- surviving one); the transport POD scaffold was removed.
--
-- PostgreSQL database dump
--


-- Dumped from database version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: check_journal_balance(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_journal_balance() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
total_debit  DECIMAL(15,2);
    total_credit DECIMAL(15,2);
BEGIN
    IF NEW.status = 'POSTED' AND OLD.status = 'DRAFT' THEN
SELECT COALESCE(SUM(debit),0), COALESCE(SUM(credit),0)
INTO total_debit, total_credit
FROM journal_line WHERE journal_entry_id = NEW.id;
IF total_debit != total_credit THEN
            RAISE EXCEPTION 'Journal entry % does not balance. Debit: %, Credit: %',
                NEW.id, total_debit, total_credit;
END IF;
        IF total_debit = 0 AND total_credit = 0 THEN
            RAISE EXCEPTION 'Journal entry % has no lines or zero amounts', NEW.id;
END IF;
END IF;
RETURN NEW;
END;
$$;


--
-- Name: get_account_balance(uuid, uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_account_balance(p_account_id uuid, p_org_id uuid, p_as_of_date date DEFAULT CURRENT_DATE) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
v_balance      DECIMAL(15,2);
    v_account_type VARCHAR(20);
BEGIN
SELECT type INTO v_account_type FROM account WHERE id = p_account_id;
SELECT COALESCE(SUM(jl.base_debit) - SUM(jl.base_credit), 0)
INTO v_balance
FROM journal_line jl
         JOIN journal_entry je ON jl.journal_entry_id = je.id
WHERE jl.account_id = p_account_id
  AND je.org_id = p_org_id
  AND je.status = 'POSTED'
  AND je.effective_date <= p_as_of_date;
IF v_account_type IN ('LIABILITY','EQUITY','REVENUE') THEN
        v_balance := -v_balance;
END IF;
RETURN v_balance;
END;
$$;


--
-- Name: get_item_balance(uuid, uuid, uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_item_balance(p_item_id uuid, p_warehouse_id uuid, p_org_id uuid, p_as_of_date date DEFAULT CURRENT_DATE) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
v_balance NUMERIC(15,4);
BEGIN
SELECT COALESCE(SUM(quantity), 0)
INTO v_balance
FROM stock_movement
WHERE org_id      = p_org_id
  AND item_id     = p_item_id
  AND warehouse_id = p_warehouse_id
  AND movement_date <= p_as_of_date;
RETURN v_balance;
END;
$$;


--
-- Name: prevent_journal_entry_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_journal_entry_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.status = 'POSTED' THEN
        RAISE EXCEPTION 'Cannot delete POSTED journal entry %', OLD.id;
END IF;
RETURN OLD;
END;
$$;


--
-- Name: prevent_journal_entry_update(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_journal_entry_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.status = 'POSTED' THEN
        IF OLD.is_reversed = FALSE AND NEW.is_reversed = TRUE
           AND NEW.status = OLD.status
           AND NEW.effective_date = OLD.effective_date
           AND NEW.description = OLD.description THEN
            RETURN NEW;
END IF;
        IF NEW.status != OLD.status
           OR NEW.description IS DISTINCT FROM OLD.description
           OR NEW.effective_date != OLD.effective_date
           OR NEW.source_module != OLD.source_module
           OR NEW.entry_number != OLD.entry_number THEN
            RAISE EXCEPTION 'Cannot modify POSTED journal entry %', OLD.id;
END IF;
END IF;
    IF OLD.status = 'DRAFT' AND NEW.status = 'POSTED' THEN RETURN NEW; END IF;
    IF OLD.status = 'DRAFT' AND NEW.status = 'DRAFT'  THEN RETURN NEW; END IF;
    IF OLD.status = 'POSTED' AND NEW.status = 'DRAFT' THEN
        RAISE EXCEPTION 'Cannot revert POSTED journal entry % to DRAFT', OLD.id;
END IF;
RETURN NEW;
END;
$$;


--
-- Name: prevent_journal_line_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_journal_line_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
entry_status VARCHAR(10);
BEGIN
SELECT status INTO entry_status FROM journal_entry
WHERE id = COALESCE(OLD.journal_entry_id, NEW.journal_entry_id);
IF entry_status = 'POSTED' THEN
        RAISE EXCEPTION 'Cannot modify lines of POSTED journal entry';
END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
RETURN NEW;
END;
$$;


--
-- Name: prevent_stock_movement_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_stock_movement_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'Cannot delete stock_movement % — record a reversal instead', OLD.id;
END;
$$;


--
-- Name: prevent_stock_movement_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_stock_movement_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.is_reversed = FALSE AND NEW.is_reversed = TRUE
       AND NEW.quantity      = OLD.quantity
       AND NEW.unit_cost     = OLD.unit_cost
       AND NEW.total_cost    = OLD.total_cost
       AND NEW.movement_type = OLD.movement_type
       AND NEW.movement_date = OLD.movement_date
       AND NEW.item_id       = OLD.item_id
       AND NEW.warehouse_id  = OLD.warehouse_id
       AND NEW.org_id        = OLD.org_id THEN
        RETURN NEW;
END IF;
    IF NEW.quantity      != OLD.quantity
       OR NEW.unit_cost     != OLD.unit_cost
       OR NEW.movement_type != OLD.movement_type
       OR NEW.movement_date != OLD.movement_date
       OR NEW.item_id       != OLD.item_id
       OR NEW.warehouse_id  != OLD.warehouse_id
       OR NEW.org_id        != OLD.org_id THEN
        RAISE EXCEPTION 'Cannot modify posted stock_movement % — record a reversal instead', OLD.id;
END IF;
RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(255) NOT NULL,
    type character varying(20) NOT NULL,
    sub_type character varying(50),
    parent_id uuid,
    level integer DEFAULT 1 NOT NULL,
    is_system boolean DEFAULT false NOT NULL,
    description character varying(500),
    opening_balance numeric(15,2) DEFAULT 0 NOT NULL,
    currency character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    CONSTRAINT account_level_check CHECK (((level >= 1) AND (level <= 5))),
    CONSTRAINT account_type_check CHECK (((type)::text = ANY (ARRAY[('ASSET'::character varying)::text, ('LIABILITY'::character varying)::text, ('EQUITY'::character varying)::text, ('REVENUE'::character varying)::text, ('EXPENSE'::character varying)::text])))
);


--
-- Name: ai_model_registry; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_model_registry (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    task_type character varying(80) NOT NULL,
    model_name character varying(80) NOT NULL,
    model_version character varying(50),
    model_type character varying(50) NOT NULL,
    model_uri text,
    endpoint_url text,
    status character varying(30) DEFAULT 'ACTIVE'::character varying NOT NULL,
    accuracy numeric(5,4),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ai_model_run; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_model_run (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid,
    task_type character varying(80) NOT NULL,
    model_name character varying(80) NOT NULL,
    model_version character varying(50),
    provider character varying(50),
    input_hash character varying(128),
    input_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    output jsonb DEFAULT '{}'::jsonb NOT NULL,
    confidence numeric(4,3),
    latency_ms integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ai_pattern; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_pattern (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    pattern_type character varying(50) NOT NULL,
    pattern_key jsonb NOT NULL,
    predicted_result jsonb NOT NULL,
    confidence numeric(4,3) DEFAULT 0.500 NOT NULL,
    match_count integer DEFAULT 0 NOT NULL,
    accepted_count integer DEFAULT 0 NOT NULL,
    rejected_count integer DEFAULT 0 NOT NULL,
    corrected_count integer DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    last_matched_at timestamp without time zone,
    last_corrected_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: ai_suggestion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_suggestion (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    entity_type character varying(50) NOT NULL,
    entity_id uuid NOT NULL,
    entity_line_id uuid,
    suggestion_type character varying(50) NOT NULL,
    suggested_action character varying(80),
    suggested_value jsonb DEFAULT '{}'::jsonb NOT NULL,
    reasoning text,
    confidence numeric(4,3),
    agent_name character varying(50),
    model_name character varying(80),
    model_version character varying(50),
    prompt_version character varying(50),
    status character varying(30) DEFAULT 'PENDING'::character varying NOT NULL,
    reviewed_by uuid,
    reviewed_at timestamp without time zone,
    review_action character varying(50),
    reviewed_value jsonb,
    correction_reason text,
    priority character varying(20) DEFAULT 'MEDIUM'::character varying NOT NULL,
    priority_score numeric(8,3) DEFAULT 0 NOT NULL,
    due_by timestamp without time zone,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: ai_training_example; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_training_example (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    source_suggestion_id uuid,
    entity_type character varying(50) NOT NULL,
    entity_id uuid NOT NULL,
    task_type character varying(50) NOT NULL,
    input_snapshot jsonb NOT NULL,
    ai_output jsonb,
    human_output jsonb NOT NULL,
    correction_type character varying(30),
    correction_reason text,
    created_by uuid,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: ai_usage_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_usage_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid,
    feature character varying(80) NOT NULL,
    provider character varying(40),
    model character varying(80),
    input_tokens integer,
    output_tokens integer,
    estimated_cost_usd numeric(12,6),
    entity_type character varying(50),
    entity_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: amortization_entry; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.amortization_entry (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    schedule_id uuid NOT NULL,
    period_year integer NOT NULL,
    period_month integer NOT NULL,
    amount numeric(18,2) NOT NULL,
    journal_entry_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: amortization_schedule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.amortization_schedule (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    schedule_type character varying(20) NOT NULL,
    description character varying(200) NOT NULL,
    reference character varying(60),
    total_amount numeric(18,2) NOT NULL,
    start_year integer NOT NULL,
    start_month integer NOT NULL,
    number_of_periods integer NOT NULL,
    debit_account_code character varying(20) NOT NULL,
    credit_account_code character varying(20) NOT NULL,
    recognized_amount numeric(18,2) DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    source_module character varying(40),
    source_id uuid,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: api_key; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_key (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid NOT NULL,
    name character varying(100) NOT NULL,
    key_hash character varying(64) NOT NULL,
    key_prefix character varying(16) NOT NULL,
    last_used_at timestamp with time zone,
    expires_at timestamp with time zone,
    revoked_at timestamp with time zone,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    is_deleted boolean DEFAULT false NOT NULL
);


--
-- Name: app_user; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_user (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    branch_id uuid,
    email character varying(255),
    phone character varying(20),
    password_hash character varying(255),
    full_name character varying(255) NOT NULL,
    role character varying(20) DEFAULT 'VIEWER'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    failed_login_count integer DEFAULT 0 NOT NULL,
    locked_until timestamp with time zone,
    last_login_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    default_landing_page character varying(50) DEFAULT '/dashboard'::character varying,
    ca_firm_id uuid,
    token_version integer DEFAULT 0 NOT NULL,
    email_verified boolean DEFAULT false NOT NULL,
    email_verified_at timestamp with time zone,
    login_method character varying(10) DEFAULT 'PHONE'::character varying NOT NULL,
    reports_to_user_id uuid,
    CONSTRAINT app_user_role_check CHECK (((role)::text = ANY (ARRAY[('OWNER'::character varying)::text, ('ADMIN'::character varying)::text, ('ACCOUNTANT'::character varying)::text, ('OPERATOR'::character varying)::text, ('VIEWER'::character varying)::text, ('CA_EXTERNAL'::character varying)::text, ('CA_PARTNER'::character varying)::text, ('CA_STAFF'::character varying)::text, ('PLATFORM_ADMIN'::character varying)::text]))),
    CONSTRAINT chk_user_has_login CHECK (((email IS NOT NULL) OR (phone IS NOT NULL)))
);


--
-- Name: approval_decision; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.approval_decision (
    id uuid NOT NULL,
    org_id uuid NOT NULL,
    approval_request_id uuid NOT NULL,
    step_number smallint NOT NULL,
    decision character varying(20) NOT NULL,
    note text,
    decided_by uuid NOT NULL,
    decided_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    is_deleted boolean DEFAULT false NOT NULL
);


--
-- Name: approval_request; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.approval_request (
    id uuid NOT NULL,
    org_id uuid NOT NULL,
    workflow_id uuid,
    document_type character varying(80) NOT NULL,
    document_id uuid NOT NULL,
    current_step smallint DEFAULT 1 NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    requested_by uuid,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    trigger_reason text,
    context_json jsonb,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    is_deleted boolean DEFAULT false NOT NULL
);


--
-- Name: attendance_regularization; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attendance_regularization (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid NOT NULL,
    work_date date NOT NULL,
    requested_punch_in timestamp with time zone,
    requested_punch_out timestamp with time zone,
    reason text,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    approved_by uuid,
    decided_at timestamp with time zone,
    rejection_reason character varying(300),
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid,
    entity_type character varying(50) NOT NULL,
    entity_id uuid,
    action character varying(20) NOT NULL,
    before_json jsonb,
    after_json jsonb,
    ip_address character varying(45),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: bank_transaction; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bank_transaction (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    transaction_date date NOT NULL,
    amount numeric(18,2) NOT NULL,
    direction character varying(10) NOT NULL,
    narration text,
    utr character varying(100),
    payer_name character varying(255),
    payer_vpa character varying(255),
    status character varying(30) DEFAULT 'UNMATCHED'::character varying NOT NULL,
    payment_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: batch_trace; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.batch_trace (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    created_by uuid,
    batch_id uuid NOT NULL,
    item_id uuid NOT NULL,
    trace_type character varying(20) NOT NULL,
    source_batch_id uuid,
    source_item_id uuid,
    work_order_id uuid,
    movement_id uuid,
    quantity numeric(18,4),
    traced_at timestamp with time zone DEFAULT now() NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: beat; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.beat (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    area character varying(100),
    city character varying(100),
    state character varying(50),
    description text,
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: beat_customer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.beat_customer (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    beat_id uuid NOT NULL,
    contact_id uuid NOT NULL,
    visit_sequence integer,
    visit_frequency character varying(20) DEFAULT 'WEEKLY'::character varying NOT NULL,
    geo_latitude numeric(10,7),
    geo_longitude numeric(10,7),
    notes text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: bmr_deviation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bmr_deviation (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    work_order_id uuid NOT NULL,
    job_card_id uuid,
    severity character varying(20) NOT NULL,
    title character varying(200) NOT NULL,
    description text,
    reported_by uuid,
    reported_at timestamp with time zone DEFAULT now() NOT NULL,
    status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    resolution text,
    resolved_by uuid,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    CONSTRAINT bmr_deviation_severity_chk CHECK (((severity)::text = ANY ((ARRAY['MINOR'::character varying, 'MAJOR'::character varying, 'CRITICAL'::character varying])::text[]))),
    CONSTRAINT bmr_deviation_status_chk CHECK (((status)::text = ANY ((ARRAY['OPEN'::character varying, 'INVESTIGATING'::character varying, 'RESOLVED'::character varying, 'ACCEPTED'::character varying])::text[])))
);


--
-- Name: bmr_signoff; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bmr_signoff (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    work_order_id uuid NOT NULL,
    job_card_id uuid,
    role character varying(20) NOT NULL,
    signed_by uuid NOT NULL,
    signed_at timestamp with time zone DEFAULT now() NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    CONSTRAINT bmr_signoff_role_chk CHECK (((role)::text = ANY ((ARRAY['OPERATOR'::character varying, 'SUPERVISOR'::character varying, 'QA'::character varying, 'QC'::character varying])::text[])))
);


--
-- Name: bmr_step_record; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bmr_step_record (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    work_order_id uuid NOT NULL,
    job_card_id uuid,
    parameter_key character varying(100) NOT NULL,
    parameter_value character varying(200) NOT NULL,
    unit character varying(20),
    observed_at timestamp with time zone DEFAULT now() NOT NULL,
    observed_by uuid,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid,
    is_deleted boolean DEFAULT false NOT NULL
);


--
-- Name: bom_alternate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bom_alternate (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    bom_component_id uuid NOT NULL,
    alternate_item_id uuid NOT NULL,
    priority integer DEFAULT 1 NOT NULL,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: bom_co_product; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bom_co_product (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    parent_item_id uuid NOT NULL,
    co_product_item_id uuid NOT NULL,
    quantity_per_unit numeric(15,4) NOT NULL,
    cost_allocation_percent numeric(5,2) DEFAULT 0 NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT chk_bom_co_product_no_self_ref CHECK ((parent_item_id <> co_product_item_id)),
    CONSTRAINT chk_bom_co_product_pct_range CHECK (((cost_allocation_percent >= (0)::numeric) AND (cost_allocation_percent <= (100)::numeric))),
    CONSTRAINT chk_bom_co_product_positive_qty CHECK ((quantity_per_unit > (0)::numeric))
);


--
-- Name: bom_component; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bom_component (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    parent_item_id uuid NOT NULL,
    child_item_id uuid NOT NULL,
    quantity numeric(15,4) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    version integer DEFAULT 1,
    effective_from date,
    effective_to date,
    change_notes text,
    scrap_percent numeric(5,2) DEFAULT 0,
    variant_filter jsonb,
    CONSTRAINT chk_bom_component_no_self_ref CHECK ((parent_item_id <> child_item_id)),
    CONSTRAINT chk_bom_component_positive_qty CHECK ((quantity > (0)::numeric))
);


--
-- Name: branch; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.branch (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(255) NOT NULL,
    address_line1 character varying(255),
    address_line2 character varying(255),
    city character varying(100),
    state character varying(100),
    state_code character varying(5),
    postal_code character varying(20),
    country character varying(2) DEFAULT 'IN'::character varying,
    gstin character varying(15),
    is_default boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: stock_balance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stock_balance (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    branch_id uuid,
    item_id uuid NOT NULL,
    warehouse_id uuid NOT NULL,
    quantity_on_hand numeric(15,4) DEFAULT 0 NOT NULL,
    reserved_qty numeric(15,4) DEFAULT 0 NOT NULL,
    average_cost numeric(15,4) DEFAULT 0 NOT NULL,
    last_movement_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: warehouse; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.warehouse (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    branch_id uuid,
    code character varying(20) NOT NULL,
    name character varying(255) NOT NULL,
    address_line1 character varying(255),
    address_line2 character varying(255),
    city character varying(100),
    state character varying(100),
    state_code character varying(5),
    postal_code character varying(20),
    country character varying(2) DEFAULT 'IN'::character varying,
    is_default boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: branch_stock_summary; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.branch_stock_summary AS
 SELECT w.org_id,
    w.branch_id,
    sb.item_id,
    sum(sb.quantity_on_hand) AS quantity_on_hand,
    sum((sb.quantity_on_hand * sb.average_cost)) AS stock_value,
    count(DISTINCT sb.warehouse_id) AS warehouse_count,
    max(sb.last_movement_at) AS last_movement_at
   FROM (public.stock_balance sb
     JOIN public.warehouse w ON ((w.id = sb.warehouse_id)))
  WHERE ((w.branch_id IS NOT NULL) AND (NOT w.is_deleted))
  GROUP BY w.org_id, w.branch_id, sb.item_id;


--
-- Name: budget_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.budget_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    fiscal_year integer NOT NULL,
    account_code character varying(20) NOT NULL,
    annual_amount numeric(15,2) DEFAULT 0 NOT NULL,
    notes character varying(255),
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: ca_alert_dismissal; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_alert_dismissal (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ca_firm_id uuid NOT NULL,
    suggestion_id uuid NOT NULL,
    dismissed_by uuid NOT NULL,
    assigned_user_id uuid,
    dismissed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ca_client_link; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_client_link (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ca_firm_id uuid NOT NULL,
    client_org_id uuid NOT NULL,
    assigned_user_id uuid,
    backup_user_id uuid,
    engagement_type character varying(50) DEFAULT 'FULL_SERVICE'::character varying NOT NULL,
    engagement_start date DEFAULT CURRENT_DATE NOT NULL,
    engagement_end date,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT ca_client_link_status_check CHECK (((status)::text = ANY (ARRAY[('ACTIVE'::character varying)::text, ('PAUSED'::character varying)::text, ('ENDED'::character varying)::text])))
);


--
-- Name: ca_compliance_deadline; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_compliance_deadline (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ca_client_link_id uuid NOT NULL,
    client_org_id uuid NOT NULL,
    deadline_type character varying(50) NOT NULL,
    period_label character varying(20) NOT NULL,
    due_date date NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    filed_at timestamp with time zone,
    filed_by uuid,
    filing_reference character varying(100),
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ca_compliance_deadline_status_check CHECK (((status)::text = ANY (ARRAY[('PENDING'::character varying)::text, ('FILED'::character varying)::text, ('OVERDUE'::character varying)::text, ('NOT_APPLICABLE'::character varying)::text])))
);


--
-- Name: ca_firm; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_firm (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    firm_name character varying(255) NOT NULL,
    icai_number character varying(50),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ca_report_dispatch; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ca_report_dispatch (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ca_client_link_id uuid,
    client_org_id uuid,
    dispatched_by uuid,
    period_label character varying(20) NOT NULL,
    report_types jsonb DEFAULT '[]'::jsonb NOT NULL,
    sent_via character varying(20) DEFAULT 'EMAIL'::character varying NOT NULL,
    sent_to_email character varying(255),
    sent_to_phone character varying(20),
    ai_commentary boolean DEFAULT false NOT NULL,
    report_urls jsonb DEFAULT '{}'::jsonb NOT NULL,
    status character varying(20) DEFAULT 'QUEUED'::character varying NOT NULL,
    sent_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ca_report_dispatch_sent_via_check CHECK (((sent_via)::text = ANY (ARRAY[('EMAIL'::character varying)::text, ('WHATSAPP'::character varying)::text, ('BOTH'::character varying)::text]))),
    CONSTRAINT ca_report_dispatch_status_check CHECK (((status)::text = ANY (ARRAY[('QUEUED'::character varying)::text, ('SENT'::character varying)::text, ('FAILED'::character varying)::text])))
);


--
-- Name: capa_action; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.capa_action (
    id uuid NOT NULL,
    org_id uuid NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    capa_number character varying(30) NOT NULL,
    ncr_id uuid,
    capa_type character varying(15) NOT NULL,
    title character varying(200) NOT NULL,
    description text,
    proposed_action text,
    assigned_to uuid,
    due_date date,
    priority character varying(10) DEFAULT 'NORMAL'::character varying NOT NULL,
    status character varying(15) DEFAULT 'OPEN'::character varying NOT NULL,
    completion_notes text,
    completed_at timestamp with time zone,
    completed_by uuid,
    verified_at timestamp with time zone,
    verified_by uuid,
    effectiveness_notes text,
    CONSTRAINT capa_priority_check CHECK (((priority)::text = ANY ((ARRAY['URGENT'::character varying, 'HIGH'::character varying, 'NORMAL'::character varying, 'LOW'::character varying])::text[]))),
    CONSTRAINT capa_status_check CHECK (((status)::text = ANY ((ARRAY['OPEN'::character varying, 'IN_PROGRESS'::character varying, 'COMPLETED'::character varying, 'VERIFIED'::character varying, 'CANCELLED'::character varying])::text[]))),
    CONSTRAINT capa_type_check CHECK (((capa_type)::text = ANY ((ARRAY['CORRECTIVE'::character varying, 'PREVENTIVE'::character varying])::text[])))
);


--
-- Name: coa_template; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.coa_template (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    industry character varying(50) NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(255) NOT NULL,
    type character varying(20) NOT NULL,
    sub_type character varying(50),
    parent_code character varying(20),
    level integer DEFAULT 1 NOT NULL,
    is_system boolean DEFAULT true NOT NULL
);


--
-- Name: cod_remittance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cod_remittance (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    remittance_number character varying(40) NOT NULL,
    courier_partner character varying(40) NOT NULL,
    remittance_date date NOT NULL,
    bank_account character varying(80),
    utr character varying(60),
    gross_collected numeric(14,2) DEFAULT 0 NOT NULL,
    total_fees numeric(14,2) DEFAULT 0 NOT NULL,
    net_remitted numeric(14,2) DEFAULT 0 NOT NULL,
    expected_net numeric(14,2) DEFAULT 0 NOT NULL,
    variance numeric(14,2) DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_by uuid,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: cod_remittance_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cod_remittance_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    cod_remittance_id uuid NOT NULL,
    awb_number character varying(60) NOT NULL,
    courier_shipment_id uuid,
    invoice_id uuid,
    cod_amount numeric(14,2) NOT NULL,
    cod_fee numeric(14,2) DEFAULT 0 NOT NULL,
    net_amount numeric(14,2) NOT NULL,
    match_status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    payment_id uuid,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: consignment_settlement; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consignment_settlement (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    consignment_stock_id uuid NOT NULL,
    settlement_number character varying(30),
    quantity_sold numeric(15,4) DEFAULT 0 NOT NULL,
    unit_cost numeric(15,4) DEFAULT 0 NOT NULL,
    total_amount numeric(15,4) DEFAULT 0 NOT NULL,
    settlement_date date,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: consignment_stock; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consignment_stock (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    item_id uuid NOT NULL,
    warehouse_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    quantity numeric(15,4) DEFAULT 0 NOT NULL,
    unit_cost numeric(15,4) DEFAULT 0 NOT NULL,
    consignment_date date,
    agreement_ref character varying(50),
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    settlement_method character varying(20) DEFAULT 'ON_SALE'::character varying NOT NULL,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: contact; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contact (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    contact_type character varying(10) DEFAULT 'CUSTOMER'::character varying NOT NULL,
    display_name character varying(255) NOT NULL,
    company_name character varying(255),
    first_name character varying(100),
    last_name character varying(100),
    salutation character varying(20),
    gstin character varying(15),
    pan character varying(10),
    tax_id character varying(50),
    gst_treatment character varying(30) DEFAULT 'UNREGISTERED'::character varying,
    place_of_supply character varying(5),
    msme_registered boolean DEFAULT false NOT NULL,
    msme_registration_no character varying(50),
    email character varying(255),
    phone character varying(30),
    mobile character varying(30),
    website character varying(255),
    billing_address_line1 character varying(255),
    billing_address_line2 character varying(255),
    billing_city character varying(100),
    billing_state character varying(100),
    billing_state_code character varying(5),
    billing_postal_code character varying(20),
    billing_country character varying(2) DEFAULT 'IN'::character varying NOT NULL,
    shipping_address_line1 character varying(255),
    shipping_address_line2 character varying(255),
    shipping_city character varying(100),
    shipping_state character varying(100),
    shipping_state_code character varying(5),
    shipping_postal_code character varying(20),
    shipping_country character varying(2) DEFAULT 'IN'::character varying NOT NULL,
    currency character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    payment_terms_days integer DEFAULT 30 NOT NULL,
    credit_limit numeric(15,2) DEFAULT 0 NOT NULL,
    opening_balance numeric(15,2) DEFAULT 0 NOT NULL,
    outstanding_ar numeric(15,2) DEFAULT 0 NOT NULL,
    outstanding_ap numeric(15,2) DEFAULT 0 NOT NULL,
    default_price_list_id uuid,
    tds_applicable boolean DEFAULT false NOT NULL,
    tds_section character varying(20),
    tds_rate numeric(5,2),
    bank_name character varying(255),
    bank_account_no character varying(50),
    bank_ifsc character varying(20),
    upi_id character varying(50),
    portal_enabled boolean DEFAULT false NOT NULL,
    portal_url character varying(500),
    notes text,
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    sales_hold boolean DEFAULT false NOT NULL,
    sales_hold_reason text,
    sales_hold_until date,
    medical_category character varying(20),
    specialty character varying(100),
    mr_class character varying(5),
    visits_per_month integer,
    CONSTRAINT contact_contact_type_check CHECK (((contact_type)::text = ANY (ARRAY[('CUSTOMER'::character varying)::text, ('VENDOR'::character varying)::text, ('BOTH'::character varying)::text]))),
    CONSTRAINT contact_gst_treatment_check CHECK (((gst_treatment)::text = ANY (ARRAY[('REGISTERED'::character varying)::text, ('UNREGISTERED'::character varying)::text, ('COMPOSITION'::character varying)::text, ('CONSUMER'::character varying)::text, ('OVERSEAS'::character varying)::text, ('SEZ'::character varying)::text])))
);


--
-- Name: contact_person; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contact_person (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contact_id uuid NOT NULL,
    salutation character varying(20),
    first_name character varying(100) NOT NULL,
    last_name character varying(100),
    designation character varying(100),
    department character varying(100),
    email character varying(255),
    phone character varying(30),
    mobile character varying(30),
    is_primary boolean DEFAULT false NOT NULL,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: cost_lot; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cost_lot (
    id uuid NOT NULL,
    org_id uuid NOT NULL,
    item_id uuid NOT NULL,
    warehouse_id uuid NOT NULL,
    source_movement_id uuid,
    received_date date NOT NULL,
    original_qty numeric(15,4) NOT NULL,
    remaining_qty numeric(15,4) NOT NULL,
    unit_cost numeric(15,4) DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: cost_lot_consumption; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cost_lot_consumption (
    id uuid NOT NULL,
    org_id uuid NOT NULL,
    lot_id uuid NOT NULL,
    movement_id uuid NOT NULL,
    qty numeric(15,4) NOT NULL,
    unit_cost numeric(15,4) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: courier_shipment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.courier_shipment (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    courier_shipment_number character varying(30) NOT NULL,
    delivery_challan_id uuid,
    invoice_id uuid,
    contact_id uuid NOT NULL,
    courier_partner character varying(40) NOT NULL,
    courier_service character varying(60),
    awb_number character varying(60),
    status character varying(30) DEFAULT 'DRAFT'::character varying NOT NULL,
    is_cod boolean DEFAULT false NOT NULL,
    cod_amount numeric(14,2) DEFAULT 0 NOT NULL,
    cod_remittance_line_id uuid,
    freight_amount numeric(14,2) DEFAULT 0 NOT NULL,
    cod_fee numeric(14,2) DEFAULT 0 NOT NULL,
    transporter_contact_id uuid,
    weight_kg numeric(10,3),
    declared_value numeric(14,2),
    pickup_address jsonb,
    delivery_address jsonb,
    booked_at timestamp with time zone,
    delivered_at timestamp with time zone,
    rto_initiated_at timestamp with time zone,
    rto_delivered_at timestamp with time zone,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_by uuid,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: courier_shipment_event; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.courier_shipment_event (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    courier_shipment_id uuid NOT NULL,
    event_status character varying(40) NOT NULL,
    event_at timestamp with time zone NOT NULL,
    location character varying(200),
    raw_payload jsonb,
    source character varying(20) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: credit_note; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credit_note (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    branch_id uuid,
    contact_id uuid NOT NULL,
    invoice_id uuid,
    credit_note_number character varying(30) NOT NULL,
    credit_note_date date NOT NULL,
    reason text NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    subtotal numeric(15,2) DEFAULT 0 NOT NULL,
    tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    total_amount numeric(15,2) DEFAULT 0 NOT NULL,
    currency character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    exchange_rate numeric(12,6) DEFAULT 1.000000 NOT NULL,
    base_subtotal numeric(15,2) DEFAULT 0 NOT NULL,
    base_tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    base_total numeric(15,2) DEFAULT 0 NOT NULL,
    place_of_supply character varying(50),
    journal_entry_id uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT credit_note_status_check CHECK (((status)::text = ANY (ARRAY[('DRAFT'::character varying)::text, ('ISSUED'::character varying)::text, ('APPLIED'::character varying)::text, ('CANCELLED'::character varying)::text])))
);


--
-- Name: credit_note_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.credit_note_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    credit_note_id uuid NOT NULL,
    line_number integer NOT NULL,
    description character varying(500) NOT NULL,
    hsn_code character varying(10),
    item_id uuid,
    batch_id uuid,
    quantity numeric(12,4) DEFAULT 1 NOT NULL,
    unit_price numeric(15,2) NOT NULL,
    taxable_amount numeric(15,2) NOT NULL,
    gst_rate numeric(5,2) DEFAULT 0 NOT NULL,
    tax_group_id uuid,
    tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    line_total numeric(15,2) NOT NULL,
    account_code character varying(20) NOT NULL,
    base_taxable_amount numeric(15,2) DEFAULT 0 NOT NULL,
    base_tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    base_line_total numeric(15,2) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: currency; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.currency (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(3) NOT NULL,
    name character varying(50) NOT NULL,
    symbol character varying(5),
    decimal_places integer DEFAULT 2 NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: customer_wallet; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customer_wallet (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    contact_id uuid NOT NULL,
    balance numeric(14,2) DEFAULT 0 NOT NULL,
    total_earned numeric(14,2) DEFAULT 0 NOT NULL,
    total_redeemed numeric(14,2) DEFAULT 0 NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: day_close; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.day_close (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    route_execution_id uuid NOT NULL,
    salesperson_id uuid NOT NULL,
    van_id uuid,
    close_date date NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    opening_cash numeric(15,2) DEFAULT 0,
    cash_collections numeric(15,2) DEFAULT 0,
    cash_expenses numeric(15,2) DEFAULT 0,
    closing_cash numeric(15,2) DEFAULT 0,
    cash_deposited numeric(15,2) DEFAULT 0,
    cash_variance numeric(15,2) DEFAULT 0,
    items_loaded integer DEFAULT 0,
    items_sold integer DEFAULT 0,
    items_returned integer DEFAULT 0,
    items_closing integer DEFAULT 0,
    stock_variance_count integer DEFAULT 0,
    visits_planned integer DEFAULT 0,
    visits_completed integer DEFAULT 0,
    visits_productive integer DEFAULT 0,
    total_orders_value numeric(15,2) DEFAULT 0,
    total_collections numeric(15,2) DEFAULT 0,
    total_returns_value numeric(15,2) DEFAULT 0,
    approved_by uuid,
    approved_at timestamp with time zone,
    rejection_reason text,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: dcr_report; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dcr_report (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    salesperson_id uuid NOT NULL,
    report_date date NOT NULL,
    route_execution_id uuid,
    work_type character varying(20) DEFAULT 'FIELD_WORK'::character varying NOT NULL,
    doctors_visited integer DEFAULT 0 NOT NULL,
    chemists_visited integer DEFAULT 0 NOT NULL,
    others_visited integer DEFAULT 0 NOT NULL,
    total_visits integer DEFAULT 0 NOT NULL,
    total_pob numeric(14,2) DEFAULT 0 NOT NULL,
    samples_given integer DEFAULT 0 NOT NULL,
    remarks text,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    submitted_at timestamp with time zone,
    approved_by uuid,
    approved_at timestamp with time zone,
    rejection_reason character varying(300),
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: debit_note; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.debit_note (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    debit_note_number character varying(30) NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    note_date date NOT NULL,
    return_reason character varying(50) NOT NULL,
    reference_bill_id uuid,
    notes text,
    subtotal numeric(19,4) DEFAULT 0 NOT NULL,
    tax_amount numeric(19,4) DEFAULT 0 NOT NULL,
    total_amount numeric(19,4) DEFAULT 0 NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: debit_note_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.debit_note_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    debit_note_id uuid NOT NULL,
    item_id uuid NOT NULL,
    description character varying(500),
    batch_id uuid,
    batch_number character varying(100),
    expiry_date date,
    quantity numeric(19,4) NOT NULL,
    unit_price numeric(19,4) DEFAULT 0 NOT NULL,
    tax_group_id uuid,
    hsn_code character varying(10),
    tax_rate numeric(6,2) DEFAULT 0 NOT NULL,
    tax_amount numeric(19,4) DEFAULT 0 NOT NULL,
    line_total numeric(19,4) DEFAULT 0 NOT NULL
);


--
-- Name: debit_note_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.debit_note_seq
    START WITH 1001
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: delegated_access_token; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.delegated_access_token (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ca_user_id uuid NOT NULL,
    client_org_id uuid NOT NULL,
    token_hash character varying(128) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used boolean DEFAULT false NOT NULL,
    used_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: delivery_challan; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.delivery_challan (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    branch_id uuid,
    challan_number character varying(30) NOT NULL,
    sales_order_id uuid NOT NULL,
    contact_id uuid NOT NULL,
    challan_date date NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    dispatch_date date,
    warehouse_id uuid,
    delivery_method character varying(50),
    vehicle_number character varying(30),
    tracking_number character varying(100),
    notes character varying(2000),
    shipping_address jsonb,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT delivery_challan_status_check CHECK (((status)::text = ANY (ARRAY[('DRAFT'::character varying)::text, ('DISPATCHED'::character varying)::text, ('DELIVERED'::character varying)::text, ('CANCELLED'::character varying)::text])))
);


--
-- Name: delivery_challan_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.delivery_challan_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    delivery_challan_id uuid NOT NULL,
    sales_order_line_id uuid NOT NULL,
    line_number integer NOT NULL,
    item_id uuid,
    description character varying(500),
    quantity numeric(12,4) NOT NULL,
    unit character varying(20),
    batch_id uuid
);


--
-- Name: demand_forecast; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.demand_forecast (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    item_id uuid NOT NULL,
    warehouse_id uuid,
    forecast_month date NOT NULL,
    forecast_qty numeric(15,4) DEFAULT 0 NOT NULL,
    actual_qty numeric(15,4),
    method character varying(30) DEFAULT 'MOVING_AVG'::character varying NOT NULL,
    confidence numeric(5,2),
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: detail_aid; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.detail_aid (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    name character varying(150) NOT NULL,
    description character varying(300),
    media_url text NOT NULL,
    media_type character varying(10) DEFAULT 'LINK'::character varying NOT NULL,
    product_name character varying(200),
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_state_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_state_config (
    id uuid NOT NULL,
    org_id uuid NOT NULL,
    document_type character varying(50) NOT NULL,
    from_state character varying(30) NOT NULL,
    to_state character varying(30) NOT NULL,
    allowed_roles text[] NOT NULL,
    requires_approval boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    is_deleted boolean DEFAULT false NOT NULL
);


--
-- Name: domain_event; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.domain_event (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    event_type character varying(80) NOT NULL,
    entity_type character varying(50) NOT NULL,
    entity_id uuid NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    before_state jsonb,
    after_state jsonb,
    actor_type character varying(30) NOT NULL,
    actor_id character varying(100),
    processed boolean DEFAULT false NOT NULL,
    processed_at timestamp without time zone,
    processing_error text,
    retry_count integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: domain_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.domain_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    event_type character varying(80) NOT NULL,
    entity_type character varying(50) NOT NULL,
    entity_id uuid NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    processed boolean DEFAULT false NOT NULL,
    processed_at timestamp with time zone,
    processing_error text,
    retry_count integer DEFAULT 0 NOT NULL,
    dead_letter boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: drug_interaction; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.drug_interaction (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    primary_salt_id uuid NOT NULL,
    interacting_salt_id uuid NOT NULL,
    severity character varying(20) NOT NULL,
    warning text NOT NULL,
    recommendation text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_drug_interaction_self CHECK ((primary_salt_id <> interacting_salt_id)),
    CONSTRAINT chk_drug_interaction_severity CHECK (((severity)::text = ANY (ARRAY[('LOW'::character varying)::text, ('MODERATE'::character varying)::text, ('HIGH'::character varying)::text, ('CRITICAL'::character varying)::text])))
);


--
-- Name: drug_licenses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.drug_licenses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    license_type character varying(50) NOT NULL,
    license_number character varying(100) NOT NULL,
    issued_by character varying(200),
    issue_date date,
    expiry_date date NOT NULL,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: drug_master; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.drug_master (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    brand_name character varying(255) NOT NULL,
    generic_name character varying(255),
    salt_id uuid,
    salt_composition text,
    manufacturer character varying(255),
    hsn_code character varying(10) DEFAULT '3004'::character varying,
    gst_rate numeric(5,2) DEFAULT 5,
    drug_schedule character varying(10) DEFAULT 'GENERAL'::character varying,
    dosage_form character varying(50),
    pack_size character varying(50),
    mrp numeric(15,2),
    prescription_required boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: einvoice; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.einvoice (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    document_number character varying(50) NOT NULL,
    document_date date NOT NULL,
    contact_id uuid,
    total_value numeric(15,2) DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    irn character varying(64),
    ack_number character varying(30),
    ack_date character varying(30),
    signed_qr text,
    generated_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    cancel_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    is_deleted boolean DEFAULT false NOT NULL
);


--
-- Name: email_template; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_template (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    template_type character varying(30) NOT NULL,
    subject character varying(255) NOT NULL,
    body_html text NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: email_verification_token; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_verification_token (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token_hash character varying(128) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used boolean DEFAULT false NOT NULL,
    used_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: employee; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.employee (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid,
    employee_code character varying(50),
    full_name character varying(255) NOT NULL,
    phone character varying(30),
    email character varying(255),
    designation character varying(100),
    department character varying(100),
    date_of_joining date,
    date_of_exit date,
    employment_status character varying(20) DEFAULT 'ACTIVE'::character varying,
    payment_mode character varying(20),
    bank_account_name character varying(255),
    bank_account_number character varying(50),
    bank_ifsc character varying(20),
    pan character varying(20),
    aadhaar_last4 character varying(4),
    uan character varying(50),
    esi_number character varying(50),
    is_pf_applicable boolean DEFAULT false NOT NULL,
    is_esi_applicable boolean DEFAULT false NOT NULL,
    is_pt_applicable boolean DEFAULT false NOT NULL,
    is_lwf_applicable boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    is_deleted boolean DEFAULT false,
    date_of_birth date,
    gender character varying(15),
    marital_status character varying(20),
    blood_group character varying(5),
    nationality character varying(50),
    personal_email character varying(255),
    current_address_line1 character varying(255),
    current_address_line2 character varying(255),
    current_city character varying(100),
    current_state character varying(100),
    current_pincode character varying(10),
    permanent_address_line1 character varying(255),
    permanent_address_line2 character varying(255),
    permanent_city character varying(100),
    permanent_state character varying(100),
    permanent_pincode character varying(10),
    emergency_contact_name character varying(150),
    emergency_contact_relationship character varying(50),
    emergency_contact_phone character varying(30),
    employment_type character varying(20),
    work_location character varying(150),
    probation_end_date date,
    confirmation_date date,
    notice_period_days integer,
    photo_attachment_id uuid,
    CONSTRAINT employee_employment_type_check CHECK (((employment_type IS NULL) OR ((employment_type)::text = ANY ((ARRAY['FULL_TIME'::character varying, 'PART_TIME'::character varying, 'CONTRACT'::character varying, 'INTERN'::character varying, 'CONSULTANT'::character varying])::text[])))),
    CONSTRAINT employee_gender_check CHECK (((gender IS NULL) OR ((gender)::text = ANY ((ARRAY['MALE'::character varying, 'FEMALE'::character varying, 'OTHER'::character varying, 'PREFER_NOT_TO_SAY'::character varying])::text[])))),
    CONSTRAINT employee_marital_status_check CHECK (((marital_status IS NULL) OR ((marital_status)::text = ANY ((ARRAY['SINGLE'::character varying, 'MARRIED'::character varying, 'DIVORCED'::character varying, 'WIDOWED'::character varying])::text[]))))
);


--
-- Name: employee_salary_component; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.employee_salary_component (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    salary_structure_id uuid NOT NULL,
    salary_component_id uuid NOT NULL,
    calculation_type character varying(20) NOT NULL,
    amount numeric(14,2),
    percentage numeric(7,4),
    base_component_code character varying(50),
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT employee_salary_component_calculation_type_check CHECK (((calculation_type)::text = ANY (ARRAY[('FIXED'::character varying)::text, ('PERCENTAGE'::character varying)::text, ('FORMULA'::character varying)::text])))
);


--
-- Name: employee_salary_structure; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.employee_salary_structure (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    employee_id uuid NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    ctc_monthly numeric(14,2),
    gross_monthly numeric(14,2),
    status character varying(20) DEFAULT 'ACTIVE'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    pay_type character varying(20) DEFAULT 'SALARY'::character varying NOT NULL,
    hourly_rate numeric(12,2),
    piece_rate numeric(12,2),
    CONSTRAINT employee_salary_structure_pay_type_chk CHECK (((pay_type)::text = ANY ((ARRAY['SALARY'::character varying, 'HOURLY'::character varying, 'PIECE_RATE'::character varying])::text[])))
);


--
-- Name: entity_attachment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entity_attachment (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    entity_type character varying(30) NOT NULL,
    entity_id uuid NOT NULL,
    file_name character varying(255) NOT NULL,
    file_type character varying(100),
    file_size bigint,
    file_url character varying(1000) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    uploaded_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: entity_comment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entity_comment (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    entity_type character varying(30) NOT NULL,
    entity_id uuid NOT NULL,
    comment_text character varying(2000) NOT NULL,
    is_system boolean DEFAULT false NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: entry_number_sequence; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entry_number_sequence (
    org_id uuid NOT NULL,
    year integer NOT NULL,
    next_value bigint DEFAULT 1 NOT NULL
);


--
-- Name: estimate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.estimate (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    branch_id uuid,
    estimate_number character varying(30) NOT NULL,
    contact_id uuid NOT NULL,
    estimate_date date NOT NULL,
    expiry_date date,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    subtotal numeric(15,2) DEFAULT 0 NOT NULL,
    discount_amount numeric(15,2) DEFAULT 0 NOT NULL,
    tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    total numeric(15,2) DEFAULT 0 NOT NULL,
    currency character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    reference_number character varying(60),
    subject character varying(200),
    notes text,
    terms text,
    converted_to_invoice_id uuid,
    converted_at timestamp with time zone,
    sent_at timestamp with time zone,
    accepted_at timestamp with time zone,
    declined_at timestamp with time zone,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT estimate_status_check CHECK (((status)::text = ANY (ARRAY[('DRAFT'::character varying)::text, ('SENT'::character varying)::text, ('ACCEPTED'::character varying)::text, ('DECLINED'::character varying)::text, ('INVOICED'::character varying)::text, ('EXPIRED'::character varying)::text])))
);


--
-- Name: estimate_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.estimate_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    estimate_id uuid NOT NULL,
    line_number integer NOT NULL,
    item_id uuid,
    description character varying(500) NOT NULL,
    unit character varying(20),
    hsn_code character varying(10),
    quantity numeric(15,3) DEFAULT 1 NOT NULL,
    rate numeric(15,2) DEFAULT 0 NOT NULL,
    discount_pct numeric(5,2) DEFAULT 0 NOT NULL,
    tax_rate numeric(5,2) DEFAULT 0 NOT NULL,
    amount numeric(15,2) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: eway_bill; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.eway_bill (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    document_type character varying(20) NOT NULL,
    document_id uuid NOT NULL,
    document_number character varying(50) NOT NULL,
    document_date date NOT NULL,
    contact_id uuid,
    total_value numeric(15,2) DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    ewb_number character varying(20),
    vehicle_number character varying(30),
    transport_mode character varying(10) DEFAULT 'ROAD'::character varying NOT NULL,
    transporter_id character varying(15),
    transporter_name character varying(255),
    distance_km integer,
    from_state_code character varying(5),
    to_state_code character varying(5),
    generated_at timestamp with time zone,
    valid_until timestamp with time zone,
    cancelled_at timestamp with time zone,
    cancel_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    is_deleted boolean DEFAULT false NOT NULL
);


--
-- Name: exchange_rate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.exchange_rate (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    from_currency character varying(3) NOT NULL,
    to_currency character varying(3) NOT NULL,
    rate numeric(15,6) NOT NULL,
    effective_date date NOT NULL,
    source character varying(30) DEFAULT 'MANUAL'::character varying NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: expense; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.expense (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    branch_id uuid,
    expense_number character varying(30) NOT NULL,
    expense_date date NOT NULL,
    account_id uuid NOT NULL,
    category character varying(60),
    description character varying(500),
    amount numeric(15,2) NOT NULL,
    tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    total numeric(15,2) NOT NULL,
    currency character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    gst_rate numeric(5,2) DEFAULT 0 NOT NULL,
    tax_group_id uuid,
    contact_id uuid,
    payment_mode character varying(20) DEFAULT 'CASH'::character varying NOT NULL,
    paid_through_id uuid NOT NULL,
    is_billable boolean DEFAULT false NOT NULL,
    project_id uuid,
    customer_contact_id uuid,
    receipt_url character varying(1000),
    status character varying(20) DEFAULT 'RECORDED'::character varying NOT NULL,
    journal_entry_id uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT expense_payment_mode_check CHECK (((payment_mode)::text = ANY (ARRAY[('CASH'::character varying)::text, ('BANK'::character varying)::text, ('UPI'::character varying)::text, ('CREDIT_CARD'::character varying)::text]))),
    CONSTRAINT expense_status_check CHECK (((status)::text = ANY (ARRAY[('RECORDED'::character varying)::text, ('BILLABLE'::character varying)::text, ('INVOICED'::character varying)::text, ('VOID'::character varying)::text])))
);


--
-- Name: field_allowance_claim; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.field_allowance_claim (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    salesperson_id uuid NOT NULL,
    claim_date date NOT NULL,
    distance_km numeric(10,2) DEFAULT 0 NOT NULL,
    ta_amount numeric(14,2) DEFAULT 0 NOT NULL,
    da_amount numeric(14,2) DEFAULT 0 NOT NULL,
    total_amount numeric(14,2) DEFAULT 0 NOT NULL,
    expense_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    gps_distance_km numeric(10,2) DEFAULT 0 NOT NULL
);


--
-- Name: field_attendance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.field_attendance (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid NOT NULL,
    work_date date NOT NULL,
    punch_in_at timestamp with time zone,
    punch_in_latitude numeric(10,7),
    punch_in_longitude numeric(10,7),
    punch_out_at timestamp with time zone,
    punch_out_latitude numeric(10,7),
    punch_out_longitude numeric(10,7),
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: field_location_ping; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.field_location_ping (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    salesperson_id uuid NOT NULL,
    route_execution_id uuid,
    latitude numeric(10,7) NOT NULL,
    longitude numeric(10,7) NOT NULL,
    accuracy_m numeric(8,2),
    recorded_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: field_sales_assignment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.field_sales_assignment (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    salesperson_id uuid NOT NULL,
    route_id uuid,
    van_id uuid,
    territory character varying(100),
    effective_from date NOT NULL,
    effective_to date,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: field_sample_txn; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.field_sample_txn (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    salesperson_id uuid NOT NULL,
    item_id uuid,
    product_name character varying(200) NOT NULL,
    txn_type character varying(10) NOT NULL,
    quantity integer NOT NULL,
    txn_date date NOT NULL,
    notes text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: field_sync_entry; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.field_sync_entry (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    salesperson_id uuid NOT NULL,
    client_id character varying(120) NOT NULL,
    action_type character varying(40) NOT NULL,
    status character varying(20) NOT NULL,
    result_summary text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: field_visit; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.field_visit (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    route_execution_id uuid NOT NULL,
    contact_id uuid NOT NULL,
    beat_id uuid,
    sequence_number integer,
    status character varying(20) DEFAULT 'PLANNED'::character varying NOT NULL,
    check_in_time timestamp with time zone,
    check_out_time timestamp with time zone,
    check_in_latitude numeric(10,7),
    check_in_longitude numeric(10,7),
    check_out_latitude numeric(10,7),
    check_out_longitude numeric(10,7),
    sales_order_id uuid,
    order_value numeric(15,2) DEFAULT 0,
    collection_amount numeric(15,2) DEFAULT 0,
    delivery_challan_id uuid,
    skip_reason character varying(200),
    notes text,
    photo_url text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    geo_verified boolean,
    geo_distance_m numeric(10,2),
    joint_visit_user_id uuid
);


--
-- Name: fiscal_period; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fiscal_period (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    period_year integer NOT NULL,
    period_month integer NOT NULL,
    status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    closed_at timestamp with time zone,
    closed_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT fiscal_period_period_month_check CHECK (((period_month >= 1) AND (period_month <= 12))),
    CONSTRAINT fiscal_period_status_check CHECK (((status)::text = ANY (ARRAY[('OPEN'::character varying)::text, ('CLOSED'::character varying)::text, ('LOCKED'::character varying)::text])))
);


--
-- Name: fixed_asset; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fixed_asset (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    asset_code character varying(40) NOT NULL,
    name character varying(200) NOT NULL,
    category character varying(60),
    acquisition_date date NOT NULL,
    cost numeric(18,2) NOT NULL,
    residual_value numeric(18,2) DEFAULT 0 NOT NULL,
    book_method character varying(10) NOT NULL,
    book_useful_life_months integer,
    book_rate_pct numeric(7,3),
    accumulated_depreciation numeric(18,2) DEFAULT 0 NOT NULL,
    it_block character varying(40),
    it_rate_pct numeric(7,3),
    asset_account_code character varying(20),
    accumulated_dep_account_code character varying(20),
    dep_expense_account_code character varying(20),
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    disposal_date date,
    disposal_proceeds numeric(18,2),
    source_bill_id uuid,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: fixed_asset_depreciation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fixed_asset_depreciation (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    fixed_asset_id uuid NOT NULL,
    period_year integer NOT NULL,
    period_month integer NOT NULL,
    opening_wdv numeric(18,2) NOT NULL,
    depreciation_amount numeric(18,2) NOT NULL,
    closing_wdv numeric(18,2) NOT NULL,
    journal_entry_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: freight_rate_card; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.freight_rate_card (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    transporter_contact_id uuid NOT NULL,
    origin character varying(120) NOT NULL,
    destination character varying(120) NOT NULL,
    mode character varying(10) DEFAULT 'ROAD'::character varying NOT NULL,
    weight_slab_min_kg numeric(12,3) DEFAULT 0 NOT NULL,
    weight_slab_max_kg numeric(12,3),
    rate_type character varying(10) DEFAULT 'PER_KG'::character varying NOT NULL,
    rate numeric(14,2) NOT NULL,
    min_charge numeric(14,2) DEFAULT 0 NOT NULL,
    effective_from date,
    effective_to date,
    active boolean DEFAULT true NOT NULL,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_by uuid,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: generic_substitution; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.generic_substitution (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    drug_master_id uuid NOT NULL,
    substitute_drug_master_id uuid NOT NULL,
    reason character varying(255),
    estimated_savings numeric(15,2),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_generic_substitution_self CHECK ((drug_master_id <> substitute_drug_master_id))
);


--
-- Name: gst_filing_snapshot; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gst_filing_snapshot (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    return_period character varying(7) NOT NULL,
    source character varying(20) NOT NULL,
    entry_count integer DEFAULT 0 NOT NULL,
    refreshed_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: gst_state_code; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gst_state_code (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(2) NOT NULL,
    state_name character varying(60) NOT NULL,
    alpha_code character varying(3),
    is_union_territory boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: gstr2b_entry; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gstr2b_entry (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    return_period character varying(7) NOT NULL,
    supplier_gstin character varying(15) NOT NULL,
    supplier_name character varying(255),
    invoice_number character varying(100) NOT NULL,
    invoice_date date,
    invoice_value numeric(15,2) DEFAULT 0 NOT NULL,
    taxable_value numeric(15,2) DEFAULT 0 NOT NULL,
    igst numeric(15,2) DEFAULT 0 NOT NULL,
    cgst numeric(15,2) DEFAULT 0 NOT NULL,
    sgst numeric(15,2) DEFAULT 0 NOT NULL,
    cess numeric(15,2) DEFAULT 0 NOT NULL,
    itc_available boolean DEFAULT true NOT NULL,
    match_status character varying(30) DEFAULT 'UNMATCHED'::character varying NOT NULL,
    matched_bill_id uuid,
    match_note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: hr_employee_document; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hr_employee_document (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    employee_user_id uuid NOT NULL,
    category character varying(40) DEFAULT 'OTHER'::character varying NOT NULL,
    title character varying(200) NOT NULL,
    file_name character varying(255),
    file_url character varying(1000),
    file_type character varying(100),
    file_size bigint,
    expiry_date date,
    attachment_id uuid,
    uploaded_by uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: hr_employee_education; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hr_employee_education (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    employee_id uuid NOT NULL,
    degree character varying(100) NOT NULL,
    field_of_study character varying(150),
    institution character varying(255),
    start_year integer,
    end_year integer,
    grade character varying(50),
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: hr_employee_experience; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hr_employee_experience (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    employee_id uuid NOT NULL,
    company_name character varying(255) NOT NULL,
    designation character varying(150),
    from_date date,
    to_date date,
    location character varying(150),
    responsibilities text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hr_employee_experience_date_check CHECK (((to_date IS NULL) OR (from_date IS NULL) OR (to_date >= from_date)))
);


--
-- Name: hr_employee_family; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hr_employee_family (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    employee_id uuid NOT NULL,
    name character varying(150) NOT NULL,
    relationship character varying(30) NOT NULL,
    date_of_birth date,
    is_dependent boolean DEFAULT false NOT NULL,
    phone character varying(30),
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hr_employee_family_rel_check CHECK (((relationship)::text = ANY ((ARRAY['SPOUSE'::character varying, 'CHILD'::character varying, 'FATHER'::character varying, 'MOTHER'::character varying, 'SIBLING'::character varying, 'OTHER'::character varying])::text[])))
);


--
-- Name: hr_employee_profile; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hr_employee_profile (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid NOT NULL,
    date_of_birth date,
    gender character varying(20),
    blood_group character varying(8),
    marital_status character varying(20),
    personal_email character varying(255),
    personal_phone character varying(20),
    current_address text,
    emergency_contact_name character varying(120),
    emergency_contact_phone character varying(20),
    emergency_contact_relation character varying(40),
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: hr_holiday; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hr_holiday (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    holiday_date date NOT NULL,
    name character varying(120) NOT NULL,
    is_optional boolean DEFAULT false NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: hr_leave_balance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hr_leave_balance (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid NOT NULL,
    leave_type_id uuid NOT NULL,
    year integer NOT NULL,
    entitled numeric(6,1) DEFAULT 0 NOT NULL,
    carried_forward numeric(6,1) DEFAULT 0 NOT NULL,
    used numeric(6,1) DEFAULT 0 NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: hr_leave_type; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hr_leave_type (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    is_paid boolean DEFAULT true NOT NULL,
    annual_quota numeric(6,1) DEFAULT 0 NOT NULL,
    accrual_method character varying(10) DEFAULT 'ANNUAL'::character varying NOT NULL,
    carry_forward_max numeric(6,1) DEFAULT 0 NOT NULL,
    requires_approval boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT hr_leave_type_accrual_check CHECK (((accrual_method)::text = ANY ((ARRAY['ANNUAL'::character varying, 'MONTHLY'::character varying, 'NONE'::character varying])::text[])))
);


--
-- Name: hr_offboarding; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hr_offboarding (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    employee_user_id uuid NOT NULL,
    initiated_by uuid,
    resignation_date date,
    last_working_day date,
    reason text,
    status character varying(20) DEFAULT 'INITIATED'::character varying NOT NULL,
    fnf_amount numeric(15,2),
    fnf_settled boolean DEFAULT false NOT NULL,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hr_offboarding_status_check CHECK (((status)::text = ANY ((ARRAY['INITIATED'::character varying, 'COMPLETED'::character varying, 'CANCELLED'::character varying])::text[])))
);


--
-- Name: hr_offboarding_task; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hr_offboarding_task (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    offboarding_id uuid NOT NULL,
    label character varying(200) NOT NULL,
    category character varying(20) DEFAULT 'OTHER'::character varying NOT NULL,
    completed boolean DEFAULT false NOT NULL,
    completed_by uuid,
    completed_at timestamp with time zone,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: hr_shift; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hr_shift (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,
    weekly_offs character varying(40) DEFAULT 'SAT,SUN'::character varying,
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: hr_shift_assignment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hr_shift_assignment (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid NOT NULL,
    shift_id uuid NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: hr_ticket; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hr_ticket (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    raised_by_user_id uuid NOT NULL,
    category character varying(40) DEFAULT 'GENERAL'::character varying NOT NULL,
    subject character varying(200) NOT NULL,
    description text,
    priority character varying(10) DEFAULT 'NORMAL'::character varying NOT NULL,
    status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    assigned_to_user_id uuid,
    resolution text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hr_ticket_priority_check CHECK (((priority)::text = ANY ((ARRAY['LOW'::character varying, 'NORMAL'::character varying, 'HIGH'::character varying])::text[]))),
    CONSTRAINT hr_ticket_status_check CHECK (((status)::text = ANY ((ARRAY['OPEN'::character varying, 'IN_PROGRESS'::character varying, 'RESOLVED'::character varying, 'CLOSED'::character varying])::text[])))
);


--
-- Name: hr_ticket_comment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hr_ticket_comment (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    ticket_id uuid NOT NULL,
    author_user_id uuid NOT NULL,
    body text NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: hr_timesheet_entry; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hr_timesheet_entry (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid NOT NULL,
    work_date date NOT NULL,
    project character varying(150),
    task character varying(200),
    hours numeric(5,2) DEFAULT 0 NOT NULL,
    billable boolean DEFAULT false NOT NULL,
    notes text,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    approved_by uuid,
    decided_at timestamp with time zone,
    rejection_reason character varying(300),
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hr_timesheet_hours_check CHECK (((hours >= (0)::numeric) AND (hours <= (24)::numeric)))
);


--
-- Name: hsn_gst_master; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hsn_gst_master (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    hsn_code character varying(10) NOT NULL,
    description character varying(255) NOT NULL,
    category character varying(100),
    gst_rate numeric(5,2) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: idempotency_record; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.idempotency_record (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    idempotency_key character varying(200) NOT NULL,
    request_method character varying(10) NOT NULL,
    request_path character varying(300) NOT NULL,
    status character varying(20) DEFAULT 'IN_PROGRESS'::character varying NOT NULL,
    response_status integer,
    response_body text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL
);


--
-- Name: industry_feature_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.industry_feature_config (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    industry_template_id uuid NOT NULL,
    sub_category_code character varying(50),
    feature_flags jsonb DEFAULT '[]'::jsonb NOT NULL,
    uom_list jsonb DEFAULT '[]'::jsonb NOT NULL,
    coa_template character varying(30) DEFAULT 'INDIAN_STANDARD'::character varying NOT NULL,
    tax_template character varying(30) DEFAULT 'GST_INDIA'::character varying NOT NULL,
    default_accounts jsonb DEFAULT '{}'::jsonb NOT NULL,
    item_fields jsonb DEFAULT '[]'::jsonb NOT NULL,
    sample_items jsonb DEFAULT '[]'::jsonb NOT NULL,
    additional_accounts jsonb DEFAULT '[]'::jsonb NOT NULL
);


--
-- Name: industry_sub_category; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.industry_sub_category (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    industry_template_id uuid NOT NULL,
    sub_category_code character varying(50) NOT NULL,
    sub_category_label character varying(100) NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: industry_template; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.industry_template (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_type character varying(20) NOT NULL,
    industry_code character varying(30) NOT NULL,
    industry_label character varying(50) NOT NULL,
    industry_icon character varying(10),
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: integration_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.integration_config (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    integration_type character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    base_url text,
    api_key_hash text,
    settings jsonb,
    is_active boolean DEFAULT true NOT NULL,
    last_sync_at timestamp with time zone,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: integration_sync_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.integration_sync_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    created_by uuid,
    integration_id uuid NOT NULL,
    sync_type character varying(30),
    direction character varying(10),
    status character varying(20) DEFAULT 'RUNNING'::character varying NOT NULL,
    records_processed integer DEFAULT 0 NOT NULL,
    records_failed integer DEFAULT 0 NOT NULL,
    error_message text,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: invoice; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoice (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    branch_id uuid,
    contact_id uuid NOT NULL,
    sales_order_id uuid,
    invoice_number character varying(30) NOT NULL,
    invoice_date date NOT NULL,
    due_date date NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    subtotal numeric(15,2) DEFAULT 0 NOT NULL,
    tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    total_amount numeric(15,2) DEFAULT 0 NOT NULL,
    amount_paid numeric(15,2) DEFAULT 0 NOT NULL,
    balance_due numeric(15,2) DEFAULT 0 NOT NULL,
    currency character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    exchange_rate numeric(12,6) DEFAULT 1.000000 NOT NULL,
    base_subtotal numeric(15,2) DEFAULT 0 NOT NULL,
    base_tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    base_total numeric(15,2) DEFAULT 0 NOT NULL,
    place_of_supply character varying(50),
    is_reverse_charge boolean DEFAULT false NOT NULL,
    journal_entry_id uuid,
    notes text,
    terms_and_conditions text,
    period_year integer,
    period_month integer,
    sent_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    cancelled_by uuid,
    cancel_reason text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    tcs_amount numeric(15,2) DEFAULT 0 NOT NULL,
    currency_code character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    CONSTRAINT invoice_status_check CHECK (((status)::text = ANY (ARRAY[('DRAFT'::character varying)::text, ('SENT'::character varying)::text, ('PARTIALLY_PAID'::character varying)::text, ('PAID'::character varying)::text, ('CANCELLED'::character varying)::text, ('OVERDUE'::character varying)::text])))
);


--
-- Name: invoice_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoice_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    invoice_id uuid NOT NULL,
    line_number integer NOT NULL,
    description character varying(500) NOT NULL,
    hsn_code character varying(10),
    item_id uuid,
    batch_id uuid,
    quantity numeric(12,4) DEFAULT 1 NOT NULL,
    unit_price numeric(15,2) NOT NULL,
    discount_percent numeric(5,2) DEFAULT 0 NOT NULL,
    discount_amount numeric(15,2) DEFAULT 0 NOT NULL,
    taxable_amount numeric(15,2) NOT NULL,
    gst_rate numeric(5,2) DEFAULT 0 NOT NULL,
    tax_group_id uuid,
    tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    line_total numeric(15,2) NOT NULL,
    account_code character varying(20) NOT NULL,
    base_taxable_amount numeric(15,2) DEFAULT 0 NOT NULL,
    base_tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    base_line_total numeric(15,2) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: invoice_number_sequence; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoice_number_sequence (
    org_id uuid NOT NULL,
    prefix character varying(10) DEFAULT 'INV'::character varying NOT NULL,
    year integer NOT NULL,
    next_value bigint DEFAULT 1 NOT NULL
);


--
-- Name: item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.item (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    sku character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    item_type character varying(20) DEFAULT 'GOODS'::character varying NOT NULL,
    category character varying(100),
    brand character varying(100),
    hsn_code character varying(10),
    unit_of_measure character varying(20) DEFAULT 'PCS'::character varying NOT NULL,
    base_uom_id uuid,
    purchase_price numeric(15,2) DEFAULT 0 NOT NULL,
    sale_price numeric(15,2) DEFAULT 0 NOT NULL,
    mrp numeric(15,2),
    gst_rate numeric(5,2) DEFAULT 0 NOT NULL,
    default_tax_group_id uuid,
    track_inventory boolean DEFAULT true NOT NULL,
    track_batches boolean DEFAULT false NOT NULL,
    reorder_level numeric(12,4) DEFAULT 0 NOT NULL,
    reorder_quantity numeric(12,4) DEFAULT 0 NOT NULL,
    revenue_account_code character varying(20),
    cogs_account_code character varying(20),
    inventory_account_code character varying(20),
    group_id uuid,
    variant_attributes jsonb DEFAULT '{}'::jsonb NOT NULL,
    barcode character varying(50),
    manufacturer character varying(100),
    preferred_vendor_id uuid,
    weight numeric(12,4),
    weight_unit character varying(10),
    length numeric(12,4),
    width numeric(12,4),
    height numeric(12,4),
    dimension_unit character varying(10),
    drug_schedule character varying(10),
    composition text,
    dosage_form character varying(50),
    pack_size character varying(50),
    storage_condition character varying(100),
    prescription_required boolean DEFAULT false NOT NULL,
    weight_based_billing boolean DEFAULT false NOT NULL,
    purchase_uom_id uuid,
    purchase_uom_conversion numeric(15,4),
    purchase_price_per_uom numeric(15,2),
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    rack_location_id uuid,
    track_serial_numbers boolean DEFAULT false NOT NULL,
    is_phantom boolean DEFAULT false NOT NULL,
    fssai_license character varying(20),
    veg_classification character varying(20),
    allergens jsonb,
    nutritional_info jsonb,
    date_marking_type character varying(20),
    shelf_life_days integer,
    production_mode character varying(10),
    CONSTRAINT chk_item_variant_attrs_not_empty CHECK (((group_id IS NULL) OR ((variant_attributes IS NOT NULL) AND (jsonb_typeof(variant_attributes) = 'object'::text) AND (variant_attributes <> '{}'::jsonb)))),
    CONSTRAINT item_date_marking_type_chk CHECK (((date_marking_type IS NULL) OR ((date_marking_type)::text = ANY ((ARRAY['BEST_BEFORE'::character varying, 'USE_BY'::character varying, 'EXPIRY'::character varying])::text[])))),
    CONSTRAINT item_item_type_check CHECK (((item_type)::text = ANY (ARRAY[('GOODS'::character varying)::text, ('SERVICE'::character varying)::text, ('COMPOSITE'::character varying)::text]))),
    CONSTRAINT item_production_mode_check CHECK (((production_mode IS NULL) OR ((production_mode)::text = ANY ((ARRAY['MTO'::character varying, 'MTS'::character varying])::text[])))),
    CONSTRAINT item_shelf_life_days_chk CHECK (((shelf_life_days IS NULL) OR (shelf_life_days > 0))),
    CONSTRAINT item_veg_classification_chk CHECK (((veg_classification IS NULL) OR ((veg_classification)::text = ANY ((ARRAY['VEGETARIAN'::character varying, 'NON_VEGETARIAN'::character varying, 'VEGAN'::character varying, 'EGG'::character varying])::text[]))))
);


--
-- Name: item_group; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.item_group (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    sku_prefix character varying(50),
    hsn_code character varying(10),
    gst_rate numeric(5,2),
    default_uom character varying(20),
    default_purchase_price numeric(15,4),
    default_sale_price numeric(15,4),
    attribute_definitions jsonb DEFAULT '[]'::jsonb NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT chk_item_group_attr_defs_array CHECK ((jsonb_typeof(attribute_definitions) = 'array'::text))
);


--
-- Name: item_supplier; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.item_supplier (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    item_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    lead_time_days integer DEFAULT 7 NOT NULL,
    min_order_qty numeric(15,4) DEFAULT 1 NOT NULL,
    unit_price numeric(15,4) DEFAULT 0 NOT NULL,
    is_preferred boolean DEFAULT false NOT NULL,
    supplier_sku character varying(50),
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: item_unit_price; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.item_unit_price (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    item_id uuid NOT NULL,
    uom_id uuid NOT NULL,
    conversion_factor numeric(15,4) NOT NULL,
    custom_price numeric(15,2),
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT item_unit_price_conversion_factor_check CHECK ((conversion_factor > (0)::numeric))
);


--
-- Name: job_card; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_card (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    work_order_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    workstation_id uuid,
    sequence_number integer NOT NULL,
    assigned_to uuid,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    planned_start timestamp with time zone,
    planned_end timestamp with time zone,
    actual_start timestamp with time zone,
    actual_end timestamp with time zone,
    planned_qty numeric(15,4) DEFAULT 0,
    completed_qty numeric(15,4) DEFAULT 0,
    scrap_qty numeric(15,4) DEFAULT 0,
    time_logged_minutes integer DEFAULT 0,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: job_work_order; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_work_order (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    job_work_number character varying(20) NOT NULL,
    vendor_id uuid NOT NULL,
    warehouse_id uuid NOT NULL,
    work_order_id uuid,
    status character varying(30) DEFAULT 'DRAFT'::character varying NOT NULL,
    processing_charges numeric(15,2) DEFAULT 0,
    total_material_cost numeric(15,2) DEFAULT 0,
    total_cost numeric(15,2) DEFAULT 0,
    challan_number character varying(30),
    planned_send_date date,
    planned_return_date date,
    actual_send_date date,
    actual_return_date date,
    gst_return_deadline date,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: job_work_order_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_work_order_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    job_work_order_id uuid NOT NULL,
    item_id uuid NOT NULL,
    line_type character varying(10) DEFAULT 'MATERIAL'::character varying NOT NULL,
    sent_qty numeric(15,4) DEFAULT 0,
    received_qty numeric(15,4) DEFAULT 0,
    wastage_qty numeric(15,4) DEFAULT 0,
    unit_cost numeric(15,4) DEFAULT 0,
    line_cost numeric(15,2) DEFAULT 0,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: journal_entry; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.journal_entry (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    entry_number character varying(30) NOT NULL,
    effective_date date NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    description character varying(500),
    source_module character varying(30) NOT NULL,
    source_id uuid,
    status character varying(10) DEFAULT 'DRAFT'::character varying NOT NULL,
    reversal_of_id uuid,
    is_reversal boolean DEFAULT false NOT NULL,
    is_reversed boolean DEFAULT false NOT NULL,
    approval_status character varying(15) DEFAULT 'NONE'::character varying NOT NULL,
    approved_by uuid,
    approved_at timestamp with time zone,
    period_year integer NOT NULL,
    period_month integer NOT NULL,
    created_by uuid NOT NULL,
    tags jsonb DEFAULT '{}'::jsonb,
    is_post_dated boolean DEFAULT false NOT NULL,
    CONSTRAINT journal_entry_approval_status_check CHECK (((approval_status)::text = ANY (ARRAY[('NONE'::character varying)::text, ('PENDING'::character varying)::text, ('APPROVED'::character varying)::text, ('REJECTED'::character varying)::text]))),
    CONSTRAINT journal_entry_period_month_check CHECK (((period_month >= 1) AND (period_month <= 12))),
    CONSTRAINT journal_entry_source_module_check CHECK (((source_module)::text = ANY (ARRAY[('SALES'::character varying)::text, ('PURCHASE'::character varying)::text, ('PAYMENT'::character varying)::text, ('PAYROLL'::character varying)::text, ('INVENTORY'::character varying)::text, ('MANUAL'::character varying)::text, ('GST'::character varying)::text, ('BANK_REC'::character varying)::text, ('OPENING'::character varying)::text, ('POS'::character varying)::text, ('EXPENSE'::character varying)::text]))),
    CONSTRAINT journal_entry_status_check CHECK (((status)::text = ANY (ARRAY[('DRAFT'::character varying)::text, ('POSTED'::character varying)::text])))
);


--
-- Name: journal_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.journal_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    journal_entry_id uuid NOT NULL,
    account_id uuid NOT NULL,
    description character varying(500),
    currency character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    debit numeric(15,2) DEFAULT 0 NOT NULL,
    credit numeric(15,2) DEFAULT 0 NOT NULL,
    exchange_rate numeric(15,6) DEFAULT 1.000000 NOT NULL,
    base_debit numeric(15,2) DEFAULT 0 NOT NULL,
    base_credit numeric(15,2) DEFAULT 0 NOT NULL,
    tax_component_code character varying(20),
    cost_centre character varying(50),
    project_id uuid,
    CONSTRAINT chk_line_debit_or_credit CHECK ((((debit > (0)::numeric) AND (credit = (0)::numeric)) OR ((debit = (0)::numeric) AND (credit > (0)::numeric)) OR ((debit = (0)::numeric) AND (credit = (0)::numeric)))),
    CONSTRAINT journal_line_base_credit_check CHECK ((base_credit >= (0)::numeric)),
    CONSTRAINT journal_line_base_debit_check CHECK ((base_debit >= (0)::numeric)),
    CONSTRAINT journal_line_credit_check CHECK ((credit >= (0)::numeric)),
    CONSTRAINT journal_line_debit_check CHECK ((debit >= (0)::numeric))
);


--
-- Name: leave_request; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leave_request (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid NOT NULL,
    from_date date NOT NULL,
    to_date date NOT NULL,
    leave_type character varying(20) DEFAULT 'CASUAL'::character varying NOT NULL,
    reason text,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    approved_by uuid,
    approved_at timestamp with time zone,
    rejection_reason character varying(300),
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    leave_type_id uuid,
    working_days numeric(6,1)
);


--
-- Name: lorry_receipt; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lorry_receipt (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    lr_number character varying(40) NOT NULL,
    lr_date date NOT NULL,
    transporter_contact_id uuid NOT NULL,
    contact_id uuid,
    delivery_challan_id uuid,
    invoice_id uuid,
    eway_bill_no character varying(30),
    vehicle_number character varying(30),
    driver_name character varying(120),
    driver_phone character varying(20),
    origin character varying(120),
    destination character varying(120),
    distance_km numeric(10,2),
    mode character varying(10) DEFAULT 'ROAD'::character varying NOT NULL,
    num_packages integer,
    weight_kg numeric(12,3),
    declared_value numeric(14,2),
    freight_amount numeric(14,2) DEFAULT 0 NOT NULL,
    freight_basis character varying(15) DEFAULT 'TO_BE_BILLED'::character varying NOT NULL,
    gst_treatment character varying(10) DEFAULT 'RCM'::character varying NOT NULL,
    freight_gst_rate numeric(5,2) DEFAULT 5 NOT NULL,
    freight_bill_id uuid,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_by uuid,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: maintenance_schedule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.maintenance_schedule (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    workstation_id uuid NOT NULL,
    code character varying(50) NOT NULL,
    title character varying(200) NOT NULL,
    description text,
    frequency_days integer NOT NULL,
    last_completed_date date,
    next_due_date date NOT NULL,
    estimated_duration_min integer,
    assigned_to_user_id uuid,
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT maintenance_schedule_freq_check CHECK ((frequency_days > 0))
);


--
-- Name: maintenance_work_order; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.maintenance_work_order (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    mwo_number character varying(30) NOT NULL,
    workstation_id uuid NOT NULL,
    schedule_id uuid,
    maintenance_type character varying(20) NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    priority character varying(10) DEFAULT 'NORMAL'::character varying NOT NULL,
    title character varying(200) NOT NULL,
    description text,
    reported_at timestamp with time zone DEFAULT now() NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    downtime_minutes integer,
    cost numeric(15,2),
    assigned_to_user_id uuid,
    completed_by uuid,
    completion_notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT maintenance_work_order_priority_check CHECK (((priority)::text = ANY ((ARRAY['URGENT'::character varying, 'HIGH'::character varying, 'NORMAL'::character varying, 'LOW'::character varying])::text[]))),
    CONSTRAINT maintenance_work_order_status_check CHECK (((status)::text = ANY ((ARRAY['DRAFT'::character varying, 'IN_PROGRESS'::character varying, 'COMPLETED'::character varying, 'CANCELLED'::character varying])::text[]))),
    CONSTRAINT maintenance_work_order_type_check CHECK (((maintenance_type)::text = ANY ((ARRAY['PREVENTIVE'::character varying, 'BREAKDOWN'::character varying, 'INSPECTION'::character varying])::text[])))
);


--
-- Name: manufacturer_master; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.manufacturer_master (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    country character varying(100),
    website character varying(255),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: mrp_demand; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mrp_demand (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    created_by uuid,
    mrp_run_id uuid NOT NULL,
    item_id uuid NOT NULL,
    warehouse_id uuid,
    source_type character varying(30) NOT NULL,
    source_id uuid,
    required_date date NOT NULL,
    required_qty numeric(18,4) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: mrp_run; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mrp_run (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    run_date date NOT NULL,
    status character varying(20) DEFAULT 'RUNNING'::character varying NOT NULL,
    horizon_days integer DEFAULT 90 NOT NULL,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: mrp_supply; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mrp_supply (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    created_by uuid,
    mrp_run_id uuid NOT NULL,
    item_id uuid NOT NULL,
    warehouse_id uuid,
    supply_type character varying(30) NOT NULL,
    supply_id uuid,
    available_date date NOT NULL,
    available_qty numeric(18,4) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: network_order; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.network_order (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_number character varying(30) NOT NULL,
    buyer_org_id uuid NOT NULL,
    seller_org_id uuid NOT NULL,
    trading_partner_id uuid NOT NULL,
    buyer_po_id uuid,
    seller_so_id uuid,
    status character varying(30) DEFAULT 'PLACED'::character varying NOT NULL,
    total_amount numeric(15,2),
    total_qty numeric(10,2),
    requested_delivery_date date,
    buyer_notes text,
    seller_notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    confirmed_at timestamp with time zone,
    dispatched_at timestamp with time zone,
    delivered_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    is_deleted boolean DEFAULT false NOT NULL,
    CONSTRAINT chk_network_order_status CHECK (((status)::text = ANY (ARRAY[('PLACED'::character varying)::text, ('CONFIRMED'::character varying)::text, ('PARTIALLY_CONFIRMED'::character varying)::text, ('REJECTED'::character varying)::text, ('PROCESSING'::character varying)::text, ('DISPATCHED'::character varying)::text, ('PARTIALLY_DISPATCHED'::character varying)::text, ('DELIVERED'::character varying)::text, ('PARTIALLY_DELIVERED'::character varying)::text, ('CANCELLED'::character varying)::text, ('CLOSED'::character varying)::text])))
);


--
-- Name: network_order_event; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.network_order_event (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    network_order_id uuid NOT NULL,
    event_type character varying(50) NOT NULL,
    actor_org_id uuid NOT NULL,
    actor_user_id uuid,
    payload jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: network_order_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.network_order_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    network_order_id uuid NOT NULL,
    catalog_item_id uuid,
    buyer_item_id uuid,
    seller_item_id uuid,
    drug_master_id uuid,
    display_name character varying(200),
    hsn_code character varying(20),
    ordered_qty numeric(10,2) NOT NULL,
    confirmed_qty numeric(10,2),
    dispatched_qty numeric(10,2) DEFAULT 0,
    unit_price numeric(15,2) NOT NULL,
    line_total numeric(15,2),
    status character varying(30) DEFAULT 'PENDING'::character varying NOT NULL,
    seller_notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_nol_status CHECK (((status)::text = ANY (ARRAY[('PENDING'::character varying)::text, ('CONFIRMED'::character varying)::text, ('REJECTED'::character varying)::text, ('DISPATCHED'::character varying)::text, ('DELIVERED'::character varying)::text, ('CANCELLED'::character varying)::text])))
);


--
-- Name: non_conformance_report; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.non_conformance_report (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    ncr_number character varying(30) NOT NULL,
    qc_inspection_id uuid,
    item_id uuid NOT NULL,
    batch_number character varying(100),
    severity character varying(10) DEFAULT 'MAJOR'::character varying NOT NULL,
    reason character varying(500),
    description text,
    status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    corrective_action text,
    root_cause text,
    closed_at timestamp with time zone,
    closed_by uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: notification; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid,
    title character varying(255) NOT NULL,
    message text,
    severity character varying(10) DEFAULT 'INFO'::character varying NOT NULL,
    type character varying(30) DEFAULT 'SYSTEM'::character varying NOT NULL,
    entity_type character varying(30),
    entity_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    channel character varying(20) DEFAULT 'IN_APP'::character varying NOT NULL,
    is_read boolean DEFAULT false NOT NULL,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT notification_channel_check CHECK (((channel)::text = ANY (ARRAY[('IN_APP'::character varying)::text, ('EMAIL'::character varying)::text, ('WHATSAPP'::character varying)::text, ('SMS'::character varying)::text, ('PUSH'::character varying)::text]))),
    CONSTRAINT notification_severity_check CHECK (((severity)::text = ANY (ARRAY[('INFO'::character varying)::text, ('WARNING'::character varying)::text, ('CRITICAL'::character varying)::text]))),
    CONSTRAINT notification_type_check CHECK (((type)::text = ANY (ARRAY[('PAYMENT_REMINDER'::character varying)::text, ('EXPIRY_ALERT'::character varying)::text, ('LOW_STOCK_ALERT'::character varying)::text, ('DAILY_SUMMARY'::character varying)::text, ('BILL_OVERDUE'::character varying)::text, ('SYSTEM'::character varying)::text, ('INFO'::character varying)::text, ('WARNING'::character varying)::text])))
);


--
-- Name: operation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operation (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    default_workstation_id uuid,
    setup_time_minutes integer DEFAULT 0,
    run_time_minutes_per_unit numeric(10,2) DEFAULT 0,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: org_ai_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_ai_settings (
    org_id uuid NOT NULL,
    provider character varying(20) DEFAULT 'CLAUDE'::character varying NOT NULL,
    model_name character varying(100) DEFAULT 'claude-sonnet-4-20250514'::character varying NOT NULL,
    base_url character varying(255),
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid,
    CONSTRAINT org_ai_settings_provider_check CHECK (((provider)::text = ANY (ARRAY[('CLAUDE'::character varying)::text, ('OLLAMA'::character varying)::text])))
);


--
-- Name: org_bootstrap_status; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_bootstrap_status (
    org_id uuid NOT NULL,
    uoms_seeded_at timestamp with time zone,
    accounts_seeded_at timestamp with time zone,
    default_accounts_seeded_at timestamp with time zone,
    tax_config_seeded_at timestamp with time zone,
    last_bootstrap_at timestamp with time zone DEFAULT now() NOT NULL,
    last_bootstrap_status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    last_error_message text,
    onboarding_completed boolean DEFAULT false NOT NULL
);


--
-- Name: org_default_account; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_default_account (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    purpose character varying(40) NOT NULL,
    account_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: org_feature_flag; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_feature_flag (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    feature character varying(50) NOT NULL,
    is_enabled boolean DEFAULT false NOT NULL,
    config jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: org_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    key character varying(100) NOT NULL,
    value text NOT NULL
);


--
-- Name: organisation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organisation (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    country_code character varying(2) DEFAULT 'IN'::character varying NOT NULL,
    base_currency character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    timezone character varying(50) DEFAULT 'Asia/Kolkata'::character varying NOT NULL,
    tax_regime character varying(30) DEFAULT 'INDIA_GST'::character varying NOT NULL,
    fiscal_year_start integer DEFAULT 4 NOT NULL,
    gstin character varying(15),
    tax_id character varying(50),
    state_code character varying(5),
    region_code character varying(20),
    industry character varying(50),
    business_type character varying(20) DEFAULT 'RETAILER'::character varying NOT NULL,
    industry_code character varying(30) DEFAULT 'OTHER_RETAIL'::character varying NOT NULL,
    sub_categories jsonb DEFAULT '[]'::jsonb NOT NULL,
    plan_tier character varying(20) DEFAULT 'FREE_BETA'::character varying NOT NULL,
    address_line1 character varying(255),
    address_line2 character varying(255),
    city character varying(100),
    state character varying(100),
    postal_code character varying(20),
    phone character varying(20),
    email character varying(255),
    logo_url character varying(500),
    approval_status character varying(20) DEFAULT 'APPROVED'::character varying NOT NULL,
    approved_at timestamp with time zone,
    approved_by uuid,
    approval_note character varying(255),
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    suspended_reason text,
    rejection_reason text,
    salary_handling_mode character varying(20) DEFAULT 'NONE'::character varying,
    fssai_license character varying(20),
    fssai_license_expiry date,
    CONSTRAINT organisation_approval_status_check CHECK (((approval_status)::text = ANY (ARRAY[('PENDING'::character varying)::text, ('APPROVED'::character varying)::text, ('REJECTED'::character varying)::text, ('SUSPENDED'::character varying)::text]))),
    CONSTRAINT organisation_business_type_check CHECK (((business_type)::text = ANY (ARRAY[('RETAILER'::character varying)::text, ('DISTRIBUTOR'::character varying)::text, ('MANUFACTURER'::character varying)::text, ('SERVICE_PROVIDER'::character varying)::text])))
);


--
-- Name: password_reset_token; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.password_reset_token (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token_hash character varying(128) NOT NULL,
    delivery_method character varying(10) DEFAULT 'EMAIL'::character varying NOT NULL,
    delivered_to character varying(255) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used boolean DEFAULT false NOT NULL,
    used_at timestamp with time zone,
    ip_address character varying(45),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: payment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    branch_id uuid,
    contact_id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    payment_number character varying(30) NOT NULL,
    payment_date date NOT NULL,
    amount numeric(15,2) NOT NULL,
    currency character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    exchange_rate numeric(12,6) DEFAULT 1.000000 NOT NULL,
    base_amount numeric(15,2) NOT NULL,
    payment_method character varying(30) NOT NULL,
    reference_number character varying(100),
    bank_account character varying(50),
    notes text,
    journal_entry_id uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    status character varying(25) DEFAULT 'POSTED'::character varying NOT NULL,
    posted_at timestamp with time zone,
    posted_by uuid,
    void_reason text,
    voided_at timestamp with time zone,
    voided_by uuid,
    CONSTRAINT payment_payment_method_check CHECK (((payment_method)::text = ANY (ARRAY[('CASH'::character varying)::text, ('BANK_TRANSFER'::character varying)::text, ('UPI'::character varying)::text, ('CHEQUE'::character varying)::text, ('CARD'::character varying)::text, ('OTHER'::character varying)::text]))),
    CONSTRAINT payment_status_check CHECK (((status)::text = ANY (ARRAY[('DRAFT'::character varying)::text, ('POSTED'::character varying)::text, ('PENDING_APPROVAL'::character varying)::text, ('VOIDED'::character varying)::text])))
);


--
-- Name: payment_match; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_match (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    bank_transaction_id uuid NOT NULL,
    invoice_id uuid,
    contact_id uuid,
    matched_amount numeric(18,2) NOT NULL,
    confidence numeric(5,4) NOT NULL,
    match_status character varying(30) DEFAULT 'SUGGESTED'::character varying NOT NULL,
    payment_id uuid,
    accepted_by uuid,
    accepted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    match_type character varying(20) DEFAULT 'INVOICE'::character varying NOT NULL,
    bill_id uuid
);


--
-- Name: payroll_audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payroll_audit_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    entity_type character varying(50) NOT NULL,
    entity_id uuid NOT NULL,
    action character varying(50) NOT NULL,
    old_value jsonb,
    new_value jsonb,
    performed_by uuid,
    performed_at timestamp with time zone DEFAULT now()
);


--
-- Name: payroll_document_snapshot; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payroll_document_snapshot (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    payroll_run_id uuid NOT NULL,
    snapshot_json jsonb NOT NULL,
    snapshot_hash character varying(128),
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: payroll_payment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payroll_payment (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    payroll_run_id uuid NOT NULL,
    payment_date date NOT NULL,
    payment_account_id uuid NOT NULL,
    amount numeric(14,2) NOT NULL,
    payment_mode character varying(30),
    reference_number character varying(100),
    journal_entry_id uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: payroll_run; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payroll_run (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    period_start date NOT NULL,
    period_end date NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying,
    employee_count integer DEFAULT 0,
    gross_total numeric(14,2) DEFAULT 0,
    deduction_total numeric(14,2) DEFAULT 0,
    employer_contribution_total numeric(14,2) DEFAULT 0,
    net_pay_total numeric(14,2) DEFAULT 0,
    journal_entry_id uuid,
    created_by uuid,
    approved_by uuid,
    approved_at timestamp with time zone,
    posted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT payroll_run_status_check CHECK (((status)::text = ANY (ARRAY[('DRAFT'::character varying)::text, ('CALCULATED'::character varying)::text, ('APPROVED'::character varying)::text, ('POSTED'::character varying)::text, ('CANCELLED'::character varying)::text])))
);


--
-- Name: payroll_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payroll_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    payroll_start_month date,
    pay_frequency character varying(20) DEFAULT 'MONTHLY'::character varying,
    default_salary_expense_account_id uuid,
    default_salary_payable_account_id uuid,
    default_pf_payable_account_id uuid,
    default_esi_payable_account_id uuid,
    default_pt_payable_account_id uuid,
    default_lwf_payable_account_id uuid,
    default_tds_payable_account_id uuid,
    pf_enabled boolean DEFAULT false NOT NULL,
    esi_enabled boolean DEFAULT false NOT NULL,
    pt_enabled boolean DEFAULT false NOT NULL,
    lwf_enabled boolean DEFAULT false NOT NULL,
    tds_enabled boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: payslip; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payslip (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    payroll_run_id uuid NOT NULL,
    employee_id uuid NOT NULL,
    lop_days numeric(5,2) DEFAULT 0 NOT NULL,
    gross_pay numeric(14,2) DEFAULT 0,
    total_deductions numeric(14,2) DEFAULT 0,
    employer_contributions numeric(14,2) DEFAULT 0,
    net_pay numeric(14,2) DEFAULT 0,
    status character varying(20) DEFAULT 'DRAFT'::character varying,
    pdf_url text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: payslip_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payslip_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    payslip_id uuid NOT NULL,
    salary_component_id uuid NOT NULL,
    component_type character varying(20) NOT NULL,
    amount numeric(14,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: period_balance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.period_balance (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    account_id uuid NOT NULL,
    period_year integer NOT NULL,
    period_month integer NOT NULL,
    opening_balance numeric(15,2) DEFAULT 0 NOT NULL,
    total_debit numeric(15,2) DEFAULT 0 NOT NULL,
    total_credit numeric(15,2) DEFAULT 0 NOT NULL,
    closing_balance numeric(15,2) DEFAULT 0 NOT NULL,
    transaction_count integer DEFAULT 0 NOT NULL,
    currency character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    frozen_at timestamp with time zone,
    CONSTRAINT period_balance_period_month_check CHECK (((period_month >= 1) AND (period_month <= 12)))
);


--
-- Name: picklist; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.picklist (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    picklist_number character varying(30) NOT NULL,
    sales_order_id uuid NOT NULL,
    warehouse_id uuid NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    assigned_to uuid,
    notes text,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    CONSTRAINT picklist_status_check CHECK (((status)::text = ANY (ARRAY[('PENDING'::character varying)::text, ('IN_PROGRESS'::character varying)::text, ('COMPLETED'::character varying)::text, ('CANCELLED'::character varying)::text])))
);


--
-- Name: picklist_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.picklist_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    picklist_id uuid NOT NULL,
    sales_order_line_id uuid NOT NULL,
    item_id uuid NOT NULL,
    required_quantity numeric(15,4) NOT NULL,
    picked_quantity numeric(15,4) DEFAULT 0 NOT NULL,
    batch_id uuid,
    rack_location_id uuid,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT picklist_line_required_quantity_check CHECK ((required_quantity > (0)::numeric))
);


--
-- Name: planned_order; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.planned_order (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    mrp_run_id uuid NOT NULL,
    item_id uuid NOT NULL,
    warehouse_id uuid,
    order_type character varying(20) NOT NULL,
    planned_qty numeric(18,4) NOT NULL,
    planned_start_date date,
    planned_end_date date,
    lead_time_days integer DEFAULT 7 NOT NULL,
    supplier_id uuid,
    status character varying(20) DEFAULT 'PLANNED'::character varying NOT NULL,
    purchase_order_id uuid,
    work_order_id uuid,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: platform_admin; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.platform_admin (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    full_name character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    role character varying(30) DEFAULT 'PLATFORM_ADMIN'::character varying NOT NULL,
    token_version integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    failed_login_count integer DEFAULT 0 NOT NULL,
    locked_until timestamp with time zone,
    last_login_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: platform_admin_audit; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.platform_admin_audit (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    platform_admin_id uuid NOT NULL,
    action_type character varying(50) NOT NULL,
    target_type character varying(20),
    target_id uuid,
    target_name character varying(255),
    reason text,
    ip_address character varying(45),
    performed_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: portal_user; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.portal_user (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    contact_id uuid NOT NULL,
    kind character varying(20) NOT NULL,
    email character varying(255) NOT NULL,
    full_name character varying(255),
    password_hash character varying(255),
    status character varying(20) DEFAULT 'INVITED'::character varying NOT NULL,
    invite_token_hash character varying(255),
    invite_expires_at timestamp with time zone,
    last_login_at timestamp with time zone,
    token_version integer DEFAULT 0 NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: pos_cash_expense; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pos_cash_expense (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    register_id uuid NOT NULL,
    amount numeric(14,2) NOT NULL,
    description character varying(255) NOT NULL,
    expense_time timestamp with time zone DEFAULT now() NOT NULL,
    recorded_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: pos_cash_register; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pos_cash_register (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    branch_id uuid,
    register_date date NOT NULL,
    opening_balance numeric(14,2) DEFAULT 0 NOT NULL,
    actual_closing numeric(14,2),
    status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    notes text,
    opened_by uuid,
    closed_by uuid,
    closed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: posted_document_snapshot; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posted_document_snapshot (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    document_type character varying(50) NOT NULL,
    document_id uuid NOT NULL,
    document_number character varying(80),
    snapshot_json jsonb NOT NULL,
    snapshot_hash character varying(128),
    posted_at timestamp with time zone DEFAULT now() NOT NULL,
    posted_by uuid
);


--
-- Name: prescription_record; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.prescription_record (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    contact_id uuid,
    receipt_id uuid,
    doctor_name character varying(200),
    doctor_reg_number character varying(100),
    prescription_number character varying(100),
    prescribed_date date,
    valid_until date,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: prescription_record_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.prescription_record_item (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    prescription_record_id uuid NOT NULL,
    item_id uuid,
    item_name character varying(500) NOT NULL,
    quantity numeric(14,4) DEFAULT 1 NOT NULL,
    dosage_instructions text
);


--
-- Name: price_list; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.price_list (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    currency character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: price_list_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.price_list_item (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    price_list_id uuid NOT NULL,
    item_id uuid NOT NULL,
    min_quantity numeric(15,4) DEFAULT 1 NOT NULL,
    price numeric(15,4) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: production_cost_summary; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.production_cost_summary (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    created_by uuid,
    work_order_id uuid NOT NULL,
    work_order_number character varying(30) NOT NULL,
    finished_good_id uuid NOT NULL,
    planned_rm_cost numeric(15,2) DEFAULT 0,
    actual_rm_cost numeric(15,2) DEFAULT 0,
    planned_labor_cost numeric(15,2) DEFAULT 0,
    actual_labor_cost numeric(15,2) DEFAULT 0,
    planned_overhead numeric(15,2) DEFAULT 0,
    actual_overhead numeric(15,2) DEFAULT 0,
    planned_total numeric(15,2) DEFAULT 0,
    actual_total numeric(15,2) DEFAULT 0,
    material_variance numeric(15,2) DEFAULT 0,
    labor_variance numeric(15,2) DEFAULT 0,
    overhead_variance numeric(15,2) DEFAULT 0,
    total_variance numeric(15,2) DEFAULT 0,
    planned_qty numeric(15,4) DEFAULT 0,
    produced_qty numeric(15,4) DEFAULT 0,
    scrap_qty numeric(15,4) DEFAULT 0,
    yield_percentage numeric(5,2) DEFAULT 0,
    completed_at timestamp with time zone,
    is_deleted boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: production_scrap; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.production_scrap (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    work_order_id uuid NOT NULL,
    job_card_id uuid,
    item_id uuid NOT NULL,
    scrap_qty numeric(15,4) NOT NULL,
    unit_cost numeric(15,4) DEFAULT 0,
    scrap_cost numeric(15,2) DEFAULT 0,
    reason_code_id uuid,
    notes text,
    scrapped_at timestamp with time zone DEFAULT now() NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: proof_of_delivery; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.proof_of_delivery (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    delivery_challan_id uuid,
    invoice_id uuid,
    contact_id uuid,
    recipient_name character varying(150) NOT NULL,
    recipient_phone character varying(30),
    recipient_relation character varying(50),
    delivered_at timestamp with time zone NOT NULL,
    geo_latitude numeric(10,7),
    geo_longitude numeric(10,7),
    notes text,
    recorded_by uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT proof_of_delivery_link_check CHECK (((delivery_challan_id IS NOT NULL) OR (invoice_id IS NOT NULL)))
);


--
-- Name: published_catalog_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.published_catalog_item (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    item_id uuid NOT NULL,
    drug_master_id uuid,
    display_name character varying(200) NOT NULL,
    published_sku character varying(60),
    hsn_code character varying(20),
    manufacturer character varying(200),
    pack_size character varying(60),
    category character varying(100),
    description text,
    published_mrp numeric(15,2),
    published_ptr numeric(15,2),
    min_order_qty numeric(10,2) DEFAULT 1,
    availability_status character varying(20) DEFAULT 'AVAILABLE'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    CONSTRAINT chk_catalog_availability CHECK (((availability_status)::text = ANY (ARRAY[('AVAILABLE'::character varying)::text, ('LOW_STOCK'::character varying)::text, ('OUT_OF_STOCK'::character varying)::text, ('DISCONTINUED'::character varying)::text])))
);


--
-- Name: purchase_bill; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchase_bill (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    branch_id uuid,
    contact_id uuid NOT NULL,
    bill_number character varying(30) NOT NULL,
    vendor_bill_number character varying(100),
    bill_date date NOT NULL,
    due_date date NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    subtotal numeric(15,2) DEFAULT 0 NOT NULL,
    tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    total_amount numeric(15,2) DEFAULT 0 NOT NULL,
    amount_paid numeric(15,2) DEFAULT 0 NOT NULL,
    balance_due numeric(15,2) DEFAULT 0 NOT NULL,
    currency character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    exchange_rate numeric(12,6) DEFAULT 1.000000 NOT NULL,
    base_subtotal numeric(15,2) DEFAULT 0 NOT NULL,
    base_tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    base_total numeric(15,2) DEFAULT 0 NOT NULL,
    place_of_supply character varying(50),
    is_reverse_charge boolean DEFAULT false NOT NULL,
    tds_amount numeric(15,2) DEFAULT 0 NOT NULL,
    tds_section character varying(20),
    journal_entry_id uuid,
    notes text,
    terms_and_conditions text,
    period_year integer,
    period_month integer,
    posted_at timestamp with time zone,
    voided_at timestamp with time zone,
    voided_by uuid,
    void_reason text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT purchase_bill_status_check CHECK (((status)::text = ANY (ARRAY[('DRAFT'::character varying)::text, ('OPEN'::character varying)::text, ('PARTIALLY_PAID'::character varying)::text, ('PAID'::character varying)::text, ('VOID'::character varying)::text, ('OVERDUE'::character varying)::text])))
);


--
-- Name: purchase_bill_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchase_bill_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    purchase_bill_id uuid NOT NULL,
    line_number integer NOT NULL,
    description character varying(500) NOT NULL,
    hsn_code character varying(10),
    item_id uuid,
    account_id uuid NOT NULL,
    quantity numeric(12,4) DEFAULT 1 NOT NULL,
    unit_price numeric(15,2) NOT NULL,
    discount_percent numeric(5,2) DEFAULT 0 NOT NULL,
    discount_amount numeric(15,2) DEFAULT 0 NOT NULL,
    taxable_amount numeric(15,2) NOT NULL,
    gst_rate numeric(5,2) DEFAULT 0 NOT NULL,
    tax_group_id uuid,
    tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    line_total numeric(15,2) NOT NULL,
    base_taxable_amount numeric(15,2) DEFAULT 0 NOT NULL,
    base_tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    base_line_total numeric(15,2) DEFAULT 0 NOT NULL,
    unit_uom_id uuid,
    unit_conversion_factor numeric(15,4),
    base_quantity numeric(15,4),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: purchase_order_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchase_order_lines (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    po_id uuid NOT NULL,
    item_id uuid NOT NULL,
    description character varying(500),
    quantity numeric(19,4) NOT NULL,
    received_quantity numeric(19,4) DEFAULT 0 NOT NULL,
    unit_price numeric(19,4) DEFAULT 0 NOT NULL,
    tax_group_id uuid,
    line_total numeric(19,4) DEFAULT 0 NOT NULL
);


--
-- Name: purchase_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchase_orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    po_number character varying(30) NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    order_date date NOT NULL,
    expected_delivery_date date,
    notes text,
    warehouse_id uuid,
    total_amount numeric(19,4) DEFAULT 0 NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    currency_code character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    exchange_rate numeric(15,6) DEFAULT 1 NOT NULL
);


--
-- Name: purchase_requisition; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchase_requisition (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    requisition_number character varying(30) NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    requested_by uuid,
    approved_by uuid,
    approved_at timestamp with time zone,
    required_by_date date,
    supplier_id uuid,
    warehouse_id uuid,
    total_amount numeric(15,4) DEFAULT 0 NOT NULL,
    source character varying(30) DEFAULT 'MANUAL'::character varying NOT NULL,
    purchase_order_id uuid,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: purchase_requisition_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.purchase_requisition_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    created_by uuid,
    requisition_id uuid NOT NULL,
    item_id uuid NOT NULL,
    required_qty numeric(15,4) NOT NULL,
    estimated_unit_price numeric(15,4) DEFAULT 0 NOT NULL,
    estimated_line_total numeric(15,4) DEFAULT 0 NOT NULL,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: push_token; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.push_token (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid NOT NULL,
    device_token text NOT NULL,
    platform character varying(10) DEFAULT 'ANDROID'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: qc_inspection; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qc_inspection (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    inspection_number character varying(20) NOT NULL,
    template_id uuid,
    inspection_type character varying(20) NOT NULL,
    reference_type character varying(30),
    reference_id uuid,
    item_id uuid NOT NULL,
    batch_id uuid,
    inspected_qty numeric(15,4),
    accepted_qty numeric(15,4),
    rejected_qty numeric(15,4),
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    inspector_id uuid,
    inspected_at timestamp with time zone,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    disposition character varying(10),
    hold_qty numeric(15,4),
    quarantine_zone_id uuid,
    disposition_notes text,
    disposition_at timestamp with time zone,
    disposition_by uuid
);


--
-- Name: qc_inspection_result; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qc_inspection_result (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    inspection_id uuid NOT NULL,
    parameter_id uuid NOT NULL,
    measured_value character varying(100),
    numeric_value numeric(15,4),
    is_passed boolean,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: qc_parameter; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qc_parameter (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    template_id uuid NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    parameter_type character varying(20) DEFAULT 'NUMERIC'::character varying NOT NULL,
    unit character varying(20),
    min_value numeric(15,4),
    max_value numeric(15,4),
    acceptable_values text,
    is_mandatory boolean DEFAULT true NOT NULL,
    sequence_number integer DEFAULT 1 NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: qc_template; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qc_template (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    name character varying(100) NOT NULL,
    item_id uuid,
    inspection_type character varying(20) DEFAULT 'INCOMING'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: rack_location; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rack_location (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    warehouse_id uuid NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(100),
    zone character varying(50),
    aisle character varying(50),
    shelf character varying(50),
    bin character varying(50),
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: rcpa_audit; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rcpa_audit (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    salesperson_id uuid NOT NULL,
    chemist_contact_id uuid NOT NULL,
    audit_date date NOT NULL,
    field_visit_id uuid,
    remarks text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: rcpa_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rcpa_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    audit_id uuid NOT NULL,
    product_name character varying(255) NOT NULL,
    brand_type character varying(12) DEFAULT 'OWN'::character varying NOT NULL,
    competitor_name character varying(255),
    our_item_id uuid,
    quantity numeric(18,3) DEFAULT 0 NOT NULL,
    value numeric(18,2) DEFAULT 0 NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT rcpa_line_brand_type_check CHECK (((brand_type)::text = ANY ((ARRAY['OWN'::character varying, 'COMPETITOR'::character varying])::text[])))
);


--
-- Name: recurring_invoice; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recurring_invoice (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    profile_name character varying(200) NOT NULL,
    contact_id uuid NOT NULL,
    frequency character varying(20) NOT NULL,
    start_date date NOT NULL,
    end_date date,
    next_invoice_date date NOT NULL,
    line_items jsonb DEFAULT '[]'::jsonb NOT NULL,
    payment_terms_days integer DEFAULT 0 NOT NULL,
    auto_send boolean DEFAULT false NOT NULL,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    total_generated integer DEFAULT 0 NOT NULL,
    last_generated_at timestamp with time zone,
    notes text,
    terms text,
    currency character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT recurring_invoice_frequency_check CHECK (((frequency)::text = ANY (ARRAY[('WEEKLY'::character varying)::text, ('MONTHLY'::character varying)::text, ('QUARTERLY'::character varying)::text, ('HALF_YEARLY'::character varying)::text, ('YEARLY'::character varying)::text]))),
    CONSTRAINT recurring_invoice_status_check CHECK (((status)::text = ANY (ARRAY[('ACTIVE'::character varying)::text, ('PAUSED'::character varying)::text, ('STOPPED'::character varying)::text, ('EXPIRED'::character varying)::text])))
);


--
-- Name: recurring_invoice_generation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recurring_invoice_generation (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    recurring_invoice_id uuid NOT NULL,
    invoice_id uuid NOT NULL,
    generated_at timestamp with time zone DEFAULT now() NOT NULL,
    auto_sent boolean DEFAULT false NOT NULL
);


--
-- Name: refresh_token; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.refresh_token (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token_hash character varying(255) NOT NULL,
    device_info character varying(255),
    ip_address character varying(45),
    expires_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: reminder_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reminder_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    contact_id uuid NOT NULL,
    sent_at timestamp with time zone DEFAULT now() NOT NULL,
    channel character varying(20) DEFAULT 'WHATSAPP'::character varying NOT NULL,
    message_preview text,
    sent_by uuid,
    followup_status character varying(30),
    promise_to_pay_date date,
    note text
);


--
-- Name: reorder_policy; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reorder_policy (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    item_id uuid NOT NULL,
    warehouse_id uuid,
    safety_stock numeric(15,4) DEFAULT 0 NOT NULL,
    reorder_point numeric(15,4) DEFAULT 0 NOT NULL,
    reorder_qty numeric(15,4) DEFAULT 0 NOT NULL,
    max_stock numeric(15,4) DEFAULT 0 NOT NULL,
    eoq numeric(15,4) DEFAULT 0 NOT NULL,
    lead_time_days integer DEFAULT 7 NOT NULL,
    service_level_pct numeric(5,2) DEFAULT 95.00 NOT NULL,
    abc_class character varying(1),
    last_calculated timestamp with time zone,
    auto_reorder boolean DEFAULT false NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: return_order; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.return_order (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    return_number character varying(30) NOT NULL,
    return_type character varying(20) DEFAULT 'PURCHASE_RETURN'::character varying NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    contact_id uuid,
    original_reference_id uuid,
    original_reference_type character varying(30),
    warehouse_id uuid,
    reason_code character varying(30),
    reason_notes text,
    total_amount numeric(15,4) DEFAULT 0 NOT NULL,
    restock_fee numeric(15,4) DEFAULT 0 NOT NULL,
    net_refund numeric(15,4) DEFAULT 0 NOT NULL,
    approved_by uuid,
    approved_at timestamp with time zone,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: return_order_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.return_order_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    created_by uuid,
    return_order_id uuid NOT NULL,
    item_id uuid NOT NULL,
    batch_id uuid,
    quantity numeric(15,4) NOT NULL,
    unit_price numeric(15,4) DEFAULT 0 NOT NULL,
    line_total numeric(15,4) DEFAULT 0 NOT NULL,
    condition character varying(20) DEFAULT 'GOOD'::character varying NOT NULL,
    restock boolean DEFAULT true NOT NULL,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: route; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.route (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    day_of_week character varying(10),
    frequency character varying(20) DEFAULT 'WEEKLY'::character varying NOT NULL,
    warehouse_id uuid,
    estimated_distance_km numeric(8,2),
    estimated_duration_minutes integer,
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: route_beat; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.route_beat (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    route_id uuid NOT NULL,
    beat_id uuid NOT NULL,
    sequence_number integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: route_execution; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.route_execution (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    route_id uuid NOT NULL,
    salesperson_id uuid NOT NULL,
    van_id uuid,
    execution_date date NOT NULL,
    status character varying(20) DEFAULT 'PLANNED'::character varying NOT NULL,
    start_time timestamp with time zone,
    end_time timestamp with time zone,
    start_odometer numeric(10,1),
    end_odometer numeric(10,1),
    planned_visits integer DEFAULT 0 NOT NULL,
    completed_visits integer DEFAULT 0 NOT NULL,
    skipped_visits integer DEFAULT 0 NOT NULL,
    total_orders_value numeric(15,2) DEFAULT 0,
    total_collections numeric(15,2) DEFAULT 0,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: routing; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.routing (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    name character varying(100) NOT NULL,
    item_id uuid,
    is_default boolean DEFAULT false,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: routing_operation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.routing_operation (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    routing_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    workstation_id uuid,
    sequence_number integer NOT NULL,
    setup_time_override integer,
    run_time_override numeric(10,2),
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: routing_operation_dependency; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.routing_operation_dependency (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    routing_operation_id uuid NOT NULL,
    predecessor_routing_operation_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    CONSTRAINT routing_operation_dependency_no_self CHECK ((routing_operation_id <> predecessor_routing_operation_id))
);


--
-- Name: salary_component; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.salary_component (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(100) NOT NULL,
    component_type character varying(20) NOT NULL,
    taxability character varying(30),
    is_statutory boolean DEFAULT false,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT salary_component_component_type_check CHECK (((component_type)::text = ANY (ARRAY[('EARNING'::character varying)::text, ('DEDUCTION'::character varying)::text, ('EMPLOYER_CONTRIBUTION'::character varying)::text])))
);


--
-- Name: sales_order; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sales_order (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    branch_id uuid,
    salesorder_number character varying(30) NOT NULL,
    reference_number character varying(50),
    contact_id uuid NOT NULL,
    estimate_id uuid,
    order_date date NOT NULL,
    expected_shipment_date date,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    shipped_status character varying(20) DEFAULT 'NOT_SHIPPED'::character varying NOT NULL,
    invoiced_status character varying(20) DEFAULT 'NOT_INVOICED'::character varying NOT NULL,
    discount_type character varying(15) DEFAULT 'ITEM_LEVEL'::character varying,
    discount_amount numeric(15,2) DEFAULT 0,
    subtotal numeric(15,2) DEFAULT 0 NOT NULL,
    tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    shipping_charge numeric(15,2) DEFAULT 0,
    adjustment numeric(15,2) DEFAULT 0,
    adjustment_description character varying(200),
    total numeric(15,2) DEFAULT 0 NOT NULL,
    billing_address jsonb,
    shipping_address jsonb,
    payment_mode character varying(20),
    delivery_method character varying(50),
    currency character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    place_of_supply character varying(50),
    notes character varying(2000),
    terms character varying(2000),
    allow_backorder boolean DEFAULT false NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    currency_code character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    exchange_rate numeric(15,6) DEFAULT 1 NOT NULL,
    CONSTRAINT sales_order_discount_type_check CHECK (((discount_type)::text = ANY (ARRAY[('ITEM_LEVEL'::character varying)::text, ('ENTITY_LEVEL'::character varying)::text]))),
    CONSTRAINT sales_order_invoiced_status_check CHECK (((invoiced_status)::text = ANY (ARRAY[('NOT_INVOICED'::character varying)::text, ('PARTIALLY_INVOICED'::character varying)::text, ('FULLY_INVOICED'::character varying)::text]))),
    CONSTRAINT sales_order_shipped_status_check CHECK (((shipped_status)::text = ANY (ARRAY[('NOT_SHIPPED'::character varying)::text, ('PARTIALLY_SHIPPED'::character varying)::text, ('FULLY_SHIPPED'::character varying)::text]))),
    CONSTRAINT sales_order_status_check CHECK (((status)::text = ANY (ARRAY[('DRAFT'::character varying)::text, ('CONFIRMED'::character varying)::text, ('BACKORDER'::character varying)::text, ('PARTIALLY_SHIPPED'::character varying)::text, ('SHIPPED'::character varying)::text, ('PARTIALLY_INVOICED'::character varying)::text, ('INVOICED'::character varying)::text, ('COMPLETED'::character varying)::text, ('CANCELLED'::character varying)::text, ('VOID'::character varying)::text])))
);


--
-- Name: sales_order_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sales_order_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sales_order_id uuid NOT NULL,
    line_number integer NOT NULL,
    item_id uuid,
    description character varying(500),
    quantity numeric(12,4) NOT NULL,
    quantity_shipped numeric(12,4) DEFAULT 0 NOT NULL,
    quantity_invoiced numeric(12,4) DEFAULT 0 NOT NULL,
    quantity_backordered numeric(12,4) DEFAULT 0 NOT NULL,
    unit character varying(20),
    rate numeric(15,2) NOT NULL,
    discount_pct numeric(5,2) DEFAULT 0,
    tax_group_id uuid,
    tax_rate numeric(5,2) DEFAULT 0,
    hsn_code character varying(8),
    amount numeric(15,2) NOT NULL
);


--
-- Name: sales_receipt; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sales_receipt (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    branch_id uuid,
    receipt_number character varying(30) NOT NULL,
    contact_id uuid,
    receipt_date date NOT NULL,
    subtotal numeric(15,2) DEFAULT 0 NOT NULL,
    tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    total numeric(15,2) DEFAULT 0 NOT NULL,
    payment_mode character varying(20) NOT NULL,
    paid_through_id uuid,
    amount_received numeric(15,2) DEFAULT 0 NOT NULL,
    change_returned numeric(15,2) DEFAULT 0 NOT NULL,
    upi_reference character varying(50),
    cgst numeric(19,2) DEFAULT 0 NOT NULL,
    sgst numeric(19,2) DEFAULT 0 NOT NULL,
    igst numeric(19,2) DEFAULT 0 NOT NULL,
    gst_invoice boolean DEFAULT false NOT NULL,
    currency character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    notes character varying(500),
    journal_entry_id uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    offline_receipt_number character varying(30),
    CONSTRAINT sales_receipt_payment_mode_check CHECK (((payment_mode)::text = ANY (ARRAY[('CASH'::character varying)::text, ('UPI'::character varying)::text, ('CARD'::character varying)::text, ('MIXED'::character varying)::text])))
);


--
-- Name: sales_receipt_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sales_receipt_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    receipt_id uuid NOT NULL,
    line_number integer NOT NULL,
    item_id uuid,
    description character varying(500),
    quantity numeric(15,3) DEFAULT 1 NOT NULL,
    unit character varying(20),
    rate numeric(15,2) DEFAULT 0 NOT NULL,
    tax_group_id uuid,
    hsn_code character varying(8),
    amount numeric(15,2) DEFAULT 0 NOT NULL,
    batch_id uuid,
    stock_movement_id uuid,
    unit_uom_id uuid,
    unit_conversion_factor numeric(15,4),
    base_quantity numeric(15,4),
    mrp numeric(19,2),
    discount_per_unit numeric(19,2) DEFAULT 0 NOT NULL,
    discount_amount numeric(19,2) DEFAULT 0 NOT NULL
);


--
-- Name: salesman_target; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.salesman_target (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    salesperson_id uuid NOT NULL,
    period_type character varying(20) DEFAULT 'MONTHLY'::character varying NOT NULL,
    period_start date NOT NULL,
    period_end date NOT NULL,
    target_type character varying(30) NOT NULL,
    target_value numeric(15,2) NOT NULL,
    achieved_value numeric(15,2) DEFAULT 0 NOT NULL,
    achievement_pct numeric(5,2) DEFAULT 0 NOT NULL,
    incentive_rate numeric(10,2) DEFAULT 0,
    incentive_amount numeric(15,2) DEFAULT 0 NOT NULL,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: salt_master; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.salt_master (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    category character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: schemes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schemes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    name character varying(200) NOT NULL,
    scheme_type character varying(30) NOT NULL,
    item_id uuid,
    buy_quantity numeric(14,4),
    free_quantity numeric(14,4),
    discount_percent numeric(6,2),
    min_order_quantity numeric(14,4) DEFAULT 0,
    valid_from date,
    valid_to date,
    supplier_id uuid,
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: scrap_reason_code; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scrap_reason_code (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    code character varying(30) NOT NULL,
    description character varying(200) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: serial_number; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.serial_number (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    item_id uuid NOT NULL,
    serial character varying(100) NOT NULL,
    warehouse_id uuid,
    status character varying(20) DEFAULT 'IN_STOCK'::character varying NOT NULL,
    batch_id uuid,
    received_at timestamp with time zone,
    sold_at timestamp with time zone,
    receipt_line_id uuid,
    invoice_line_id uuid,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT serial_number_status_check CHECK (((status)::text = ANY (ARRAY[('IN_STOCK'::character varying)::text, ('SOLD'::character varying)::text, ('DAMAGED'::character varying)::text, ('RETURNED'::character varying)::text, ('RESERVED'::character varying)::text])))
);


--
-- Name: shipment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shipment (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    shipment_number character varying(30) NOT NULL,
    shipment_type character varying(20) NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    origin_warehouse_id uuid,
    destination_warehouse_id uuid,
    carrier character varying(100),
    tracking_number character varying(100),
    vehicle_number character varying(30),
    estimated_departure timestamp with time zone,
    actual_departure timestamp with time zone,
    estimated_arrival timestamp with time zone,
    actual_arrival timestamp with time zone,
    total_weight numeric(18,4),
    total_packages integer,
    freight_cost numeric(18,2) DEFAULT 0 NOT NULL,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: shipment_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shipment_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    created_by uuid,
    shipment_id uuid NOT NULL,
    reference_type character varying(30),
    reference_id uuid,
    item_id uuid NOT NULL,
    quantity numeric(18,4) NOT NULL,
    weight numeric(18,4),
    packages integer DEFAULT 1 NOT NULL,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: statutory_payment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.statutory_payment (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    statutory_type character varying(20) NOT NULL,
    period_label character varying(20),
    due_date date,
    payment_date date,
    amount numeric(14,2) NOT NULL,
    payment_account_id uuid,
    reference_number character varying(100),
    status character varying(20) DEFAULT 'PENDING'::character varying,
    journal_entry_id uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: stock_batch; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stock_batch (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    item_id uuid NOT NULL,
    batch_number character varying(100) NOT NULL,
    expiry_date date,
    manufacturing_date date,
    unit_cost numeric(15,4) DEFAULT 0 NOT NULL,
    supplier_id uuid,
    notes text,
    is_expired boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: stock_batch_balance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stock_batch_balance (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    batch_id uuid NOT NULL,
    warehouse_id uuid NOT NULL,
    quantity_on_hand numeric(15,4) DEFAULT 0 NOT NULL,
    last_movement_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: stock_count; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stock_count (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    warehouse_id uuid NOT NULL,
    count_number character varying(30) NOT NULL,
    count_date date NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    notes text,
    posted_at timestamp with time zone,
    posted_by uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT stock_count_status_check CHECK (((status)::text = ANY (ARRAY[('DRAFT'::character varying)::text, ('POSTED'::character varying)::text, ('CANCELLED'::character varying)::text])))
);


--
-- Name: stock_count_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stock_count_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    stock_count_id uuid NOT NULL,
    item_id uuid NOT NULL,
    expected_quantity numeric(15,4) DEFAULT 0 NOT NULL,
    counted_quantity numeric(15,4) DEFAULT 0 NOT NULL,
    variance numeric(15,4) DEFAULT 0 NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: stock_movement; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stock_movement (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    branch_id uuid,
    item_id uuid NOT NULL,
    warehouse_id uuid NOT NULL,
    movement_date date NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    movement_type character varying(20) NOT NULL,
    quantity numeric(15,4) NOT NULL,
    unit_cost numeric(15,4) DEFAULT 0 NOT NULL,
    total_cost numeric(15,2) DEFAULT 0 NOT NULL,
    reference_type character varying(30),
    reference_id uuid,
    reference_number character varying(50),
    batch_id uuid,
    is_reversal boolean DEFAULT false NOT NULL,
    reversal_of_id uuid,
    is_reversed boolean DEFAULT false NOT NULL,
    notes text,
    created_by uuid,
    CONSTRAINT stock_movement_movement_type_check CHECK (((movement_type)::text = ANY (ARRAY[('PURCHASE'::character varying)::text, ('SALE'::character varying)::text, ('ADJUSTMENT'::character varying)::text, ('TRANSFER_IN'::character varying)::text, ('TRANSFER_OUT'::character varying)::text, ('OPENING'::character varying)::text, ('RETURN_IN'::character varying)::text, ('RETURN_OUT'::character varying)::text, ('STOCK_COUNT'::character varying)::text, ('REVERSAL'::character varying)::text]))),
    CONSTRAINT stock_movement_reference_type_check CHECK (((reference_type)::text = ANY (ARRAY[('INVOICE'::character varying)::text, ('CREDIT_NOTE'::character varying)::text, ('BILL'::character varying)::text, ('DEBIT_NOTE'::character varying)::text, ('STOCK_ADJUSTMENT'::character varying)::text, ('STOCK_TRANSFER'::character varying)::text, ('STOCK_COUNT'::character varying)::text, ('OPENING_BALANCE'::character varying)::text, ('STOCK_RECEIPT'::character varying)::text, ('DELIVERY_CHALLAN'::character varying)::text, ('SALES_RECEIPT'::character varying)::text])))
);


--
-- Name: stock_receipt; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stock_receipt (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    branch_id uuid,
    receipt_number character varying(30) NOT NULL,
    receipt_date date NOT NULL,
    warehouse_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    supplier_invoice_no character varying(100),
    supplier_invoice_date date,
    subtotal numeric(15,2) DEFAULT 0 NOT NULL,
    tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    total_amount numeric(15,2) DEFAULT 0 NOT NULL,
    currency character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    status character varying(15) DEFAULT 'DRAFT'::character varying NOT NULL,
    received_at timestamp with time zone,
    received_by uuid,
    cancelled_at timestamp with time zone,
    cancelled_by uuid,
    cancel_reason character varying(500),
    notes text,
    period_year integer,
    period_month integer,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    freight_amount numeric(15,2) DEFAULT 0 NOT NULL,
    duty_amount numeric(15,2) DEFAULT 0 NOT NULL,
    insurance_amount numeric(15,2) DEFAULT 0 NOT NULL,
    other_charges numeric(15,2) DEFAULT 0 NOT NULL,
    CONSTRAINT stock_receipt_status_check CHECK (((status)::text = ANY (ARRAY[('DRAFT'::character varying)::text, ('RECEIVED'::character varying)::text, ('CANCELLED'::character varying)::text])))
);


--
-- Name: stock_receipt_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stock_receipt_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    receipt_id uuid NOT NULL,
    line_number integer NOT NULL,
    item_id uuid NOT NULL,
    description character varying(500),
    hsn_code character varying(10),
    quantity numeric(15,4) NOT NULL,
    unit_of_measure character varying(20) DEFAULT 'PCS'::character varying NOT NULL,
    unit_price numeric(15,4) NOT NULL,
    discount_percent numeric(5,2) DEFAULT 0 NOT NULL,
    discount_amount numeric(15,2) DEFAULT 0 NOT NULL,
    taxable_amount numeric(15,2) NOT NULL,
    gst_rate numeric(5,2) DEFAULT 0 NOT NULL,
    tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    line_total numeric(15,2) NOT NULL,
    batch_number character varying(50),
    batch_id uuid,
    expiry_date date,
    manufacturing_date date,
    stock_movement_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    landed_unit_cost numeric(15,4)
);


--
-- Name: stock_reservation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stock_reservation (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    item_id uuid NOT NULL,
    warehouse_id uuid NOT NULL,
    source_type character varying(20) NOT NULL,
    source_id uuid NOT NULL,
    source_line_id uuid NOT NULL,
    quantity_reserved numeric(12,4) NOT NULL,
    status character varying(15) DEFAULT 'ACTIVE'::character varying NOT NULL,
    reserved_at timestamp with time zone DEFAULT now() NOT NULL,
    fulfilled_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    CONSTRAINT stock_reservation_source_type_check CHECK (((source_type)::text = ANY (ARRAY[('SALES_ORDER'::character varying)::text, ('TRANSFER_ORDER'::character varying)::text]))),
    CONSTRAINT stock_reservation_status_check CHECK (((status)::text = ANY (ARRAY[('ACTIVE'::character varying)::text, ('FULFILLED'::character varying)::text, ('CANCELLED'::character varying)::text])))
);


--
-- Name: stockist_sales_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stockist_sales_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    statement_id uuid NOT NULL,
    item_id uuid,
    product_name character varying(255) NOT NULL,
    opening_qty numeric(18,3) DEFAULT 0 NOT NULL,
    purchase_qty numeric(18,3) DEFAULT 0 NOT NULL,
    sales_qty numeric(18,3) DEFAULT 0 NOT NULL,
    return_qty numeric(18,3) DEFAULT 0 NOT NULL,
    closing_qty numeric(18,3) DEFAULT 0 NOT NULL,
    sales_value numeric(18,2) DEFAULT 0 NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: stockist_sales_statement; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stockist_sales_statement (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    stockist_contact_id uuid NOT NULL,
    period_month date NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: supplier; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    gstin character varying(15),
    pan character varying(10),
    phone character varying(30),
    email character varying(255),
    address_line1 character varying(255),
    address_line2 character varying(255),
    city character varying(100),
    state character varying(100),
    state_code character varying(5),
    postal_code character varying(20),
    country character varying(2) DEFAULT 'IN'::character varying,
    payment_terms_days integer DEFAULT 30 NOT NULL,
    notes text,
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    lead_time_days integer DEFAULT 7 NOT NULL,
    quality_rating numeric(5,2) DEFAULT 0 NOT NULL,
    delivery_rating numeric(5,2) DEFAULT 0 NOT NULL,
    overall_rating numeric(5,2) DEFAULT 0 NOT NULL
);


--
-- Name: supplier_performance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_performance (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    supplier_id uuid NOT NULL,
    period_start date NOT NULL,
    period_end date NOT NULL,
    total_orders integer DEFAULT 0 NOT NULL,
    on_time_deliveries integer DEFAULT 0 NOT NULL,
    late_deliveries integer DEFAULT 0 NOT NULL,
    total_qty_ordered numeric(15,4) DEFAULT 0 NOT NULL,
    total_qty_received numeric(15,4) DEFAULT 0 NOT NULL,
    total_qty_rejected numeric(15,4) DEFAULT 0 NOT NULL,
    total_amount numeric(15,4) DEFAULT 0 NOT NULL,
    avg_lead_time_days numeric(8,2) DEFAULT 0 NOT NULL,
    on_time_rate numeric(5,2) DEFAULT 0 NOT NULL,
    quality_rate numeric(5,2) DEFAULT 0 NOT NULL,
    overall_score numeric(5,2) DEFAULT 0 NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: supply_chain_alert; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supply_chain_alert (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    alert_type character varying(30) NOT NULL,
    severity character varying(10) DEFAULT 'MEDIUM'::character varying NOT NULL,
    title character varying(200) NOT NULL,
    description text,
    item_id uuid,
    supplier_id uuid,
    warehouse_id uuid,
    reference_id uuid,
    reference_type character varying(30),
    status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    resolved_at timestamp with time zone,
    resolved_by uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: tax_configuration; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tax_configuration (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    country_code character varying(5) NOT NULL,
    tax_system character varying(20) NOT NULL,
    name character varying(50) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tax_group; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tax_group (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(200),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tax_group_rate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tax_group_rate (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tax_group_id uuid NOT NULL,
    tax_rate_id uuid NOT NULL
);


--
-- Name: tax_line_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tax_line_item (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    source_type character varying(30) NOT NULL,
    source_id uuid NOT NULL,
    source_line_id uuid,
    tax_regime character varying(30) NOT NULL,
    component_code character varying(10) NOT NULL,
    rate numeric(5,2) NOT NULL,
    taxable_amount numeric(15,2) NOT NULL,
    tax_amount numeric(15,2) NOT NULL,
    account_code character varying(20) NOT NULL,
    hsn_code character varying(10),
    base_taxable_amount numeric(15,2) DEFAULT 0 NOT NULL,
    base_tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT tax_line_item_source_type_check CHECK (((source_type)::text = ANY (ARRAY[('INVOICE'::character varying)::text, ('CREDIT_NOTE'::character varying)::text, ('BILL'::character varying)::text, ('EXPENSE'::character varying)::text, ('VENDOR_CREDIT'::character varying)::text, ('SALES_RECEIPT'::character varying)::text])))
);


--
-- Name: tax_rate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tax_rate (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    tax_config_id uuid NOT NULL,
    name character varying(50) NOT NULL,
    rate_code character varying(20) NOT NULL,
    percentage numeric(5,2) NOT NULL,
    tax_type character varying(20) NOT NULL,
    gl_output_account_id uuid,
    gl_input_account_id uuid,
    is_gl_account_customized boolean DEFAULT false NOT NULL,
    is_recoverable boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT tax_rate_tax_type_check CHECK (((tax_type)::text = ANY (ARRAY[('OUTPUT'::character varying)::text, ('INPUT'::character varying)::text, ('BOTH'::character varying)::text])))
);


--
-- Name: tour_plan; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tour_plan (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    salesperson_id uuid NOT NULL,
    plan_month date NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    notes text,
    submitted_at timestamp with time zone,
    approved_by uuid,
    approved_at timestamp with time zone,
    rejection_reason character varying(300),
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tour_plan_entry; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tour_plan_entry (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    tour_plan_id uuid NOT NULL,
    plan_date date NOT NULL,
    activity_type character varying(20) DEFAULT 'FIELD_WORK'::character varying NOT NULL,
    beat_id uuid,
    area character varying(150),
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: trading_partner; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trading_partner (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    seller_org_id uuid NOT NULL,
    buyer_org_id uuid NOT NULL,
    status character varying(30) DEFAULT 'PENDING'::character varying NOT NULL,
    requested_by_org_id uuid NOT NULL,
    price_list_id uuid,
    credit_limit numeric(15,2),
    payment_terms character varying(100),
    delivery_terms character varying(200),
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    approved_at timestamp with time zone,
    is_deleted boolean DEFAULT false NOT NULL,
    CONSTRAINT chk_trading_partner_diff_orgs CHECK ((seller_org_id <> buyer_org_id)),
    CONSTRAINT chk_trading_partner_status CHECK (((status)::text = ANY (ARRAY[('PENDING'::character varying)::text, ('APPROVED'::character varying)::text, ('REJECTED'::character varying)::text, ('SUSPENDED'::character varying)::text, ('REVOKED'::character varying)::text])))
);


--
-- Name: transfer_order; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transfer_order (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    transfer_number character varying(30) NOT NULL,
    from_warehouse_id uuid NOT NULL,
    to_warehouse_id uuid NOT NULL,
    transfer_date date NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    notes text,
    shipped_at timestamp with time zone,
    shipped_by uuid,
    received_at timestamp with time zone,
    received_by uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT chk_transfer_order_warehouses CHECK ((from_warehouse_id <> to_warehouse_id)),
    CONSTRAINT transfer_order_status_check CHECK (((status)::text = ANY (ARRAY[('DRAFT'::character varying)::text, ('IN_TRANSIT'::character varying)::text, ('RECEIVED'::character varying)::text, ('CANCELLED'::character varying)::text])))
);


--
-- Name: transfer_order_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transfer_order_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    transfer_order_id uuid NOT NULL,
    item_id uuid NOT NULL,
    batch_id uuid,
    quantity numeric(15,4) NOT NULL,
    received_quantity numeric(15,4) DEFAULT 0 NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT transfer_order_line_quantity_check CHECK ((quantity > (0)::numeric))
);


--
-- Name: uom; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uom (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    name character varying(50) NOT NULL,
    abbreviation character varying(20) NOT NULL,
    category character varying(20) NOT NULL,
    is_base boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT uom_category_check CHECK (((category)::text = ANY (ARRAY[('WEIGHT'::character varying)::text, ('VOLUME'::character varying)::text, ('COUNT'::character varying)::text, ('LENGTH'::character varying)::text, ('PACKAGING'::character varying)::text])))
);


--
-- Name: uom_conversion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uom_conversion (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    item_id uuid,
    from_uom_id uuid NOT NULL,
    to_uom_id uuid NOT NULL,
    factor numeric(18,6) NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT uom_conversion_factor_check CHECK ((factor > (0)::numeric)),
    CONSTRAINT uom_conversion_not_self CHECK ((from_uom_id <> to_uom_id))
);


--
-- Name: user_invitation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_invitation (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    email character varying(255),
    phone character varying(20),
    role character varying(20) DEFAULT 'VIEWER'::character varying NOT NULL,
    token character varying(255) NOT NULL,
    invited_by uuid NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    accepted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_invite_has_contact CHECK (((email IS NOT NULL) OR (phone IS NOT NULL))),
    CONSTRAINT user_invitation_role_check CHECK (((role)::text = ANY (ARRAY[('OWNER'::character varying)::text, ('ADMIN'::character varying)::text, ('ACCOUNTANT'::character varying)::text, ('OPERATOR'::character varying)::text, ('VIEWER'::character varying)::text, ('CA_EXTERNAL'::character varying)::text, ('CA_PARTNER'::character varying)::text, ('CA_STAFF'::character varying)::text, ('PLATFORM_ADMIN'::character varying)::text])))
);


--
-- Name: van; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.van (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    code character varying(30) NOT NULL,
    vehicle_number character varying(30) NOT NULL,
    name character varying(100),
    vehicle_type character varying(30) DEFAULT 'VAN'::character varying NOT NULL,
    source_warehouse_id uuid,
    capacity_weight_kg numeric(10,2),
    capacity_volume_litre numeric(10,2),
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: van_stock_balance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.van_stock_balance (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    van_id uuid NOT NULL,
    item_id uuid NOT NULL,
    batch_id uuid,
    quantity_on_hand numeric(15,4) DEFAULT 0 NOT NULL,
    last_movement_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: van_stock_transfer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.van_stock_transfer (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    van_id uuid NOT NULL,
    warehouse_id uuid NOT NULL,
    transfer_type character varying(20) NOT NULL,
    transfer_date date NOT NULL,
    route_execution_id uuid,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    notes text,
    confirmed_by uuid,
    confirmed_at timestamp with time zone,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: van_stock_transfer_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.van_stock_transfer_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    van_stock_transfer_id uuid NOT NULL,
    item_id uuid NOT NULL,
    batch_id uuid,
    quantity numeric(15,4) NOT NULL,
    unit character varying(20),
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vehicle_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vehicle_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    vehicle_number character varying(30) NOT NULL,
    van_id uuid,
    log_type character varying(20) NOT NULL,
    log_date date NOT NULL,
    odometer_km numeric(12,2),
    quantity numeric(12,3),
    amount numeric(14,2) DEFAULT 0 NOT NULL,
    vendor_contact_id uuid,
    reference_no character varying(60),
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_by uuid,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vendor_credit; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vendor_credit (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    branch_id uuid,
    contact_id uuid NOT NULL,
    credit_number character varying(30) NOT NULL,
    credit_date date NOT NULL,
    purchase_bill_id uuid,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    subtotal numeric(15,2) DEFAULT 0 NOT NULL,
    tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    total_amount numeric(15,2) DEFAULT 0 NOT NULL,
    balance numeric(15,2) DEFAULT 0 NOT NULL,
    currency character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    exchange_rate numeric(12,6) DEFAULT 1.000000 NOT NULL,
    base_subtotal numeric(15,2) DEFAULT 0 NOT NULL,
    base_tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    base_total numeric(15,2) DEFAULT 0 NOT NULL,
    place_of_supply character varying(50),
    reason text NOT NULL,
    journal_entry_id uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT vendor_credit_status_check CHECK (((status)::text = ANY (ARRAY[('DRAFT'::character varying)::text, ('OPEN'::character varying)::text, ('APPLIED'::character varying)::text, ('VOID'::character varying)::text])))
);


--
-- Name: vendor_credit_application; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vendor_credit_application (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    vendor_credit_id uuid NOT NULL,
    purchase_bill_id uuid NOT NULL,
    amount_applied numeric(15,2) NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL,
    applied_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT vendor_credit_application_amount_applied_check CHECK ((amount_applied > (0)::numeric))
);


--
-- Name: vendor_credit_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vendor_credit_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    vendor_credit_id uuid NOT NULL,
    line_number integer NOT NULL,
    description character varying(500) NOT NULL,
    hsn_code character varying(10),
    item_id uuid,
    account_id uuid NOT NULL,
    quantity numeric(12,4) DEFAULT 1 NOT NULL,
    unit_price numeric(15,2) NOT NULL,
    taxable_amount numeric(15,2) NOT NULL,
    gst_rate numeric(5,2) DEFAULT 0 NOT NULL,
    tax_group_id uuid,
    tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    line_total numeric(15,2) NOT NULL,
    base_taxable_amount numeric(15,2) DEFAULT 0 NOT NULL,
    base_tax_amount numeric(15,2) DEFAULT 0 NOT NULL,
    base_line_total numeric(15,2) DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vendor_payment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vendor_payment (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    branch_id uuid,
    contact_id uuid NOT NULL,
    payment_number character varying(30) NOT NULL,
    payment_date date NOT NULL,
    amount numeric(15,2) NOT NULL,
    currency character varying(3) DEFAULT 'INR'::character varying NOT NULL,
    exchange_rate numeric(12,6) DEFAULT 1.000000 NOT NULL,
    base_amount numeric(15,2) NOT NULL,
    payment_mode character varying(30) NOT NULL,
    paid_through_id uuid NOT NULL,
    reference_number character varying(100),
    tds_amount numeric(15,2) DEFAULT 0 NOT NULL,
    tds_section character varying(20),
    notes text,
    journal_entry_id uuid,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT vendor_payment_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT vendor_payment_payment_mode_check CHECK (((payment_mode)::text = ANY (ARRAY[('CASH'::character varying)::text, ('BANK_TRANSFER'::character varying)::text, ('UPI'::character varying)::text, ('CHEQUE'::character varying)::text, ('CARD'::character varying)::text, ('OTHER'::character varying)::text])))
);


--
-- Name: vendor_payment_allocation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vendor_payment_allocation (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    vendor_payment_id uuid NOT NULL,
    purchase_bill_id uuid NOT NULL,
    amount_applied numeric(15,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT vendor_payment_allocation_amount_applied_check CHECK ((amount_applied > (0)::numeric))
);


--
-- Name: visit_detail_aid_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visit_detail_aid_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    field_visit_id uuid NOT NULL,
    detail_aid_id uuid NOT NULL,
    shown_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: visit_product_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visit_product_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    field_visit_id uuid NOT NULL,
    item_id uuid,
    product_name character varying(200) NOT NULL,
    detailed boolean DEFAULT true NOT NULL,
    sample_qty integer DEFAULT 0 NOT NULL,
    gift_name character varying(150),
    gift_qty integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: wallet_transaction; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wallet_transaction (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    wallet_id uuid NOT NULL,
    contact_id uuid NOT NULL,
    txn_type character varying(20) NOT NULL,
    amount numeric(14,2) NOT NULL,
    balance_after numeric(14,2) NOT NULL,
    reference_id uuid,
    reference_type character varying(30),
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: warehouse_zone; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.warehouse_zone (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    warehouse_id uuid NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(200) NOT NULL,
    zone_type character varying(20) DEFAULT 'STORAGE'::character varying NOT NULL,
    capacity numeric(18,4),
    current_utilization numeric(18,4) DEFAULT 0 NOT NULL,
    temperature_controlled boolean DEFAULT false NOT NULL,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: whatsapp_message; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.whatsapp_message (
    id uuid NOT NULL,
    org_id uuid NOT NULL,
    recipient character varying(20) NOT NULL,
    doc_type character varying(20) NOT NULL,
    doc_id uuid,
    template_name character varying(120),
    status character varying(20) NOT NULL,
    provider character varying(20),
    provider_message_id character varying(120),
    error_message text,
    sent_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    is_deleted boolean DEFAULT false NOT NULL
);


--
-- Name: work_order; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.work_order (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    work_order_number character varying(30) NOT NULL,
    finished_good_id uuid NOT NULL,
    warehouse_id uuid NOT NULL,
    quantity_to_produce numeric(15,4) NOT NULL,
    quantity_produced numeric(15,4) DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    planned_start_date date,
    planned_end_date date,
    actual_start_date date,
    actual_end_date date,
    raw_material_cost numeric(15,2) DEFAULT 0 NOT NULL,
    direct_labor_cost numeric(15,2) DEFAULT 0 NOT NULL,
    overhead_cost numeric(15,2) DEFAULT 0 NOT NULL,
    total_cost numeric(15,2) DEFAULT 0 NOT NULL,
    unit_cost numeric(15,4) DEFAULT 0 NOT NULL,
    notes text,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    sales_order_id uuid,
    routing_id uuid,
    priority character varying(10) DEFAULT 'NORMAL'::character varying,
    scrap_qty numeric(15,4) DEFAULT 0,
    scrap_cost numeric(15,2) DEFAULT 0,
    journal_entry_id uuid,
    wip_journal_entry_id uuid,
    backflush_mode boolean DEFAULT false,
    bom_version integer,
    approval_status character varying(20) DEFAULT 'NONE'::character varying,
    approved_by uuid,
    approved_at timestamp with time zone,
    is_disassembly boolean DEFAULT false,
    parent_work_order_id uuid,
    CONSTRAINT work_order_priority_check CHECK (((priority)::text = ANY (ARRAY[('URGENT'::character varying)::text, ('HIGH'::character varying)::text, ('NORMAL'::character varying)::text, ('LOW'::character varying)::text])))
);


--
-- Name: work_order_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.work_order_line (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    created_by uuid,
    work_order_id uuid NOT NULL,
    item_id uuid NOT NULL,
    required_qty numeric(15,4) NOT NULL,
    issued_qty numeric(15,4) DEFAULT 0 NOT NULL,
    unit_cost numeric(15,4) DEFAULT 0 NOT NULL,
    line_cost numeric(15,2) DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    batch_id uuid,
    batch_number character varying(50)
);


--
-- Name: workflow_definition; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workflow_definition (
    id uuid NOT NULL,
    org_id uuid NOT NULL,
    code character varying(80) NOT NULL,
    name character varying(160) NOT NULL,
    document_type character varying(80) NOT NULL,
    trigger_condition jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    is_deleted boolean DEFAULT false NOT NULL
);


--
-- Name: workflow_step; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workflow_step (
    id uuid NOT NULL,
    org_id uuid NOT NULL,
    workflow_definition_id uuid NOT NULL,
    step_number smallint NOT NULL,
    approver_role character varying(40),
    approver_user_id uuid,
    timeout_hours smallint DEFAULT 24 NOT NULL,
    on_timeout character varying(20) DEFAULT 'ESCALATE'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    is_deleted boolean DEFAULT false NOT NULL
);


--
-- Name: workstation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workstation (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    hourly_rate numeric(15,2) DEFAULT 0,
    capacity_hours_per_day numeric(5,2) DEFAULT 8,
    is_active boolean DEFAULT true NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid
);


--
-- Name: workstation_alternate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workstation_alternate (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    routing_operation_id uuid NOT NULL,
    workstation_id uuid NOT NULL,
    priority integer DEFAULT 1 NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid,
    is_deleted boolean DEFAULT false NOT NULL
);


--
-- Name: account account_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_pkey PRIMARY KEY (id);


--
-- Name: ai_model_registry ai_model_registry_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_model_registry
    ADD CONSTRAINT ai_model_registry_pkey PRIMARY KEY (id);


--
-- Name: ai_model_run ai_model_run_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_model_run
    ADD CONSTRAINT ai_model_run_pkey PRIMARY KEY (id);


--
-- Name: ai_pattern ai_pattern_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_pattern
    ADD CONSTRAINT ai_pattern_pkey PRIMARY KEY (id);


--
-- Name: ai_suggestion ai_suggestion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_suggestion
    ADD CONSTRAINT ai_suggestion_pkey PRIMARY KEY (id);


--
-- Name: ai_training_example ai_training_example_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_training_example
    ADD CONSTRAINT ai_training_example_pkey PRIMARY KEY (id);


--
-- Name: ai_usage_log ai_usage_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_usage_log
    ADD CONSTRAINT ai_usage_log_pkey PRIMARY KEY (id);


--
-- Name: amortization_entry amortization_entry_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.amortization_entry
    ADD CONSTRAINT amortization_entry_pkey PRIMARY KEY (id);


--
-- Name: amortization_schedule amortization_schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.amortization_schedule
    ADD CONSTRAINT amortization_schedule_pkey PRIMARY KEY (id);


--
-- Name: api_key api_key_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_key
    ADD CONSTRAINT api_key_pkey PRIMARY KEY (id);


--
-- Name: app_user app_user_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_pkey PRIMARY KEY (id);


--
-- Name: approval_decision approval_decision_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_decision
    ADD CONSTRAINT approval_decision_pkey PRIMARY KEY (id);


--
-- Name: approval_request approval_request_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_request
    ADD CONSTRAINT approval_request_pkey PRIMARY KEY (id);


--
-- Name: attendance_regularization attendance_regularization_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_regularization
    ADD CONSTRAINT attendance_regularization_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: bank_transaction bank_transaction_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bank_transaction
    ADD CONSTRAINT bank_transaction_pkey PRIMARY KEY (id);


--
-- Name: batch_trace batch_trace_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.batch_trace
    ADD CONSTRAINT batch_trace_pkey PRIMARY KEY (id);


--
-- Name: beat_customer beat_customer_org_id_beat_id_contact_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.beat_customer
    ADD CONSTRAINT beat_customer_org_id_beat_id_contact_id_key UNIQUE (org_id, beat_id, contact_id);


--
-- Name: beat_customer beat_customer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.beat_customer
    ADD CONSTRAINT beat_customer_pkey PRIMARY KEY (id);


--
-- Name: beat beat_org_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.beat
    ADD CONSTRAINT beat_org_id_code_key UNIQUE (org_id, code);


--
-- Name: beat beat_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.beat
    ADD CONSTRAINT beat_pkey PRIMARY KEY (id);


--
-- Name: bmr_deviation bmr_deviation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bmr_deviation
    ADD CONSTRAINT bmr_deviation_pkey PRIMARY KEY (id);


--
-- Name: bmr_signoff bmr_signoff_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bmr_signoff
    ADD CONSTRAINT bmr_signoff_pkey PRIMARY KEY (id);


--
-- Name: bmr_step_record bmr_step_record_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bmr_step_record
    ADD CONSTRAINT bmr_step_record_pkey PRIMARY KEY (id);


--
-- Name: bom_alternate bom_alternate_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bom_alternate
    ADD CONSTRAINT bom_alternate_pkey PRIMARY KEY (id);


--
-- Name: bom_co_product bom_co_product_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bom_co_product
    ADD CONSTRAINT bom_co_product_pkey PRIMARY KEY (id);


--
-- Name: bom_component bom_component_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bom_component
    ADD CONSTRAINT bom_component_pkey PRIMARY KEY (id);


--
-- Name: branch branch_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch
    ADD CONSTRAINT branch_pkey PRIMARY KEY (id);


--
-- Name: budget_line budget_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget_line
    ADD CONSTRAINT budget_line_pkey PRIMARY KEY (id);


--
-- Name: ca_alert_dismissal ca_alert_dismissal_ca_firm_id_suggestion_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_alert_dismissal
    ADD CONSTRAINT ca_alert_dismissal_ca_firm_id_suggestion_id_key UNIQUE (ca_firm_id, suggestion_id);


--
-- Name: ca_alert_dismissal ca_alert_dismissal_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_alert_dismissal
    ADD CONSTRAINT ca_alert_dismissal_pkey PRIMARY KEY (id);


--
-- Name: ca_client_link ca_client_link_ca_firm_id_client_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_client_link
    ADD CONSTRAINT ca_client_link_ca_firm_id_client_org_id_key UNIQUE (ca_firm_id, client_org_id);


--
-- Name: ca_client_link ca_client_link_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_client_link
    ADD CONSTRAINT ca_client_link_pkey PRIMARY KEY (id);


--
-- Name: ca_compliance_deadline ca_compliance_deadline_ca_client_link_id_deadline_type_peri_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_compliance_deadline
    ADD CONSTRAINT ca_compliance_deadline_ca_client_link_id_deadline_type_peri_key UNIQUE (ca_client_link_id, deadline_type, period_label);


--
-- Name: ca_compliance_deadline ca_compliance_deadline_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_compliance_deadline
    ADD CONSTRAINT ca_compliance_deadline_pkey PRIMARY KEY (id);


--
-- Name: ca_firm ca_firm_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_firm
    ADD CONSTRAINT ca_firm_org_id_key UNIQUE (org_id);


--
-- Name: ca_firm ca_firm_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_firm
    ADD CONSTRAINT ca_firm_pkey PRIMARY KEY (id);


--
-- Name: ca_report_dispatch ca_report_dispatch_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_report_dispatch
    ADD CONSTRAINT ca_report_dispatch_pkey PRIMARY KEY (id);


--
-- Name: capa_action capa_action_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capa_action
    ADD CONSTRAINT capa_action_pkey PRIMARY KEY (id);


--
-- Name: coa_template coa_template_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coa_template
    ADD CONSTRAINT coa_template_pkey PRIMARY KEY (id);


--
-- Name: cod_remittance_line cod_remittance_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cod_remittance_line
    ADD CONSTRAINT cod_remittance_line_pkey PRIMARY KEY (id);


--
-- Name: cod_remittance cod_remittance_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cod_remittance
    ADD CONSTRAINT cod_remittance_pkey PRIMARY KEY (id);


--
-- Name: consignment_settlement consignment_settlement_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consignment_settlement
    ADD CONSTRAINT consignment_settlement_pkey PRIMARY KEY (id);


--
-- Name: consignment_stock consignment_stock_org_id_item_id_warehouse_id_supplier_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consignment_stock
    ADD CONSTRAINT consignment_stock_org_id_item_id_warehouse_id_supplier_id_key UNIQUE (org_id, item_id, warehouse_id, supplier_id);


--
-- Name: consignment_stock consignment_stock_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consignment_stock
    ADD CONSTRAINT consignment_stock_pkey PRIMARY KEY (id);


--
-- Name: contact_person contact_person_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_person
    ADD CONSTRAINT contact_person_pkey PRIMARY KEY (id);


--
-- Name: contact contact_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact
    ADD CONSTRAINT contact_pkey PRIMARY KEY (id);


--
-- Name: cost_lot_consumption cost_lot_consumption_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_lot_consumption
    ADD CONSTRAINT cost_lot_consumption_pkey PRIMARY KEY (id);


--
-- Name: cost_lot cost_lot_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_lot
    ADD CONSTRAINT cost_lot_pkey PRIMARY KEY (id);


--
-- Name: courier_shipment_event courier_shipment_event_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courier_shipment_event
    ADD CONSTRAINT courier_shipment_event_pkey PRIMARY KEY (id);


--
-- Name: courier_shipment courier_shipment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courier_shipment
    ADD CONSTRAINT courier_shipment_pkey PRIMARY KEY (id);


--
-- Name: credit_note_line credit_note_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_note_line
    ADD CONSTRAINT credit_note_line_pkey PRIMARY KEY (id);


--
-- Name: credit_note credit_note_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_note
    ADD CONSTRAINT credit_note_pkey PRIMARY KEY (id);


--
-- Name: currency currency_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.currency
    ADD CONSTRAINT currency_code_key UNIQUE (code);


--
-- Name: currency currency_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.currency
    ADD CONSTRAINT currency_pkey PRIMARY KEY (id);


--
-- Name: customer_wallet customer_wallet_org_id_contact_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_wallet
    ADD CONSTRAINT customer_wallet_org_id_contact_id_key UNIQUE (org_id, contact_id);


--
-- Name: customer_wallet customer_wallet_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_wallet
    ADD CONSTRAINT customer_wallet_pkey PRIMARY KEY (id);


--
-- Name: day_close day_close_org_id_route_execution_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.day_close
    ADD CONSTRAINT day_close_org_id_route_execution_id_key UNIQUE (org_id, route_execution_id);


--
-- Name: day_close day_close_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.day_close
    ADD CONSTRAINT day_close_pkey PRIMARY KEY (id);


--
-- Name: dcr_report dcr_report_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dcr_report
    ADD CONSTRAINT dcr_report_pkey PRIMARY KEY (id);


--
-- Name: debit_note_line debit_note_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debit_note_line
    ADD CONSTRAINT debit_note_line_pkey PRIMARY KEY (id);


--
-- Name: debit_note debit_note_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debit_note
    ADD CONSTRAINT debit_note_pkey PRIMARY KEY (id);


--
-- Name: delegated_access_token delegated_access_token_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delegated_access_token
    ADD CONSTRAINT delegated_access_token_pkey PRIMARY KEY (id);


--
-- Name: delegated_access_token delegated_access_token_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delegated_access_token
    ADD CONSTRAINT delegated_access_token_token_hash_key UNIQUE (token_hash);


--
-- Name: delivery_challan_line delivery_challan_line_delivery_challan_id_line_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_challan_line
    ADD CONSTRAINT delivery_challan_line_delivery_challan_id_line_number_key UNIQUE (delivery_challan_id, line_number);


--
-- Name: delivery_challan_line delivery_challan_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_challan_line
    ADD CONSTRAINT delivery_challan_line_pkey PRIMARY KEY (id);


--
-- Name: delivery_challan delivery_challan_org_id_challan_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_challan
    ADD CONSTRAINT delivery_challan_org_id_challan_number_key UNIQUE (org_id, challan_number);


--
-- Name: delivery_challan delivery_challan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_challan
    ADD CONSTRAINT delivery_challan_pkey PRIMARY KEY (id);


--
-- Name: demand_forecast demand_forecast_org_id_item_id_warehouse_id_forecast_month_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.demand_forecast
    ADD CONSTRAINT demand_forecast_org_id_item_id_warehouse_id_forecast_month_key UNIQUE (org_id, item_id, warehouse_id, forecast_month);


--
-- Name: demand_forecast demand_forecast_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.demand_forecast
    ADD CONSTRAINT demand_forecast_pkey PRIMARY KEY (id);


--
-- Name: detail_aid detail_aid_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.detail_aid
    ADD CONSTRAINT detail_aid_pkey PRIMARY KEY (id);


--
-- Name: document_state_config document_state_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_state_config
    ADD CONSTRAINT document_state_config_pkey PRIMARY KEY (id);


--
-- Name: domain_event domain_event_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_event
    ADD CONSTRAINT domain_event_pkey PRIMARY KEY (id);


--
-- Name: domain_events domain_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_events
    ADD CONSTRAINT domain_events_pkey PRIMARY KEY (id);


--
-- Name: drug_interaction drug_interaction_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drug_interaction
    ADD CONSTRAINT drug_interaction_pkey PRIMARY KEY (id);


--
-- Name: drug_licenses drug_licenses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drug_licenses
    ADD CONSTRAINT drug_licenses_pkey PRIMARY KEY (id);


--
-- Name: drug_master drug_master_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drug_master
    ADD CONSTRAINT drug_master_pkey PRIMARY KEY (id);


--
-- Name: einvoice einvoice_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.einvoice
    ADD CONSTRAINT einvoice_pkey PRIMARY KEY (id);


--
-- Name: email_template email_template_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_template
    ADD CONSTRAINT email_template_pkey PRIMARY KEY (id);


--
-- Name: email_verification_token email_verification_token_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_verification_token
    ADD CONSTRAINT email_verification_token_pkey PRIMARY KEY (id);


--
-- Name: employee employee_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee
    ADD CONSTRAINT employee_pkey PRIMARY KEY (id);


--
-- Name: employee_salary_component employee_salary_component_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_salary_component
    ADD CONSTRAINT employee_salary_component_pkey PRIMARY KEY (id);


--
-- Name: employee_salary_structure employee_salary_structure_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_salary_structure
    ADD CONSTRAINT employee_salary_structure_pkey PRIMARY KEY (id);


--
-- Name: entity_attachment entity_attachment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_attachment
    ADD CONSTRAINT entity_attachment_pkey PRIMARY KEY (id);


--
-- Name: entity_comment entity_comment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_comment
    ADD CONSTRAINT entity_comment_pkey PRIMARY KEY (id);


--
-- Name: entry_number_sequence entry_number_sequence_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entry_number_sequence
    ADD CONSTRAINT entry_number_sequence_pkey PRIMARY KEY (org_id, year);


--
-- Name: estimate_line estimate_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estimate_line
    ADD CONSTRAINT estimate_line_pkey PRIMARY KEY (id);


--
-- Name: estimate estimate_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estimate
    ADD CONSTRAINT estimate_pkey PRIMARY KEY (id);


--
-- Name: eway_bill eway_bill_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.eway_bill
    ADD CONSTRAINT eway_bill_pkey PRIMARY KEY (id);


--
-- Name: exchange_rate exchange_rate_org_id_from_currency_to_currency_effective_da_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exchange_rate
    ADD CONSTRAINT exchange_rate_org_id_from_currency_to_currency_effective_da_key UNIQUE (org_id, from_currency, to_currency, effective_date);


--
-- Name: exchange_rate exchange_rate_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exchange_rate
    ADD CONSTRAINT exchange_rate_pkey PRIMARY KEY (id);


--
-- Name: expense expense_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense
    ADD CONSTRAINT expense_pkey PRIMARY KEY (id);


--
-- Name: field_allowance_claim field_allowance_claim_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.field_allowance_claim
    ADD CONSTRAINT field_allowance_claim_pkey PRIMARY KEY (id);


--
-- Name: field_attendance field_attendance_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.field_attendance
    ADD CONSTRAINT field_attendance_pkey PRIMARY KEY (id);


--
-- Name: field_location_ping field_location_ping_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.field_location_ping
    ADD CONSTRAINT field_location_ping_pkey PRIMARY KEY (id);


--
-- Name: field_sales_assignment field_sales_assignment_org_id_salesperson_id_route_id_effec_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.field_sales_assignment
    ADD CONSTRAINT field_sales_assignment_org_id_salesperson_id_route_id_effec_key UNIQUE (org_id, salesperson_id, route_id, effective_from);


--
-- Name: field_sales_assignment field_sales_assignment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.field_sales_assignment
    ADD CONSTRAINT field_sales_assignment_pkey PRIMARY KEY (id);


--
-- Name: field_sample_txn field_sample_txn_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.field_sample_txn
    ADD CONSTRAINT field_sample_txn_pkey PRIMARY KEY (id);


--
-- Name: field_sync_entry field_sync_entry_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.field_sync_entry
    ADD CONSTRAINT field_sync_entry_pkey PRIMARY KEY (id);


--
-- Name: field_visit field_visit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.field_visit
    ADD CONSTRAINT field_visit_pkey PRIMARY KEY (id);


--
-- Name: fiscal_period fiscal_period_org_id_period_year_period_month_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fiscal_period
    ADD CONSTRAINT fiscal_period_org_id_period_year_period_month_key UNIQUE (org_id, period_year, period_month);


--
-- Name: fiscal_period fiscal_period_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fiscal_period
    ADD CONSTRAINT fiscal_period_pkey PRIMARY KEY (id);


--
-- Name: fixed_asset_depreciation fixed_asset_depreciation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fixed_asset_depreciation
    ADD CONSTRAINT fixed_asset_depreciation_pkey PRIMARY KEY (id);


--
-- Name: fixed_asset fixed_asset_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fixed_asset
    ADD CONSTRAINT fixed_asset_pkey PRIMARY KEY (id);


--
-- Name: freight_rate_card freight_rate_card_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.freight_rate_card
    ADD CONSTRAINT freight_rate_card_pkey PRIMARY KEY (id);


--
-- Name: generic_substitution generic_substitution_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generic_substitution
    ADD CONSTRAINT generic_substitution_pkey PRIMARY KEY (id);


--
-- Name: gst_filing_snapshot gst_filing_snapshot_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gst_filing_snapshot
    ADD CONSTRAINT gst_filing_snapshot_pkey PRIMARY KEY (id);


--
-- Name: gst_state_code gst_state_code_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gst_state_code
    ADD CONSTRAINT gst_state_code_code_key UNIQUE (code);


--
-- Name: gst_state_code gst_state_code_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gst_state_code
    ADD CONSTRAINT gst_state_code_pkey PRIMARY KEY (id);


--
-- Name: gstr2b_entry gstr2b_entry_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gstr2b_entry
    ADD CONSTRAINT gstr2b_entry_pkey PRIMARY KEY (id);


--
-- Name: hr_employee_document hr_employee_document_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_document
    ADD CONSTRAINT hr_employee_document_pkey PRIMARY KEY (id);


--
-- Name: hr_employee_education hr_employee_education_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_education
    ADD CONSTRAINT hr_employee_education_pkey PRIMARY KEY (id);


--
-- Name: hr_employee_experience hr_employee_experience_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_experience
    ADD CONSTRAINT hr_employee_experience_pkey PRIMARY KEY (id);


--
-- Name: hr_employee_family hr_employee_family_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_family
    ADD CONSTRAINT hr_employee_family_pkey PRIMARY KEY (id);


--
-- Name: hr_employee_profile hr_employee_profile_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_employee_profile
    ADD CONSTRAINT hr_employee_profile_pkey PRIMARY KEY (id);


--
-- Name: hr_holiday hr_holiday_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_holiday
    ADD CONSTRAINT hr_holiday_pkey PRIMARY KEY (id);


--
-- Name: hr_leave_balance hr_leave_balance_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_leave_balance
    ADD CONSTRAINT hr_leave_balance_pkey PRIMARY KEY (id);


--
-- Name: hr_leave_type hr_leave_type_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_leave_type
    ADD CONSTRAINT hr_leave_type_pkey PRIMARY KEY (id);


--
-- Name: hr_offboarding hr_offboarding_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_offboarding
    ADD CONSTRAINT hr_offboarding_pkey PRIMARY KEY (id);


--
-- Name: hr_offboarding_task hr_offboarding_task_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_offboarding_task
    ADD CONSTRAINT hr_offboarding_task_pkey PRIMARY KEY (id);


--
-- Name: hr_shift_assignment hr_shift_assignment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_shift_assignment
    ADD CONSTRAINT hr_shift_assignment_pkey PRIMARY KEY (id);


--
-- Name: hr_shift hr_shift_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_shift
    ADD CONSTRAINT hr_shift_pkey PRIMARY KEY (id);


--
-- Name: hr_ticket_comment hr_ticket_comment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_ticket_comment
    ADD CONSTRAINT hr_ticket_comment_pkey PRIMARY KEY (id);


--
-- Name: hr_ticket hr_ticket_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_ticket
    ADD CONSTRAINT hr_ticket_pkey PRIMARY KEY (id);


--
-- Name: hr_timesheet_entry hr_timesheet_entry_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hr_timesheet_entry
    ADD CONSTRAINT hr_timesheet_entry_pkey PRIMARY KEY (id);


--
-- Name: hsn_gst_master hsn_gst_master_hsn_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hsn_gst_master
    ADD CONSTRAINT hsn_gst_master_hsn_code_key UNIQUE (hsn_code);


--
-- Name: hsn_gst_master hsn_gst_master_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hsn_gst_master
    ADD CONSTRAINT hsn_gst_master_pkey PRIMARY KEY (id);


--
-- Name: idempotency_record idempotency_record_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.idempotency_record
    ADD CONSTRAINT idempotency_record_pkey PRIMARY KEY (id);


--
-- Name: industry_feature_config industry_feature_config_industry_template_id_sub_category_c_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.industry_feature_config
    ADD CONSTRAINT industry_feature_config_industry_template_id_sub_category_c_key UNIQUE (industry_template_id, sub_category_code);


--
-- Name: industry_feature_config industry_feature_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.industry_feature_config
    ADD CONSTRAINT industry_feature_config_pkey PRIMARY KEY (id);


--
-- Name: industry_sub_category industry_sub_category_industry_template_id_sub_category_cod_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.industry_sub_category
    ADD CONSTRAINT industry_sub_category_industry_template_id_sub_category_cod_key UNIQUE (industry_template_id, sub_category_code);


--
-- Name: industry_sub_category industry_sub_category_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.industry_sub_category
    ADD CONSTRAINT industry_sub_category_pkey PRIMARY KEY (id);


--
-- Name: industry_template industry_template_industry_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.industry_template
    ADD CONSTRAINT industry_template_industry_code_key UNIQUE (industry_code);


--
-- Name: industry_template industry_template_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.industry_template
    ADD CONSTRAINT industry_template_pkey PRIMARY KEY (id);


--
-- Name: integration_config integration_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_config
    ADD CONSTRAINT integration_config_pkey PRIMARY KEY (id);


--
-- Name: integration_sync_log integration_sync_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_sync_log
    ADD CONSTRAINT integration_sync_log_pkey PRIMARY KEY (id);


--
-- Name: invoice_line invoice_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_line
    ADD CONSTRAINT invoice_line_pkey PRIMARY KEY (id);


--
-- Name: invoice_number_sequence invoice_number_sequence_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_number_sequence
    ADD CONSTRAINT invoice_number_sequence_pkey PRIMARY KEY (org_id, prefix, year);


--
-- Name: invoice invoice_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice
    ADD CONSTRAINT invoice_pkey PRIMARY KEY (id);


--
-- Name: item_group item_group_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_group
    ADD CONSTRAINT item_group_pkey PRIMARY KEY (id);


--
-- Name: item item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item
    ADD CONSTRAINT item_pkey PRIMARY KEY (id);


--
-- Name: item_supplier item_supplier_org_id_item_id_supplier_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_supplier
    ADD CONSTRAINT item_supplier_org_id_item_id_supplier_id_key UNIQUE (org_id, item_id, supplier_id);


--
-- Name: item_supplier item_supplier_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_supplier
    ADD CONSTRAINT item_supplier_pkey PRIMARY KEY (id);


--
-- Name: item_unit_price item_unit_price_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_unit_price
    ADD CONSTRAINT item_unit_price_pkey PRIMARY KEY (id);


--
-- Name: item_unit_price item_unit_price_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_unit_price
    ADD CONSTRAINT item_unit_price_unique UNIQUE (org_id, item_id, uom_id);


--
-- Name: job_card job_card_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_card
    ADD CONSTRAINT job_card_pkey PRIMARY KEY (id);


--
-- Name: job_work_order_line job_work_order_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_work_order_line
    ADD CONSTRAINT job_work_order_line_pkey PRIMARY KEY (id);


--
-- Name: job_work_order job_work_order_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_work_order
    ADD CONSTRAINT job_work_order_pkey PRIMARY KEY (id);


--
-- Name: journal_entry journal_entry_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry
    ADD CONSTRAINT journal_entry_pkey PRIMARY KEY (id);


--
-- Name: journal_line journal_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_line
    ADD CONSTRAINT journal_line_pkey PRIMARY KEY (id);


--
-- Name: leave_request leave_request_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leave_request
    ADD CONSTRAINT leave_request_pkey PRIMARY KEY (id);


--
-- Name: lorry_receipt lorry_receipt_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lorry_receipt
    ADD CONSTRAINT lorry_receipt_pkey PRIMARY KEY (id);


--
-- Name: maintenance_schedule maintenance_schedule_code_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_schedule
    ADD CONSTRAINT maintenance_schedule_code_uniq UNIQUE (org_id, code);


--
-- Name: maintenance_schedule maintenance_schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_schedule
    ADD CONSTRAINT maintenance_schedule_pkey PRIMARY KEY (id);


--
-- Name: maintenance_work_order maintenance_work_order_number_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_work_order
    ADD CONSTRAINT maintenance_work_order_number_uniq UNIQUE (org_id, mwo_number);


--
-- Name: maintenance_work_order maintenance_work_order_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.maintenance_work_order
    ADD CONSTRAINT maintenance_work_order_pkey PRIMARY KEY (id);


--
-- Name: manufacturer_master manufacturer_master_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manufacturer_master
    ADD CONSTRAINT manufacturer_master_name_key UNIQUE (name);


--
-- Name: manufacturer_master manufacturer_master_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manufacturer_master
    ADD CONSTRAINT manufacturer_master_pkey PRIMARY KEY (id);


--
-- Name: mrp_demand mrp_demand_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mrp_demand
    ADD CONSTRAINT mrp_demand_pkey PRIMARY KEY (id);


--
-- Name: mrp_run mrp_run_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mrp_run
    ADD CONSTRAINT mrp_run_pkey PRIMARY KEY (id);


--
-- Name: mrp_supply mrp_supply_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mrp_supply
    ADD CONSTRAINT mrp_supply_pkey PRIMARY KEY (id);


--
-- Name: network_order_event network_order_event_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.network_order_event
    ADD CONSTRAINT network_order_event_pkey PRIMARY KEY (id);


--
-- Name: network_order_line network_order_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.network_order_line
    ADD CONSTRAINT network_order_line_pkey PRIMARY KEY (id);


--
-- Name: network_order network_order_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.network_order
    ADD CONSTRAINT network_order_pkey PRIMARY KEY (id);


--
-- Name: non_conformance_report non_conformance_report_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.non_conformance_report
    ADD CONSTRAINT non_conformance_report_pkey PRIMARY KEY (id);


--
-- Name: notification notification_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT notification_pkey PRIMARY KEY (id);


--
-- Name: operation operation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operation
    ADD CONSTRAINT operation_pkey PRIMARY KEY (id);


--
-- Name: org_ai_settings org_ai_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_ai_settings
    ADD CONSTRAINT org_ai_settings_pkey PRIMARY KEY (org_id);


--
-- Name: org_bootstrap_status org_bootstrap_status_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_bootstrap_status
    ADD CONSTRAINT org_bootstrap_status_pkey PRIMARY KEY (org_id);


--
-- Name: org_default_account org_default_account_org_id_purpose_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_default_account
    ADD CONSTRAINT org_default_account_org_id_purpose_key UNIQUE (org_id, purpose);


--
-- Name: org_default_account org_default_account_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_default_account
    ADD CONSTRAINT org_default_account_pkey PRIMARY KEY (id);


--
-- Name: org_feature_flag org_feature_flag_org_id_feature_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_feature_flag
    ADD CONSTRAINT org_feature_flag_org_id_feature_key UNIQUE (org_id, feature);


--
-- Name: org_feature_flag org_feature_flag_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_feature_flag
    ADD CONSTRAINT org_feature_flag_pkey PRIMARY KEY (id);


--
-- Name: org_settings org_settings_org_id_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_settings
    ADD CONSTRAINT org_settings_org_id_key_key UNIQUE (org_id, key);


--
-- Name: org_settings org_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_settings
    ADD CONSTRAINT org_settings_pkey PRIMARY KEY (id);


--
-- Name: organisation organisation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organisation
    ADD CONSTRAINT organisation_pkey PRIMARY KEY (id);


--
-- Name: password_reset_token password_reset_token_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_token
    ADD CONSTRAINT password_reset_token_pkey PRIMARY KEY (id);


--
-- Name: payment_match payment_match_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_match
    ADD CONSTRAINT payment_match_pkey PRIMARY KEY (id);


--
-- Name: payment payment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_pkey PRIMARY KEY (id);


--
-- Name: payroll_audit_log payroll_audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payroll_audit_log
    ADD CONSTRAINT payroll_audit_log_pkey PRIMARY KEY (id);


--
-- Name: payroll_document_snapshot payroll_document_snapshot_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payroll_document_snapshot
    ADD CONSTRAINT payroll_document_snapshot_pkey PRIMARY KEY (id);


--
-- Name: payroll_payment payroll_payment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payroll_payment
    ADD CONSTRAINT payroll_payment_pkey PRIMARY KEY (id);


--
-- Name: payroll_run payroll_run_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payroll_run
    ADD CONSTRAINT payroll_run_pkey PRIMARY KEY (id);


--
-- Name: payroll_settings payroll_settings_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payroll_settings
    ADD CONSTRAINT payroll_settings_org_id_key UNIQUE (org_id);


--
-- Name: payroll_settings payroll_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payroll_settings
    ADD CONSTRAINT payroll_settings_pkey PRIMARY KEY (id);


--
-- Name: payslip_line payslip_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payslip_line
    ADD CONSTRAINT payslip_line_pkey PRIMARY KEY (id);


--
-- Name: payslip payslip_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payslip
    ADD CONSTRAINT payslip_pkey PRIMARY KEY (id);


--
-- Name: period_balance period_balance_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.period_balance
    ADD CONSTRAINT period_balance_pkey PRIMARY KEY (id);


--
-- Name: picklist_line picklist_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.picklist_line
    ADD CONSTRAINT picklist_line_pkey PRIMARY KEY (id);


--
-- Name: picklist picklist_org_id_picklist_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.picklist
    ADD CONSTRAINT picklist_org_id_picklist_number_key UNIQUE (org_id, picklist_number);


--
-- Name: picklist picklist_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.picklist
    ADD CONSTRAINT picklist_pkey PRIMARY KEY (id);


--
-- Name: planned_order planned_order_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planned_order
    ADD CONSTRAINT planned_order_pkey PRIMARY KEY (id);


--
-- Name: platform_admin_audit platform_admin_audit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_admin_audit
    ADD CONSTRAINT platform_admin_audit_pkey PRIMARY KEY (id);


--
-- Name: platform_admin platform_admin_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_admin
    ADD CONSTRAINT platform_admin_email_key UNIQUE (email);


--
-- Name: platform_admin platform_admin_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_admin
    ADD CONSTRAINT platform_admin_pkey PRIMARY KEY (id);


--
-- Name: portal_user portal_user_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.portal_user
    ADD CONSTRAINT portal_user_pkey PRIMARY KEY (id);


--
-- Name: pos_cash_expense pos_cash_expense_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pos_cash_expense
    ADD CONSTRAINT pos_cash_expense_pkey PRIMARY KEY (id);


--
-- Name: pos_cash_register pos_cash_register_org_id_register_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pos_cash_register
    ADD CONSTRAINT pos_cash_register_org_id_register_date_key UNIQUE (org_id, register_date);


--
-- Name: pos_cash_register pos_cash_register_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pos_cash_register
    ADD CONSTRAINT pos_cash_register_pkey PRIMARY KEY (id);


--
-- Name: posted_document_snapshot posted_document_snapshot_document_type_document_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posted_document_snapshot
    ADD CONSTRAINT posted_document_snapshot_document_type_document_id_key UNIQUE (document_type, document_id);


--
-- Name: posted_document_snapshot posted_document_snapshot_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posted_document_snapshot
    ADD CONSTRAINT posted_document_snapshot_pkey PRIMARY KEY (id);


--
-- Name: prescription_record_item prescription_record_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prescription_record_item
    ADD CONSTRAINT prescription_record_item_pkey PRIMARY KEY (id);


--
-- Name: prescription_record prescription_record_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prescription_record
    ADD CONSTRAINT prescription_record_pkey PRIMARY KEY (id);


--
-- Name: price_list_item price_list_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list_item
    ADD CONSTRAINT price_list_item_pkey PRIMARY KEY (id);


--
-- Name: price_list price_list_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list
    ADD CONSTRAINT price_list_pkey PRIMARY KEY (id);


--
-- Name: production_cost_summary production_cost_summary_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_cost_summary
    ADD CONSTRAINT production_cost_summary_pkey PRIMARY KEY (id);


--
-- Name: production_scrap production_scrap_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_scrap
    ADD CONSTRAINT production_scrap_pkey PRIMARY KEY (id);


--
-- Name: proof_of_delivery proof_of_delivery_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.proof_of_delivery
    ADD CONSTRAINT proof_of_delivery_pkey PRIMARY KEY (id);


--
-- Name: published_catalog_item published_catalog_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.published_catalog_item
    ADD CONSTRAINT published_catalog_item_pkey PRIMARY KEY (id);


--
-- Name: purchase_bill_line purchase_bill_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_bill_line
    ADD CONSTRAINT purchase_bill_line_pkey PRIMARY KEY (id);


--
-- Name: purchase_bill purchase_bill_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_bill
    ADD CONSTRAINT purchase_bill_pkey PRIMARY KEY (id);


--
-- Name: purchase_order_lines purchase_order_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_order_lines
    ADD CONSTRAINT purchase_order_lines_pkey PRIMARY KEY (id);


--
-- Name: purchase_orders purchase_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_orders
    ADD CONSTRAINT purchase_orders_pkey PRIMARY KEY (id);


--
-- Name: purchase_requisition_line purchase_requisition_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_requisition_line
    ADD CONSTRAINT purchase_requisition_line_pkey PRIMARY KEY (id);


--
-- Name: purchase_requisition purchase_requisition_org_id_requisition_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_requisition
    ADD CONSTRAINT purchase_requisition_org_id_requisition_number_key UNIQUE (org_id, requisition_number);


--
-- Name: purchase_requisition purchase_requisition_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_requisition
    ADD CONSTRAINT purchase_requisition_pkey PRIMARY KEY (id);


--
-- Name: push_token push_token_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_token
    ADD CONSTRAINT push_token_pkey PRIMARY KEY (id);


--
-- Name: qc_inspection qc_inspection_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qc_inspection
    ADD CONSTRAINT qc_inspection_pkey PRIMARY KEY (id);


--
-- Name: qc_inspection_result qc_inspection_result_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qc_inspection_result
    ADD CONSTRAINT qc_inspection_result_pkey PRIMARY KEY (id);


--
-- Name: qc_parameter qc_parameter_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qc_parameter
    ADD CONSTRAINT qc_parameter_pkey PRIMARY KEY (id);


--
-- Name: qc_template qc_template_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qc_template
    ADD CONSTRAINT qc_template_pkey PRIMARY KEY (id);


--
-- Name: rack_location rack_location_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rack_location
    ADD CONSTRAINT rack_location_pkey PRIMARY KEY (id);


--
-- Name: rcpa_audit rcpa_audit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rcpa_audit
    ADD CONSTRAINT rcpa_audit_pkey PRIMARY KEY (id);


--
-- Name: rcpa_line rcpa_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rcpa_line
    ADD CONSTRAINT rcpa_line_pkey PRIMARY KEY (id);


--
-- Name: recurring_invoice_generation recurring_invoice_generation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_invoice_generation
    ADD CONSTRAINT recurring_invoice_generation_pkey PRIMARY KEY (id);


--
-- Name: recurring_invoice recurring_invoice_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_invoice
    ADD CONSTRAINT recurring_invoice_pkey PRIMARY KEY (id);


--
-- Name: refresh_token refresh_token_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_token
    ADD CONSTRAINT refresh_token_pkey PRIMARY KEY (id);


--
-- Name: refresh_token refresh_token_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_token
    ADD CONSTRAINT refresh_token_token_hash_key UNIQUE (token_hash);


--
-- Name: reminder_log reminder_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reminder_log
    ADD CONSTRAINT reminder_log_pkey PRIMARY KEY (id);


--
-- Name: reorder_policy reorder_policy_org_id_item_id_warehouse_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reorder_policy
    ADD CONSTRAINT reorder_policy_org_id_item_id_warehouse_id_key UNIQUE (org_id, item_id, warehouse_id);


--
-- Name: reorder_policy reorder_policy_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reorder_policy
    ADD CONSTRAINT reorder_policy_pkey PRIMARY KEY (id);


--
-- Name: return_order_line return_order_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.return_order_line
    ADD CONSTRAINT return_order_line_pkey PRIMARY KEY (id);


--
-- Name: return_order return_order_org_id_return_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.return_order
    ADD CONSTRAINT return_order_org_id_return_number_key UNIQUE (org_id, return_number);


--
-- Name: return_order return_order_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.return_order
    ADD CONSTRAINT return_order_pkey PRIMARY KEY (id);


--
-- Name: route_beat route_beat_org_id_route_id_beat_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.route_beat
    ADD CONSTRAINT route_beat_org_id_route_id_beat_id_key UNIQUE (org_id, route_id, beat_id);


--
-- Name: route_beat route_beat_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.route_beat
    ADD CONSTRAINT route_beat_pkey PRIMARY KEY (id);


--
-- Name: route_execution route_execution_org_id_route_id_salesperson_id_execution_da_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.route_execution
    ADD CONSTRAINT route_execution_org_id_route_id_salesperson_id_execution_da_key UNIQUE (org_id, route_id, salesperson_id, execution_date);


--
-- Name: route_execution route_execution_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.route_execution
    ADD CONSTRAINT route_execution_pkey PRIMARY KEY (id);


--
-- Name: route route_org_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.route
    ADD CONSTRAINT route_org_id_code_key UNIQUE (org_id, code);


--
-- Name: route route_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.route
    ADD CONSTRAINT route_pkey PRIMARY KEY (id);


--
-- Name: routing_operation_dependency routing_operation_dependency_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routing_operation_dependency
    ADD CONSTRAINT routing_operation_dependency_pkey PRIMARY KEY (id);


--
-- Name: routing_operation routing_operation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routing_operation
    ADD CONSTRAINT routing_operation_pkey PRIMARY KEY (id);


--
-- Name: routing routing_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routing
    ADD CONSTRAINT routing_pkey PRIMARY KEY (id);


--
-- Name: salary_component salary_component_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.salary_component
    ADD CONSTRAINT salary_component_pkey PRIMARY KEY (id);


--
-- Name: sales_order_line sales_order_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_order_line
    ADD CONSTRAINT sales_order_line_pkey PRIMARY KEY (id);


--
-- Name: sales_order_line sales_order_line_sales_order_id_line_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_order_line
    ADD CONSTRAINT sales_order_line_sales_order_id_line_number_key UNIQUE (sales_order_id, line_number);


--
-- Name: sales_order sales_order_org_id_salesorder_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_order
    ADD CONSTRAINT sales_order_org_id_salesorder_number_key UNIQUE (org_id, salesorder_number);


--
-- Name: sales_order sales_order_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_order
    ADD CONSTRAINT sales_order_pkey PRIMARY KEY (id);


--
-- Name: sales_receipt_line sales_receipt_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_receipt_line
    ADD CONSTRAINT sales_receipt_line_pkey PRIMARY KEY (id);


--
-- Name: sales_receipt sales_receipt_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_receipt
    ADD CONSTRAINT sales_receipt_pkey PRIMARY KEY (id);


--
-- Name: salesman_target salesman_target_org_id_salesperson_id_period_type_period_st_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.salesman_target
    ADD CONSTRAINT salesman_target_org_id_salesperson_id_period_type_period_st_key UNIQUE (org_id, salesperson_id, period_type, period_start, target_type);


--
-- Name: salesman_target salesman_target_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.salesman_target
    ADD CONSTRAINT salesman_target_pkey PRIMARY KEY (id);


--
-- Name: salt_master salt_master_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.salt_master
    ADD CONSTRAINT salt_master_name_key UNIQUE (name);


--
-- Name: salt_master salt_master_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.salt_master
    ADD CONSTRAINT salt_master_pkey PRIMARY KEY (id);


--
-- Name: schemes schemes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schemes
    ADD CONSTRAINT schemes_pkey PRIMARY KEY (id);


--
-- Name: scrap_reason_code scrap_reason_code_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scrap_reason_code
    ADD CONSTRAINT scrap_reason_code_pkey PRIMARY KEY (id);


--
-- Name: serial_number serial_number_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.serial_number
    ADD CONSTRAINT serial_number_pkey PRIMARY KEY (id);


--
-- Name: shipment_line shipment_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shipment_line
    ADD CONSTRAINT shipment_line_pkey PRIMARY KEY (id);


--
-- Name: shipment shipment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shipment
    ADD CONSTRAINT shipment_pkey PRIMARY KEY (id);


--
-- Name: statutory_payment statutory_payment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.statutory_payment
    ADD CONSTRAINT statutory_payment_pkey PRIMARY KEY (id);


--
-- Name: stock_balance stock_balance_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_balance
    ADD CONSTRAINT stock_balance_pkey PRIMARY KEY (id);


--
-- Name: stock_batch_balance stock_batch_balance_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_batch_balance
    ADD CONSTRAINT stock_batch_balance_pkey PRIMARY KEY (id);


--
-- Name: stock_batch stock_batch_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_batch
    ADD CONSTRAINT stock_batch_pkey PRIMARY KEY (id);


--
-- Name: stock_count_line stock_count_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_count_line
    ADD CONSTRAINT stock_count_line_pkey PRIMARY KEY (id);


--
-- Name: stock_count stock_count_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_count
    ADD CONSTRAINT stock_count_pkey PRIMARY KEY (id);


--
-- Name: stock_movement stock_movement_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_pkey PRIMARY KEY (id);


--
-- Name: stock_receipt_line stock_receipt_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_receipt_line
    ADD CONSTRAINT stock_receipt_line_pkey PRIMARY KEY (id);


--
-- Name: stock_receipt stock_receipt_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_receipt
    ADD CONSTRAINT stock_receipt_pkey PRIMARY KEY (id);


--
-- Name: stock_reservation stock_reservation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_reservation
    ADD CONSTRAINT stock_reservation_pkey PRIMARY KEY (id);


--
-- Name: stock_reservation stock_reservation_source_type_source_line_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_reservation
    ADD CONSTRAINT stock_reservation_source_type_source_line_id_key UNIQUE (source_type, source_line_id);


--
-- Name: stockist_sales_line stockist_sales_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stockist_sales_line
    ADD CONSTRAINT stockist_sales_line_pkey PRIMARY KEY (id);


--
-- Name: stockist_sales_statement stockist_sales_statement_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stockist_sales_statement
    ADD CONSTRAINT stockist_sales_statement_pkey PRIMARY KEY (id);


--
-- Name: supplier_performance supplier_performance_org_id_supplier_id_period_start_period_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_performance
    ADD CONSTRAINT supplier_performance_org_id_supplier_id_period_start_period_key UNIQUE (org_id, supplier_id, period_start, period_end);


--
-- Name: supplier_performance supplier_performance_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_performance
    ADD CONSTRAINT supplier_performance_pkey PRIMARY KEY (id);


--
-- Name: supplier supplier_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier
    ADD CONSTRAINT supplier_pkey PRIMARY KEY (id);


--
-- Name: supply_chain_alert supply_chain_alert_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supply_chain_alert
    ADD CONSTRAINT supply_chain_alert_pkey PRIMARY KEY (id);


--
-- Name: tax_configuration tax_configuration_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tax_configuration
    ADD CONSTRAINT tax_configuration_pkey PRIMARY KEY (id);


--
-- Name: tax_group tax_group_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tax_group
    ADD CONSTRAINT tax_group_pkey PRIMARY KEY (id);


--
-- Name: tax_group_rate tax_group_rate_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tax_group_rate
    ADD CONSTRAINT tax_group_rate_pkey PRIMARY KEY (id);


--
-- Name: tax_group_rate tax_group_rate_tax_group_id_tax_rate_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tax_group_rate
    ADD CONSTRAINT tax_group_rate_tax_group_id_tax_rate_id_key UNIQUE (tax_group_id, tax_rate_id);


--
-- Name: tax_line_item tax_line_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tax_line_item
    ADD CONSTRAINT tax_line_item_pkey PRIMARY KEY (id);


--
-- Name: tax_rate tax_rate_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tax_rate
    ADD CONSTRAINT tax_rate_pkey PRIMARY KEY (id);


--
-- Name: tour_plan_entry tour_plan_entry_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_plan_entry
    ADD CONSTRAINT tour_plan_entry_pkey PRIMARY KEY (id);


--
-- Name: tour_plan tour_plan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_plan
    ADD CONSTRAINT tour_plan_pkey PRIMARY KEY (id);


--
-- Name: trading_partner trading_partner_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trading_partner
    ADD CONSTRAINT trading_partner_pkey PRIMARY KEY (id);


--
-- Name: transfer_order_line transfer_order_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfer_order_line
    ADD CONSTRAINT transfer_order_line_pkey PRIMARY KEY (id);


--
-- Name: transfer_order transfer_order_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfer_order
    ADD CONSTRAINT transfer_order_pkey PRIMARY KEY (id);


--
-- Name: document_state_config uk_document_state_config_transition; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_state_config
    ADD CONSTRAINT uk_document_state_config_transition UNIQUE (org_id, document_type, from_state, to_state);


--
-- Name: push_token uk_push_token_org_device; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_token
    ADD CONSTRAINT uk_push_token_org_device UNIQUE (org_id, device_token);


--
-- Name: workflow_definition uk_workflow_definition_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflow_definition
    ADD CONSTRAINT uk_workflow_definition_code UNIQUE (org_id, code);


--
-- Name: workflow_step uk_workflow_step_order; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflow_step
    ADD CONSTRAINT uk_workflow_step_order UNIQUE (workflow_definition_id, step_number);


--
-- Name: uom_conversion uom_conversion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uom_conversion
    ADD CONSTRAINT uom_conversion_pkey PRIMARY KEY (id);


--
-- Name: uom uom_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uom
    ADD CONSTRAINT uom_pkey PRIMARY KEY (id);


--
-- Name: account uq_account_code_org; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT uq_account_code_org UNIQUE (org_id, code);


--
-- Name: budget_line uq_budget_line; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget_line
    ADD CONSTRAINT uq_budget_line UNIQUE (org_id, fiscal_year, account_code);


--
-- Name: coa_template uq_coa_template; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coa_template
    ADD CONSTRAINT uq_coa_template UNIQUE (industry, code);


--
-- Name: drug_interaction uq_drug_interaction_pair; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drug_interaction
    ADD CONSTRAINT uq_drug_interaction_pair UNIQUE (primary_salt_id, interacting_salt_id);


--
-- Name: email_template uq_email_template_org_type; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_template
    ADD CONSTRAINT uq_email_template_org_type UNIQUE (org_id, template_type);


--
-- Name: generic_substitution uq_generic_substitution_pair; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generic_substitution
    ADD CONSTRAINT uq_generic_substitution_pair UNIQUE (drug_master_id, substitute_drug_master_id);


--
-- Name: idempotency_record uq_idempotency_org_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.idempotency_record
    ADD CONSTRAINT uq_idempotency_org_key UNIQUE (org_id, idempotency_key);


--
-- Name: journal_entry uq_journal_entry_number; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry
    ADD CONSTRAINT uq_journal_entry_number UNIQUE (org_id, entry_number);


--
-- Name: period_balance uq_period_balance; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.period_balance
    ADD CONSTRAINT uq_period_balance UNIQUE (org_id, account_id, period_year, period_month);


--
-- Name: rack_location uq_rack_location_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rack_location
    ADD CONSTRAINT uq_rack_location_code UNIQUE (org_id, warehouse_id, code);


--
-- Name: sales_receipt uq_sales_receipt_org_number; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_receipt
    ADD CONSTRAINT uq_sales_receipt_org_number UNIQUE (org_id, receipt_number);


--
-- Name: serial_number uq_serial_number; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.serial_number
    ADD CONSTRAINT uq_serial_number UNIQUE (org_id, item_id, serial);


--
-- Name: shipment uq_shipment_number; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shipment
    ADD CONSTRAINT uq_shipment_number UNIQUE (org_id, shipment_number);


--
-- Name: trading_partner uq_trading_partner; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trading_partner
    ADD CONSTRAINT uq_trading_partner UNIQUE (seller_org_id, buyer_org_id);


--
-- Name: transfer_order uq_transfer_order_number; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfer_order
    ADD CONSTRAINT uq_transfer_order_number UNIQUE (org_id, transfer_number);


--
-- Name: app_user uq_user_email_org; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT uq_user_email_org UNIQUE (org_id, email);


--
-- Name: app_user uq_user_phone_org; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT uq_user_phone_org UNIQUE (org_id, phone);


--
-- Name: warehouse_zone uq_warehouse_zone_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warehouse_zone
    ADD CONSTRAINT uq_warehouse_zone_code UNIQUE (org_id, warehouse_id, code);


--
-- Name: user_invitation user_invitation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_invitation
    ADD CONSTRAINT user_invitation_pkey PRIMARY KEY (id);


--
-- Name: user_invitation user_invitation_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_invitation
    ADD CONSTRAINT user_invitation_token_key UNIQUE (token);


--
-- Name: van van_org_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.van
    ADD CONSTRAINT van_org_id_code_key UNIQUE (org_id, code);


--
-- Name: van van_org_id_vehicle_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.van
    ADD CONSTRAINT van_org_id_vehicle_number_key UNIQUE (org_id, vehicle_number);


--
-- Name: van van_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.van
    ADD CONSTRAINT van_pkey PRIMARY KEY (id);


--
-- Name: van_stock_balance van_stock_balance_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.van_stock_balance
    ADD CONSTRAINT van_stock_balance_pkey PRIMARY KEY (id);


--
-- Name: van_stock_transfer_line van_stock_transfer_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.van_stock_transfer_line
    ADD CONSTRAINT van_stock_transfer_line_pkey PRIMARY KEY (id);


--
-- Name: van_stock_transfer van_stock_transfer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.van_stock_transfer
    ADD CONSTRAINT van_stock_transfer_pkey PRIMARY KEY (id);


--
-- Name: vehicle_log vehicle_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_log
    ADD CONSTRAINT vehicle_log_pkey PRIMARY KEY (id);


--
-- Name: vendor_credit_application vendor_credit_application_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_credit_application
    ADD CONSTRAINT vendor_credit_application_pkey PRIMARY KEY (id);


--
-- Name: vendor_credit_line vendor_credit_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_credit_line
    ADD CONSTRAINT vendor_credit_line_pkey PRIMARY KEY (id);


--
-- Name: vendor_credit vendor_credit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_credit
    ADD CONSTRAINT vendor_credit_pkey PRIMARY KEY (id);


--
-- Name: vendor_payment_allocation vendor_payment_allocation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_payment_allocation
    ADD CONSTRAINT vendor_payment_allocation_pkey PRIMARY KEY (id);


--
-- Name: vendor_payment vendor_payment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_payment
    ADD CONSTRAINT vendor_payment_pkey PRIMARY KEY (id);


--
-- Name: visit_detail_aid_log visit_detail_aid_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visit_detail_aid_log
    ADD CONSTRAINT visit_detail_aid_log_pkey PRIMARY KEY (id);


--
-- Name: visit_product_log visit_product_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visit_product_log
    ADD CONSTRAINT visit_product_log_pkey PRIMARY KEY (id);


--
-- Name: wallet_transaction wallet_transaction_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transaction
    ADD CONSTRAINT wallet_transaction_pkey PRIMARY KEY (id);


--
-- Name: warehouse warehouse_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warehouse
    ADD CONSTRAINT warehouse_pkey PRIMARY KEY (id);


--
-- Name: warehouse_zone warehouse_zone_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warehouse_zone
    ADD CONSTRAINT warehouse_zone_pkey PRIMARY KEY (id);


--
-- Name: whatsapp_message whatsapp_message_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_message
    ADD CONSTRAINT whatsapp_message_pkey PRIMARY KEY (id);


--
-- Name: work_order_line work_order_line_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_order_line
    ADD CONSTRAINT work_order_line_pkey PRIMARY KEY (id);


--
-- Name: work_order work_order_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_order
    ADD CONSTRAINT work_order_pkey PRIMARY KEY (id);


--
-- Name: workflow_definition workflow_definition_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflow_definition
    ADD CONSTRAINT workflow_definition_pkey PRIMARY KEY (id);


--
-- Name: workflow_step workflow_step_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflow_step
    ADD CONSTRAINT workflow_step_pkey PRIMARY KEY (id);


--
-- Name: workstation_alternate workstation_alternate_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workstation_alternate
    ADD CONSTRAINT workstation_alternate_pkey PRIMARY KEY (id);


--
-- Name: workstation workstation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workstation
    ADD CONSTRAINT workstation_pkey PRIMARY KEY (id);


--
-- Name: capa_number_org_uq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX capa_number_org_uq ON public.capa_action USING btree (org_id, capa_number) WHERE (is_deleted = false);


--
-- Name: capa_org_assignee_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX capa_org_assignee_idx ON public.capa_action USING btree (org_id, assigned_to) WHERE (is_deleted = false);


--
-- Name: capa_org_due_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX capa_org_due_idx ON public.capa_action USING btree (org_id, due_date) WHERE ((is_deleted = false) AND ((status)::text = ANY ((ARRAY['OPEN'::character varying, 'IN_PROGRESS'::character varying])::text[])));


--
-- Name: capa_org_ncr_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX capa_org_ncr_idx ON public.capa_action USING btree (org_id, ncr_id) WHERE ((is_deleted = false) AND (ncr_id IS NOT NULL));


--
-- Name: capa_org_open_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX capa_org_open_idx ON public.capa_action USING btree (org_id, status) WHERE ((is_deleted = false) AND ((status)::text = ANY ((ARRAY['OPEN'::character varying, 'IN_PROGRESS'::character varying])::text[])));


--
-- Name: idx_account_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_account_org ON public.account USING btree (org_id) WHERE (is_deleted = false);


--
-- Name: idx_account_org_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_account_org_type ON public.account USING btree (org_id, type) WHERE (is_deleted = false);


--
-- Name: idx_account_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_account_parent ON public.account USING btree (parent_id) WHERE (parent_id IS NOT NULL);


--
-- Name: idx_ai_model_registry_task_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ai_model_registry_task_status ON public.ai_model_registry USING btree (task_type, status);


--
-- Name: idx_ai_model_run_org_task; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ai_model_run_org_task ON public.ai_model_run USING btree (org_id, task_type, created_at DESC);


--
-- Name: idx_ai_pattern_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ai_pattern_lookup ON public.ai_pattern USING btree (org_id, pattern_type, status);


--
-- Name: idx_ai_suggestion_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ai_suggestion_entity ON public.ai_suggestion USING btree (org_id, entity_type, entity_id);


--
-- Name: idx_ai_suggestion_inbox; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ai_suggestion_inbox ON public.ai_suggestion USING btree (org_id, status, priority_score DESC, created_at DESC);


--
-- Name: idx_ai_training_example_task; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ai_training_example_task ON public.ai_training_example USING btree (org_id, task_type, created_at DESC);


--
-- Name: idx_ai_usage_log_org_feature; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ai_usage_log_org_feature ON public.ai_usage_log USING btree (org_id, feature, created_at DESC);


--
-- Name: idx_amort_entry_schedule; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_amort_entry_schedule ON public.amortization_entry USING btree (org_id, schedule_id);


--
-- Name: idx_amort_schedule_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_amort_schedule_org ON public.amortization_schedule USING btree (org_id) WHERE (is_deleted = false);


--
-- Name: idx_api_key_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_api_key_org ON public.api_key USING btree (org_id) WHERE (is_deleted = false);


--
-- Name: idx_app_user_reports_to; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_app_user_reports_to ON public.app_user USING btree (org_id, reports_to_user_id);


--
-- Name: idx_approval_request_document; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_request_document ON public.approval_request USING btree (org_id, document_type, document_id) WHERE (is_deleted = false);


--
-- Name: idx_approval_request_org_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approval_request_org_status ON public.approval_request USING btree (org_id, status) WHERE (is_deleted = false);


--
-- Name: idx_att_reg_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_att_reg_status ON public.attendance_regularization USING btree (org_id, status);


--
-- Name: idx_att_reg_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_att_reg_user ON public.attendance_regularization USING btree (org_id, user_id, work_date);


--
-- Name: idx_attendance_org_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_attendance_org_date ON public.field_attendance USING btree (org_id, work_date);


--
-- Name: idx_audit_org_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_org_entity ON public.audit_log USING btree (org_id, entity_type, created_at DESC);


--
-- Name: idx_audit_org_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_org_user ON public.audit_log USING btree (org_id, user_id, created_at DESC);


--
-- Name: idx_bank_transaction_org_status_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bank_transaction_org_status_date ON public.bank_transaction USING btree (org_id, status, transaction_date DESC, created_at DESC);


--
-- Name: idx_bank_transaction_org_utr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bank_transaction_org_utr ON public.bank_transaction USING btree (org_id, utr);


--
-- Name: idx_batch_trace_batch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_batch_trace_batch ON public.batch_trace USING btree (org_id, batch_id) WHERE (NOT is_deleted);


--
-- Name: idx_batch_trace_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_batch_trace_source ON public.batch_trace USING btree (org_id, source_batch_id) WHERE (NOT is_deleted);


--
-- Name: idx_batch_trace_work_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_batch_trace_work_order ON public.batch_trace USING btree (work_order_id) WHERE (NOT is_deleted);


--
-- Name: idx_beat_customer_beat; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_beat_customer_beat ON public.beat_customer USING btree (org_id, beat_id) WHERE is_active;


--
-- Name: idx_beat_customer_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_beat_customer_contact ON public.beat_customer USING btree (org_id, contact_id);


--
-- Name: idx_beat_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_beat_org ON public.beat USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_bmr_deviation_open; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bmr_deviation_open ON public.bmr_deviation USING btree (org_id, status) WHERE ((is_deleted = false) AND ((status)::text = ANY ((ARRAY['OPEN'::character varying, 'INVESTIGATING'::character varying])::text[])));


--
-- Name: idx_bmr_deviation_wo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bmr_deviation_wo ON public.bmr_deviation USING btree (org_id, work_order_id) WHERE (is_deleted = false);


--
-- Name: idx_bmr_signoff_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_bmr_signoff_unique ON public.bmr_signoff USING btree (org_id, work_order_id, COALESCE(job_card_id, '00000000-0000-0000-0000-000000000000'::uuid), role, signed_by) WHERE (is_deleted = false);


--
-- Name: idx_bmr_signoff_wo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bmr_signoff_wo ON public.bmr_signoff USING btree (org_id, work_order_id) WHERE (is_deleted = false);


--
-- Name: idx_bmr_step_record_jc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bmr_step_record_jc ON public.bmr_step_record USING btree (org_id, job_card_id) WHERE ((is_deleted = false) AND (job_card_id IS NOT NULL));


--
-- Name: idx_bmr_step_record_wo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bmr_step_record_wo ON public.bmr_step_record USING btree (org_id, work_order_id) WHERE (is_deleted = false);


--
-- Name: idx_bom_alternate_component; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bom_alternate_component ON public.bom_alternate USING btree (bom_component_id) WHERE (NOT is_deleted);


--
-- Name: idx_bom_alternate_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bom_alternate_org ON public.bom_alternate USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_bom_alternate_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_bom_alternate_unique ON public.bom_alternate USING btree (bom_component_id, alternate_item_id) WHERE (NOT is_deleted);


--
-- Name: idx_bom_co_product_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bom_co_product_org ON public.bom_co_product USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_bom_co_product_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bom_co_product_parent ON public.bom_co_product USING btree (org_id, parent_item_id) WHERE (NOT is_deleted);


--
-- Name: idx_bom_co_product_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_bom_co_product_unique ON public.bom_co_product USING btree (parent_item_id, co_product_item_id) WHERE (NOT is_deleted);


--
-- Name: idx_bom_component_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bom_component_org ON public.bom_component USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_bom_component_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bom_component_parent ON public.bom_component USING btree (parent_item_id) WHERE (NOT is_deleted);


--
-- Name: idx_bom_component_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_bom_component_unique ON public.bom_component USING btree (parent_item_id, child_item_id) WHERE (NOT is_deleted);


--
-- Name: idx_bom_component_variant_filter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bom_component_variant_filter ON public.bom_component USING gin (variant_filter) WHERE ((variant_filter IS NOT NULL) AND (is_deleted = false));


--
-- Name: idx_bom_component_version; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bom_component_version ON public.bom_component USING btree (org_id, parent_item_id, version) WHERE (NOT is_deleted);


--
-- Name: idx_branch_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_branch_org ON public.branch USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_branch_org_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_branch_org_code ON public.branch USING btree (org_id, code) WHERE (NOT is_deleted);


--
-- Name: idx_branch_org_default; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_branch_org_default ON public.branch USING btree (org_id) WHERE (is_default AND (NOT is_deleted));


--
-- Name: idx_budget_line_org_fy; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_budget_line_org_fy ON public.budget_line USING btree (org_id, fiscal_year) WHERE (is_deleted = false);


--
-- Name: idx_ca_alert_dismissal_firm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ca_alert_dismissal_firm ON public.ca_alert_dismissal USING btree (ca_firm_id, suggestion_id);


--
-- Name: idx_ca_client_link_assigned; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ca_client_link_assigned ON public.ca_client_link USING btree (assigned_user_id, backup_user_id);


--
-- Name: idx_ca_client_link_client_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ca_client_link_client_status ON public.ca_client_link USING btree (client_org_id, status);


--
-- Name: idx_ca_client_link_firm_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ca_client_link_firm_status ON public.ca_client_link USING btree (ca_firm_id, status);


--
-- Name: idx_ca_deadline_client_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ca_deadline_client_due ON public.ca_compliance_deadline USING btree (client_org_id, due_date);


--
-- Name: idx_ca_deadline_link_status_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ca_deadline_link_status_due ON public.ca_compliance_deadline USING btree (ca_client_link_id, status, due_date);


--
-- Name: idx_ca_report_dispatch_client_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ca_report_dispatch_client_created ON public.ca_report_dispatch USING btree (client_org_id, created_at DESC);


--
-- Name: idx_catalog_drug_master; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_catalog_drug_master ON public.published_catalog_item USING btree (drug_master_id) WHERE ((drug_master_id IS NOT NULL) AND (NOT is_deleted));


--
-- Name: idx_catalog_hsn; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_catalog_hsn ON public.published_catalog_item USING btree (hsn_code) WHERE ((hsn_code IS NOT NULL) AND (NOT is_deleted));


--
-- Name: idx_catalog_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_catalog_org ON public.published_catalog_item USING btree (org_id, is_active) WHERE (NOT is_deleted);


--
-- Name: idx_cod_remittance_line_awb; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cod_remittance_line_awb ON public.cod_remittance_line USING btree (org_id, awb_number);


--
-- Name: idx_consignment_settlement_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_consignment_settlement_org ON public.consignment_settlement USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_consignment_settlement_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_consignment_settlement_status ON public.consignment_settlement USING btree (org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_consignment_settlement_stock; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_consignment_settlement_stock ON public.consignment_settlement USING btree (consignment_stock_id) WHERE (NOT is_deleted);


--
-- Name: idx_consignment_stock_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_consignment_stock_item ON public.consignment_stock USING btree (org_id, item_id) WHERE (NOT is_deleted);


--
-- Name: idx_consignment_stock_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_consignment_stock_org ON public.consignment_stock USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_consignment_stock_supplier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_consignment_stock_supplier ON public.consignment_stock USING btree (org_id, supplier_id) WHERE (NOT is_deleted);


--
-- Name: idx_contact_default_pl; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contact_default_pl ON public.contact USING btree (default_price_list_id) WHERE (default_price_list_id IS NOT NULL);


--
-- Name: idx_contact_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contact_org ON public.contact USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_contact_org_gstin; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_contact_org_gstin ON public.contact USING btree (org_id, gstin) WHERE ((gstin IS NOT NULL) AND (NOT is_deleted));


--
-- Name: idx_contact_org_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contact_org_name ON public.contact USING btree (org_id, display_name) WHERE (NOT is_deleted);


--
-- Name: idx_contact_org_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contact_org_type ON public.contact USING btree (org_id, contact_type) WHERE (NOT is_deleted);


--
-- Name: idx_contact_person_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contact_person_contact ON public.contact_person USING btree (contact_id) WHERE (NOT is_deleted);


--
-- Name: idx_contact_person_primary; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_contact_person_primary ON public.contact_person USING btree (contact_id) WHERE (is_primary AND (NOT is_deleted));


--
-- Name: idx_cost_lot_consumption_lot; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cost_lot_consumption_lot ON public.cost_lot_consumption USING btree (lot_id);


--
-- Name: idx_cost_lot_consumption_movement; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cost_lot_consumption_movement ON public.cost_lot_consumption USING btree (movement_id);


--
-- Name: idx_cost_lot_fifo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cost_lot_fifo ON public.cost_lot USING btree (org_id, item_id, warehouse_id, received_date, created_at) WHERE is_active;


--
-- Name: idx_cost_lot_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cost_lot_source ON public.cost_lot USING btree (source_movement_id) WHERE (source_movement_id IS NOT NULL);


--
-- Name: idx_courier_event_shipment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_courier_event_shipment ON public.courier_shipment_event USING btree (org_id, courier_shipment_id, event_at DESC);


--
-- Name: idx_courier_shipment_invoice; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_courier_shipment_invoice ON public.courier_shipment USING btree (org_id, invoice_id) WHERE ((invoice_id IS NOT NULL) AND (is_deleted = false));


--
-- Name: idx_courier_shipment_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_courier_shipment_status ON public.courier_shipment USING btree (org_id, status) WHERE (is_deleted = false);


--
-- Name: idx_credit_note_invoice; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_credit_note_invoice ON public.credit_note USING btree (invoice_id);


--
-- Name: idx_credit_note_line_batch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_credit_note_line_batch ON public.credit_note_line USING btree (batch_id) WHERE (batch_id IS NOT NULL);


--
-- Name: idx_credit_note_line_cn; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_credit_note_line_cn ON public.credit_note_line USING btree (credit_note_id);


--
-- Name: idx_credit_note_line_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_credit_note_line_item ON public.credit_note_line USING btree (item_id) WHERE (item_id IS NOT NULL);


--
-- Name: idx_credit_note_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_credit_note_org ON public.credit_note USING btree (org_id);


--
-- Name: idx_credit_note_org_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_credit_note_org_number ON public.credit_note USING btree (org_id, credit_note_number) WHERE (NOT is_deleted);


--
-- Name: idx_day_close_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_day_close_date ON public.day_close USING btree (org_id, close_date);


--
-- Name: idx_dcr_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dcr_status ON public.dcr_report USING btree (org_id, status);


--
-- Name: idx_debit_note_line_dn; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_debit_note_line_dn ON public.debit_note_line USING btree (debit_note_id);


--
-- Name: idx_debit_note_org_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_debit_note_org_status ON public.debit_note USING btree (org_id, status, is_deleted);


--
-- Name: idx_debit_note_supplier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_debit_note_supplier ON public.debit_note USING btree (org_id, supplier_id) WHERE (is_deleted = false);


--
-- Name: idx_delegated_access_user_client; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_delegated_access_user_client ON public.delegated_access_token USING btree (ca_user_id, client_org_id, expires_at DESC);


--
-- Name: idx_delivery_challan_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_delivery_challan_contact ON public.delivery_challan USING btree (org_id, contact_id) WHERE (NOT is_deleted);


--
-- Name: idx_delivery_challan_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_delivery_challan_org ON public.delivery_challan USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_delivery_challan_so; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_delivery_challan_so ON public.delivery_challan USING btree (sales_order_id) WHERE (NOT is_deleted);


--
-- Name: idx_delivery_challan_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_delivery_challan_status ON public.delivery_challan USING btree (org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_demand_forecast_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_demand_forecast_item ON public.demand_forecast USING btree (org_id, item_id) WHERE (NOT is_deleted);


--
-- Name: idx_demand_forecast_month; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_demand_forecast_month ON public.demand_forecast USING btree (org_id, forecast_month);


--
-- Name: idx_demand_forecast_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_demand_forecast_org ON public.demand_forecast USING btree (org_id);


--
-- Name: idx_detail_aid_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_detail_aid_org ON public.detail_aid USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_document_state_config_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_document_state_config_org ON public.document_state_config USING btree (org_id, document_type) WHERE (is_deleted = false);


--
-- Name: idx_domain_event_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_domain_event_entity ON public.domain_event USING btree (org_id, entity_type, entity_id);


--
-- Name: idx_domain_event_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_domain_event_pending ON public.domain_event USING btree (org_id, processed, created_at);


--
-- Name: idx_domain_events_org_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_domain_events_org_entity ON public.domain_events USING btree (org_id, entity_type, entity_id);


--
-- Name: idx_domain_events_unprocessed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_domain_events_unprocessed ON public.domain_events USING btree (processed, created_at) WHERE ((processed = false) AND (dead_letter = false));


--
-- Name: idx_drug_interaction_interacting; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_drug_interaction_interacting ON public.drug_interaction USING btree (interacting_salt_id);


--
-- Name: idx_drug_interaction_primary; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_drug_interaction_primary ON public.drug_interaction USING btree (primary_salt_id);


--
-- Name: idx_drug_licenses_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_drug_licenses_expiry ON public.drug_licenses USING btree (expiry_date) WHERE (is_deleted = false);


--
-- Name: idx_drug_licenses_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_drug_licenses_org ON public.drug_licenses USING btree (org_id, is_deleted);


--
-- Name: idx_drug_master_brand_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_drug_master_brand_trgm ON public.drug_master USING gin (brand_name public.gin_trgm_ops);


--
-- Name: idx_drug_master_salt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_drug_master_salt ON public.drug_master USING btree (salt_id);


--
-- Name: idx_einvoice_org_invoice; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_einvoice_org_invoice ON public.einvoice USING btree (org_id, invoice_id) WHERE (is_deleted = false);


--
-- Name: idx_einvoice_org_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_einvoice_org_status ON public.einvoice USING btree (org_id, status) WHERE (is_deleted = false);


--
-- Name: idx_email_template_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_email_template_org ON public.email_template USING btree (org_id);


--
-- Name: idx_employee_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_employee_org ON public.employee USING btree (org_id);


--
-- Name: idx_employee_org_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_employee_org_status ON public.employee USING btree (org_id, employment_status) WHERE (is_deleted = false);


--
-- Name: idx_entity_attachment_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_entity_attachment_entity ON public.entity_attachment USING btree (org_id, entity_type, entity_id) WHERE (NOT is_deleted);


--
-- Name: idx_entity_comment_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_entity_comment_entity ON public.entity_comment USING btree (org_id, entity_type, entity_id) WHERE (NOT is_deleted);


--
-- Name: idx_entity_comment_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_entity_comment_user ON public.entity_comment USING btree (created_by) WHERE (created_by IS NOT NULL);


--
-- Name: idx_esc_structure; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_esc_structure ON public.employee_salary_component USING btree (salary_structure_id);


--
-- Name: idx_ess_employee; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ess_employee ON public.employee_salary_structure USING btree (employee_id);


--
-- Name: idx_ess_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ess_org ON public.employee_salary_structure USING btree (org_id);


--
-- Name: idx_estimate_converted; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_estimate_converted ON public.estimate USING btree (converted_to_invoice_id) WHERE (converted_to_invoice_id IS NOT NULL);


--
-- Name: idx_estimate_line_estimate; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_estimate_line_estimate ON public.estimate_line USING btree (estimate_id);


--
-- Name: idx_estimate_line_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_estimate_line_item ON public.estimate_line USING btree (item_id) WHERE (item_id IS NOT NULL);


--
-- Name: idx_estimate_org_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_estimate_org_contact ON public.estimate USING btree (org_id, contact_id) WHERE (NOT is_deleted);


--
-- Name: idx_estimate_org_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_estimate_org_date ON public.estimate USING btree (org_id, estimate_date DESC) WHERE (NOT is_deleted);


--
-- Name: idx_estimate_org_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_estimate_org_number ON public.estimate USING btree (org_id, estimate_number) WHERE (NOT is_deleted);


--
-- Name: idx_estimate_org_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_estimate_org_status ON public.estimate USING btree (org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_evt_user_used; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_evt_user_used ON public.email_verification_token USING btree (user_id, used);


--
-- Name: idx_eway_org_document; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_eway_org_document ON public.eway_bill USING btree (org_id, document_type, document_id) WHERE (is_deleted = false);


--
-- Name: idx_eway_org_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_eway_org_status ON public.eway_bill USING btree (org_id, status) WHERE (is_deleted = false);


--
-- Name: idx_eway_vehicle_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_eway_vehicle_date ON public.eway_bill USING btree (org_id, vehicle_number, document_date) WHERE (is_deleted = false);


--
-- Name: idx_exchange_rate_org_pair_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_exchange_rate_org_pair_date ON public.exchange_rate USING btree (org_id, from_currency, to_currency, effective_date DESC) WHERE (NOT is_deleted);


--
-- Name: idx_expense_journal; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_journal ON public.expense USING btree (journal_entry_id) WHERE (journal_entry_id IS NOT NULL);


--
-- Name: idx_expense_org_billable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_org_billable ON public.expense USING btree (org_id, customer_contact_id) WHERE ((is_billable = true) AND (NOT is_deleted));


--
-- Name: idx_expense_org_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_org_category ON public.expense USING btree (org_id, category) WHERE ((category IS NOT NULL) AND (NOT is_deleted));


--
-- Name: idx_expense_org_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_org_contact ON public.expense USING btree (org_id, contact_id) WHERE ((contact_id IS NOT NULL) AND (NOT is_deleted));


--
-- Name: idx_expense_org_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_org_date ON public.expense USING btree (org_id, expense_date DESC) WHERE (NOT is_deleted);


--
-- Name: idx_expense_org_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_expense_org_number ON public.expense USING btree (org_id, expense_number) WHERE (NOT is_deleted);


--
-- Name: idx_expense_org_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_expense_org_status ON public.expense USING btree (org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_field_assignment_person; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_field_assignment_person ON public.field_sales_assignment USING btree (org_id, salesperson_id) WHERE is_active;


--
-- Name: idx_field_visit_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_field_visit_contact ON public.field_visit USING btree (org_id, contact_id);


--
-- Name: idx_field_visit_execution; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_field_visit_execution ON public.field_visit USING btree (org_id, route_execution_id);


--
-- Name: idx_fiscal_period_org_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fiscal_period_org_status ON public.fiscal_period USING btree (org_id, status);


--
-- Name: idx_fixed_asset_dep_asset; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fixed_asset_dep_asset ON public.fixed_asset_depreciation USING btree (org_id, fixed_asset_id);


--
-- Name: idx_fixed_asset_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fixed_asset_org ON public.fixed_asset USING btree (org_id) WHERE (is_deleted = false);


--
-- Name: idx_flp_org_execution; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_flp_org_execution ON public.field_location_ping USING btree (org_id, route_execution_id);


--
-- Name: idx_flp_org_salesperson_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_flp_org_salesperson_time ON public.field_location_ping USING btree (org_id, salesperson_id, recorded_at DESC);


--
-- Name: idx_freight_rate_card_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_freight_rate_card_lookup ON public.freight_rate_card USING btree (org_id, transporter_contact_id, mode) WHERE ((is_deleted = false) AND (active = true));


--
-- Name: idx_fst_org_salesperson; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fst_org_salesperson ON public.field_sample_txn USING btree (org_id, salesperson_id);


--
-- Name: idx_generic_substitution_drug; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_generic_substitution_drug ON public.generic_substitution USING btree (drug_master_id);


--
-- Name: idx_gstr2b_match_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_gstr2b_match_status ON public.gstr2b_entry USING btree (org_id, return_period, match_status);


--
-- Name: idx_gstr2b_org_period; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_gstr2b_org_period ON public.gstr2b_entry USING btree (org_id, return_period);


--
-- Name: idx_hr_emp_doc_employee; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_emp_doc_employee ON public.hr_employee_document USING btree (org_id, employee_user_id);


--
-- Name: idx_hr_emp_doc_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_emp_doc_expiry ON public.hr_employee_document USING btree (org_id, expiry_date);


--
-- Name: idx_hr_employee_education_emp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_education_emp ON public.hr_employee_education USING btree (org_id, employee_id);


--
-- Name: idx_hr_employee_experience_emp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_experience_emp ON public.hr_employee_experience USING btree (org_id, employee_id);


--
-- Name: idx_hr_employee_family_emp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_employee_family_emp ON public.hr_employee_family USING btree (org_id, employee_id);


--
-- Name: idx_hr_offb_task; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_offb_task ON public.hr_offboarding_task USING btree (org_id, offboarding_id);


--
-- Name: idx_hr_offboarding_emp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_offboarding_emp ON public.hr_offboarding USING btree (org_id, employee_user_id);


--
-- Name: idx_hr_offboarding_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_offboarding_status ON public.hr_offboarding USING btree (org_id, status);


--
-- Name: idx_hr_shift_assign_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_shift_assign_user ON public.hr_shift_assignment USING btree (org_id, user_id, effective_from);


--
-- Name: idx_hr_ticket_assigned; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_ticket_assigned ON public.hr_ticket USING btree (org_id, assigned_to_user_id, status);


--
-- Name: idx_hr_ticket_comment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_ticket_comment ON public.hr_ticket_comment USING btree (org_id, ticket_id, created_at);


--
-- Name: idx_hr_ticket_raised; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_ticket_raised ON public.hr_ticket USING btree (org_id, raised_by_user_id, created_at);


--
-- Name: idx_hr_ticket_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_ticket_status ON public.hr_ticket USING btree (org_id, status);


--
-- Name: idx_hr_timesheet_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_timesheet_status ON public.hr_timesheet_entry USING btree (org_id, status);


--
-- Name: idx_hr_timesheet_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hr_timesheet_user ON public.hr_timesheet_entry USING btree (org_id, user_id, work_date);


--
-- Name: idx_hsn_gst_master_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hsn_gst_master_code ON public.hsn_gst_master USING btree (hsn_code);


--
-- Name: idx_idempotency_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_idempotency_expiry ON public.idempotency_record USING btree (expires_at);


--
-- Name: idx_industry_feature_template; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_industry_feature_template ON public.industry_feature_config USING btree (industry_template_id);


--
-- Name: idx_industry_sub_cat_template; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_industry_sub_cat_template ON public.industry_sub_category USING btree (industry_template_id);


--
-- Name: idx_industry_template_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_industry_template_type ON public.industry_template USING btree (business_type);


--
-- Name: idx_integration_config_org_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_integration_config_org_type ON public.integration_config USING btree (org_id, integration_type) WHERE ((NOT is_deleted) AND is_active);


--
-- Name: idx_integration_sync_log_config; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_integration_sync_log_config ON public.integration_sync_log USING btree (integration_id, started_at DESC) WHERE (NOT is_deleted);


--
-- Name: idx_integration_sync_log_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_integration_sync_log_org ON public.integration_sync_log USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_invitation_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invitation_org ON public.user_invitation USING btree (org_id);


--
-- Name: idx_invitation_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invitation_token ON public.user_invitation USING btree (token) WHERE (accepted_at IS NULL);


--
-- Name: idx_invoice_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invoice_contact ON public.invoice USING btree (contact_id);


--
-- Name: idx_invoice_contact_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invoice_contact_date ON public.invoice USING btree (contact_id, org_id, invoice_date);


--
-- Name: idx_invoice_date_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invoice_date_org ON public.invoice USING btree (org_id, invoice_date);


--
-- Name: idx_invoice_line_batch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invoice_line_batch ON public.invoice_line USING btree (batch_id) WHERE (batch_id IS NOT NULL);


--
-- Name: idx_invoice_line_invoice; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invoice_line_invoice ON public.invoice_line USING btree (invoice_id);


--
-- Name: idx_invoice_line_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invoice_line_item ON public.invoice_line USING btree (item_id) WHERE (item_id IS NOT NULL);


--
-- Name: idx_invoice_org_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invoice_org_date ON public.invoice USING btree (org_id, invoice_date);


--
-- Name: idx_invoice_org_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invoice_org_due ON public.invoice USING btree (org_id, due_date) WHERE ((status)::text = ANY (ARRAY[('SENT'::character varying)::text, ('PARTIALLY_PAID'::character varying)::text, ('OVERDUE'::character varying)::text]));


--
-- Name: idx_invoice_org_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_invoice_org_number ON public.invoice USING btree (org_id, invoice_number) WHERE (NOT is_deleted);


--
-- Name: idx_invoice_org_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invoice_org_status ON public.invoice USING btree (org_id, status);


--
-- Name: idx_invoice_sales_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_invoice_sales_order ON public.invoice USING btree (sales_order_id) WHERE (sales_order_id IS NOT NULL);


--
-- Name: idx_item_allergens; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_allergens ON public.item USING gin (allergens) WHERE ((allergens IS NOT NULL) AND (is_deleted = false));


--
-- Name: idx_item_barcode; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_barcode ON public.item USING btree (barcode) WHERE (barcode IS NOT NULL);


--
-- Name: idx_item_base_uom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_base_uom ON public.item USING btree (base_uom_id) WHERE (base_uom_id IS NOT NULL);


--
-- Name: idx_item_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_group_id ON public.item USING btree (group_id) WHERE ((group_id IS NOT NULL) AND (NOT is_deleted));


--
-- Name: idx_item_group_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_group_org ON public.item_group USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_item_group_org_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_item_group_org_name ON public.item_group USING btree (org_id, lower((name)::text)) WHERE (NOT is_deleted);


--
-- Name: idx_item_group_variant_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_item_group_variant_unique ON public.item USING btree (group_id, variant_attributes) WHERE ((group_id IS NOT NULL) AND (NOT is_deleted));


--
-- Name: idx_item_manufacturer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_manufacturer ON public.item USING btree (org_id, manufacturer) WHERE (manufacturer IS NOT NULL);


--
-- Name: idx_item_org_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_org_active ON public.item USING btree (org_id, is_active) WHERE (NOT is_deleted);


--
-- Name: idx_item_org_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_org_category ON public.item USING btree (org_id, category) WHERE (NOT is_deleted);


--
-- Name: idx_item_org_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_org_name ON public.item USING btree (org_id, name) WHERE (NOT is_deleted);


--
-- Name: idx_item_org_sku; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_item_org_sku ON public.item USING btree (org_id, sku) WHERE (NOT is_deleted);


--
-- Name: idx_item_preferred_vendor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_preferred_vendor ON public.item USING btree (preferred_vendor_id) WHERE (preferred_vendor_id IS NOT NULL);


--
-- Name: idx_item_purchase_uom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_purchase_uom ON public.item USING btree (purchase_uom_id) WHERE (purchase_uom_id IS NOT NULL);


--
-- Name: idx_item_supplier_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_supplier_item ON public.item_supplier USING btree (org_id, item_id) WHERE (NOT is_deleted);


--
-- Name: idx_item_supplier_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_supplier_org ON public.item_supplier USING btree (org_id);


--
-- Name: idx_item_supplier_supplier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_supplier_supplier ON public.item_supplier USING btree (org_id, supplier_id) WHERE (NOT is_deleted);


--
-- Name: idx_item_track_batches; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_track_batches ON public.item USING btree (org_id) WHERE (track_batches AND (NOT is_deleted));


--
-- Name: idx_item_unit_price_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_unit_price_item ON public.item_unit_price USING btree (org_id, item_id) WHERE (NOT is_deleted);


--
-- Name: idx_je_org_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_je_org_date ON public.journal_entry USING btree (org_id, effective_date);


--
-- Name: idx_je_org_period; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_je_org_period ON public.journal_entry USING btree (org_id, period_year, period_month);


--
-- Name: idx_je_org_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_je_org_status ON public.journal_entry USING btree (org_id, status);


--
-- Name: idx_je_reversal; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_je_reversal ON public.journal_entry USING btree (reversal_of_id) WHERE (reversal_of_id IS NOT NULL);


--
-- Name: idx_je_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_je_source ON public.journal_entry USING btree (org_id, source_module, source_id);


--
-- Name: idx_jl_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jl_account ON public.journal_line USING btree (account_id);


--
-- Name: idx_jl_account_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jl_account_entry ON public.journal_line USING btree (account_id, journal_entry_id);


--
-- Name: idx_jl_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jl_entry ON public.journal_line USING btree (journal_entry_id);


--
-- Name: idx_job_card_assigned; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_job_card_assigned ON public.job_card USING btree (org_id, assigned_to) WHERE (NOT is_deleted);


--
-- Name: idx_job_card_wo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_job_card_wo ON public.job_card USING btree (work_order_id) WHERE (NOT is_deleted);


--
-- Name: idx_journal_entry_date_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_journal_entry_date_org ON public.journal_entry USING btree (org_id, effective_date);


--
-- Name: idx_journal_post_dated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_journal_post_dated ON public.journal_entry USING btree (org_id, effective_date) WHERE ((is_post_dated = true) AND ((status)::text = 'DRAFT'::text));


--
-- Name: idx_jwo_gst_deadline; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jwo_gst_deadline ON public.job_work_order USING btree (org_id, gst_return_deadline) WHERE ((NOT is_deleted) AND (gst_return_deadline IS NOT NULL));


--
-- Name: idx_jwo_org_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jwo_org_status ON public.job_work_order USING btree (org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_jwo_org_vendor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jwo_org_vendor ON public.job_work_order USING btree (org_id, vendor_id) WHERE (NOT is_deleted);


--
-- Name: idx_jwol_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jwol_order ON public.job_work_order_line USING btree (job_work_order_id) WHERE (NOT is_deleted);


--
-- Name: idx_leave_org_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_leave_org_status ON public.leave_request USING btree (org_id, status);


--
-- Name: idx_leave_org_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_leave_org_user ON public.leave_request USING btree (org_id, user_id);


--
-- Name: idx_lorry_receipt_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lorry_receipt_status ON public.lorry_receipt USING btree (org_id, status) WHERE (is_deleted = false);


--
-- Name: idx_lorry_receipt_transporter; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lorry_receipt_transporter ON public.lorry_receipt USING btree (org_id, transporter_contact_id) WHERE (is_deleted = false);


--
-- Name: idx_maintenance_schedule_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_maintenance_schedule_due ON public.maintenance_schedule USING btree (org_id, next_due_date) WHERE ((is_active = true) AND (is_deleted = false));


--
-- Name: idx_maintenance_schedule_ws; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_maintenance_schedule_ws ON public.maintenance_schedule USING btree (org_id, workstation_id);


--
-- Name: idx_manufacturer_master_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_manufacturer_master_name ON public.manufacturer_master USING btree (name);


--
-- Name: idx_mrp_demand_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mrp_demand_item ON public.mrp_demand USING btree (org_id, item_id) WHERE (NOT is_deleted);


--
-- Name: idx_mrp_demand_run; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mrp_demand_run ON public.mrp_demand USING btree (mrp_run_id) WHERE (NOT is_deleted);


--
-- Name: idx_mrp_run_org_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mrp_run_org_date ON public.mrp_run USING btree (org_id, run_date DESC) WHERE (NOT is_deleted);


--
-- Name: idx_mrp_run_org_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mrp_run_org_status ON public.mrp_run USING btree (org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_mrp_supply_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mrp_supply_item ON public.mrp_supply USING btree (org_id, item_id) WHERE (NOT is_deleted);


--
-- Name: idx_mrp_supply_run; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mrp_supply_run ON public.mrp_supply USING btree (mrp_run_id) WHERE (NOT is_deleted);


--
-- Name: idx_mwo_reported; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mwo_reported ON public.maintenance_work_order USING btree (org_id, reported_at);


--
-- Name: idx_mwo_schedule; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mwo_schedule ON public.maintenance_work_order USING btree (org_id, schedule_id) WHERE (schedule_id IS NOT NULL);


--
-- Name: idx_mwo_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mwo_status ON public.maintenance_work_order USING btree (org_id, status);


--
-- Name: idx_mwo_ws; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_mwo_ws ON public.maintenance_work_order USING btree (org_id, workstation_id);


--
-- Name: idx_ncr_inspection; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ncr_inspection ON public.non_conformance_report USING btree (qc_inspection_id) WHERE (NOT is_deleted);


--
-- Name: idx_ncr_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ncr_item ON public.non_conformance_report USING btree (item_id) WHERE (NOT is_deleted);


--
-- Name: idx_ncr_org_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ncr_org_status ON public.non_conformance_report USING btree (org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_network_order_buyer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_network_order_buyer ON public.network_order USING btree (buyer_org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_network_order_event_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_network_order_event_order ON public.network_order_event USING btree (network_order_id);


--
-- Name: idx_network_order_line_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_network_order_line_order ON public.network_order_line USING btree (network_order_id);


--
-- Name: idx_network_order_partner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_network_order_partner ON public.network_order USING btree (trading_partner_id) WHERE (NOT is_deleted);


--
-- Name: idx_network_order_seller; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_network_order_seller ON public.network_order USING btree (seller_org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_notification_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_entity ON public.notification USING btree (entity_type, entity_id) WHERE (entity_type IS NOT NULL);


--
-- Name: idx_notification_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_org ON public.notification USING btree (org_id, created_at DESC);


--
-- Name: idx_notification_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_user ON public.notification USING btree (org_id, user_id, is_read) WHERE (user_id IS NOT NULL);


--
-- Name: idx_operation_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operation_org ON public.operation USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_org_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_org_active ON public.organisation USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_org_approval_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_org_approval_status ON public.organisation USING btree (approval_status, created_at DESC) WHERE (is_deleted = false);


--
-- Name: idx_org_default_account_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_org_default_account_org ON public.org_default_account USING btree (org_id);


--
-- Name: idx_org_feature_flag_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_org_feature_flag_org ON public.org_feature_flag USING btree (org_id);


--
-- Name: idx_org_settings_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_org_settings_org ON public.org_settings USING btree (org_id);


--
-- Name: idx_pa_audit_admin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pa_audit_admin ON public.platform_admin_audit USING btree (platform_admin_id);


--
-- Name: idx_pa_audit_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pa_audit_target ON public.platform_admin_audit USING btree (target_type, target_id);


--
-- Name: idx_payment_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_contact ON public.payment USING btree (contact_id);


--
-- Name: idx_payment_contact_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_contact_date ON public.payment USING btree (contact_id, org_id, payment_date);


--
-- Name: idx_payment_invoice; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_invoice ON public.payment USING btree (invoice_id);


--
-- Name: idx_payment_match_bill; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_match_bill ON public.payment_match USING btree (org_id, bill_id) WHERE (bill_id IS NOT NULL);


--
-- Name: idx_payment_match_org_invoice; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_match_org_invoice ON public.payment_match USING btree (org_id, invoice_id);


--
-- Name: idx_payment_match_org_tx_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_match_org_tx_status ON public.payment_match USING btree (org_id, bank_transaction_id, match_status, confidence DESC);


--
-- Name: idx_payment_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_org ON public.payment USING btree (org_id);


--
-- Name: idx_payment_org_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_payment_org_number ON public.payment USING btree (org_id, payment_number) WHERE (NOT is_deleted);


--
-- Name: idx_payment_org_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_org_status ON public.payment USING btree (org_id, status) WHERE (is_deleted = false);


--
-- Name: idx_payroll_audit_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payroll_audit_entity ON public.payroll_audit_log USING btree (entity_type, entity_id);


--
-- Name: idx_payroll_audit_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payroll_audit_org ON public.payroll_audit_log USING btree (org_id);


--
-- Name: idx_payroll_payment_run; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payroll_payment_run ON public.payroll_payment USING btree (payroll_run_id);


--
-- Name: idx_payroll_run_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payroll_run_org ON public.payroll_run USING btree (org_id);


--
-- Name: idx_payroll_run_org_period; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payroll_run_org_period ON public.payroll_run USING btree (org_id, period_start, period_end);


--
-- Name: idx_payroll_snapshot_run; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payroll_snapshot_run ON public.payroll_document_snapshot USING btree (payroll_run_id);


--
-- Name: idx_payslip_employee; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payslip_employee ON public.payslip USING btree (employee_id);


--
-- Name: idx_payslip_line_payslip; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payslip_line_payslip ON public.payslip_line USING btree (payslip_id);


--
-- Name: idx_payslip_run; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payslip_run ON public.payslip USING btree (payroll_run_id);


--
-- Name: idx_pb_org_period; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pb_org_period ON public.period_balance USING btree (org_id, account_id, period_year, period_month);


--
-- Name: idx_picklist_line_picklist; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_picklist_line_picklist ON public.picklist_line USING btree (picklist_id);


--
-- Name: idx_picklist_org_deleted; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_picklist_org_deleted ON public.picklist USING btree (org_id, is_deleted);


--
-- Name: idx_picklist_so; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_picklist_so ON public.picklist USING btree (sales_order_id);


--
-- Name: idx_planned_order_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_planned_order_item ON public.planned_order USING btree (org_id, item_id) WHERE (NOT is_deleted);


--
-- Name: idx_planned_order_run; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_planned_order_run ON public.planned_order USING btree (mrp_run_id) WHERE (NOT is_deleted);


--
-- Name: idx_planned_order_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_planned_order_status ON public.planned_order USING btree (org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_po_lines_po_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_po_lines_po_id ON public.purchase_order_lines USING btree (po_id);


--
-- Name: idx_po_org_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_po_org_created ON public.purchase_orders USING btree (org_id, created_at DESC) WHERE (is_deleted = false);


--
-- Name: idx_po_org_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_po_org_status ON public.purchase_orders USING btree (org_id, status, is_deleted);


--
-- Name: idx_pod_org_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pod_org_contact ON public.proof_of_delivery USING btree (org_id, contact_id) WHERE (contact_id IS NOT NULL);


--
-- Name: idx_pod_org_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pod_org_date ON public.proof_of_delivery USING btree (org_id, delivered_at);


--
-- Name: idx_pod_org_dc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pod_org_dc ON public.proof_of_delivery USING btree (org_id, delivery_challan_id) WHERE (delivery_challan_id IS NOT NULL);


--
-- Name: idx_pod_org_invoice; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pod_org_invoice ON public.proof_of_delivery USING btree (org_id, invoice_id) WHERE (invoice_id IS NOT NULL);


--
-- Name: idx_portal_user_invite; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_portal_user_invite ON public.portal_user USING btree (invite_token_hash) WHERE (is_deleted = false);


--
-- Name: idx_portal_user_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_portal_user_org ON public.portal_user USING btree (org_id) WHERE (is_deleted = false);


--
-- Name: idx_pos_cash_expense_register; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pos_cash_expense_register ON public.pos_cash_expense USING btree (register_id);


--
-- Name: idx_pos_cash_register_org_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pos_cash_register_org_date ON public.pos_cash_register USING btree (org_id, register_date);


--
-- Name: idx_posted_document_snapshot_org_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posted_document_snapshot_org_type ON public.posted_document_snapshot USING btree (org_id, document_type);


--
-- Name: idx_price_list_item_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_price_list_item_lookup ON public.price_list_item USING btree (price_list_id, item_id, min_quantity DESC) WHERE (NOT is_deleted);


--
-- Name: idx_price_list_item_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_price_list_item_org ON public.price_list_item USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_price_list_item_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_price_list_item_unique ON public.price_list_item USING btree (price_list_id, item_id, min_quantity) WHERE (NOT is_deleted);


--
-- Name: idx_price_list_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_price_list_org ON public.price_list USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_price_list_org_default; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_price_list_org_default ON public.price_list USING btree (org_id) WHERE (is_default AND (NOT is_deleted));


--
-- Name: idx_price_list_org_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_price_list_org_name ON public.price_list USING btree (org_id, name) WHERE (NOT is_deleted);


--
-- Name: idx_prod_cost_summary_fg; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prod_cost_summary_fg ON public.production_cost_summary USING btree (org_id, finished_good_id) WHERE (NOT is_deleted);


--
-- Name: idx_prod_cost_summary_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prod_cost_summary_org ON public.production_cost_summary USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_prod_cost_summary_wo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prod_cost_summary_wo ON public.production_cost_summary USING btree (work_order_id) WHERE (NOT is_deleted);


--
-- Name: idx_prod_scrap_wo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prod_scrap_wo ON public.production_scrap USING btree (work_order_id) WHERE (NOT is_deleted);


--
-- Name: idx_production_scrap_org_scrapped_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_production_scrap_org_scrapped_at ON public.production_scrap USING btree (org_id, scrapped_at) WHERE (is_deleted = false);


--
-- Name: idx_prt_user_used; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prt_user_used ON public.password_reset_token USING btree (user_id, used);


--
-- Name: idx_purchase_bill_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchase_bill_branch ON public.purchase_bill USING btree (org_id, branch_id) WHERE ((branch_id IS NOT NULL) AND (NOT is_deleted));


--
-- Name: idx_purchase_bill_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchase_bill_contact ON public.purchase_bill USING btree (contact_id);


--
-- Name: idx_purchase_bill_date_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchase_bill_date_org ON public.purchase_bill USING btree (org_id, bill_date);


--
-- Name: idx_purchase_bill_line_bill; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchase_bill_line_bill ON public.purchase_bill_line USING btree (purchase_bill_id);


--
-- Name: idx_purchase_bill_line_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchase_bill_line_item ON public.purchase_bill_line USING btree (item_id) WHERE (item_id IS NOT NULL);


--
-- Name: idx_purchase_bill_org_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchase_bill_org_date ON public.purchase_bill USING btree (org_id, bill_date);


--
-- Name: idx_purchase_bill_org_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchase_bill_org_due ON public.purchase_bill USING btree (org_id, due_date) WHERE ((status)::text = ANY (ARRAY[('OPEN'::character varying)::text, ('PARTIALLY_PAID'::character varying)::text, ('OVERDUE'::character varying)::text]));


--
-- Name: idx_purchase_bill_org_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_purchase_bill_org_number ON public.purchase_bill USING btree (org_id, bill_number) WHERE (NOT is_deleted);


--
-- Name: idx_purchase_bill_org_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchase_bill_org_status ON public.purchase_bill USING btree (org_id, status);


--
-- Name: idx_purchase_req_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchase_req_org ON public.purchase_requisition USING btree (org_id);


--
-- Name: idx_purchase_req_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_purchase_req_status ON public.purchase_requisition USING btree (org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_push_token_org_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_push_token_org_active ON public.push_token USING btree (org_id, is_active) WHERE (NOT is_deleted);


--
-- Name: idx_push_token_org_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_push_token_org_user ON public.push_token USING btree (org_id, user_id) WHERE (NOT is_deleted);


--
-- Name: idx_qc_insp_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_qc_insp_org ON public.qc_inspection USING btree (org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_qc_insp_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_qc_insp_ref ON public.qc_inspection USING btree (reference_type, reference_id) WHERE (NOT is_deleted);


--
-- Name: idx_qc_param_template; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_qc_param_template ON public.qc_parameter USING btree (template_id) WHERE (NOT is_deleted);


--
-- Name: idx_qc_result_insp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_qc_result_insp ON public.qc_inspection_result USING btree (inspection_id) WHERE (NOT is_deleted);


--
-- Name: idx_qc_template_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_qc_template_item ON public.qc_template USING btree (org_id, item_id) WHERE ((NOT is_deleted) AND (item_id IS NOT NULL));


--
-- Name: idx_qc_template_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_qc_template_org ON public.qc_template USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_rack_location_org_wh; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rack_location_org_wh ON public.rack_location USING btree (org_id, warehouse_id) WHERE (is_deleted = false);


--
-- Name: idx_rcpa_audit_chemist; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rcpa_audit_chemist ON public.rcpa_audit USING btree (org_id, chemist_contact_id, audit_date);


--
-- Name: idx_rcpa_audit_salesperson; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rcpa_audit_salesperson ON public.rcpa_audit USING btree (org_id, salesperson_id, audit_date);


--
-- Name: idx_rcpa_line_audit; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rcpa_line_audit ON public.rcpa_line USING btree (org_id, audit_id);


--
-- Name: idx_recurring_invoice_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_recurring_invoice_contact ON public.recurring_invoice USING btree (org_id, contact_id) WHERE (NOT is_deleted);


--
-- Name: idx_recurring_invoice_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_recurring_invoice_due ON public.recurring_invoice USING btree (status, next_invoice_date) WHERE (NOT is_deleted);


--
-- Name: idx_recurring_invoice_gen_invoice; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_recurring_invoice_gen_invoice ON public.recurring_invoice_generation USING btree (invoice_id);


--
-- Name: idx_recurring_invoice_gen_template; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_recurring_invoice_gen_template ON public.recurring_invoice_generation USING btree (recurring_invoice_id);


--
-- Name: idx_recurring_invoice_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_recurring_invoice_org ON public.recurring_invoice USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_refresh_token_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_refresh_token_hash ON public.refresh_token USING btree (token_hash) WHERE (revoked_at IS NULL);


--
-- Name: idx_refresh_token_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_refresh_token_user ON public.refresh_token USING btree (user_id);


--
-- Name: idx_reminder_log_followup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reminder_log_followup ON public.reminder_log USING btree (org_id, contact_id, followup_status, sent_at DESC);


--
-- Name: idx_reminder_log_org_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reminder_log_org_contact ON public.reminder_log USING btree (org_id, contact_id);


--
-- Name: idx_reminder_log_sent_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reminder_log_sent_at ON public.reminder_log USING btree (org_id, sent_at DESC);


--
-- Name: idx_reorder_policy_abc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reorder_policy_abc ON public.reorder_policy USING btree (org_id, abc_class) WHERE (NOT is_deleted);


--
-- Name: idx_reorder_policy_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reorder_policy_item ON public.reorder_policy USING btree (org_id, item_id) WHERE (NOT is_deleted);


--
-- Name: idx_reorder_policy_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reorder_policy_org ON public.reorder_policy USING btree (org_id);


--
-- Name: idx_return_order_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_return_order_contact ON public.return_order USING btree (org_id, contact_id) WHERE (NOT is_deleted);


--
-- Name: idx_return_order_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_return_order_org ON public.return_order USING btree (org_id);


--
-- Name: idx_return_order_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_return_order_status ON public.return_order USING btree (org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_route_beat_route; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_route_beat_route ON public.route_beat USING btree (org_id, route_id);


--
-- Name: idx_route_execution_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_route_execution_date ON public.route_execution USING btree (org_id, execution_date);


--
-- Name: idx_route_execution_person; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_route_execution_person ON public.route_execution USING btree (org_id, salesperson_id);


--
-- Name: idx_route_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_route_org ON public.route USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_routing_op_dep_pred; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_routing_op_dep_pred ON public.routing_operation_dependency USING btree (org_id, predecessor_routing_operation_id) WHERE (is_deleted = false);


--
-- Name: idx_routing_op_dep_succ; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_routing_op_dep_succ ON public.routing_operation_dependency USING btree (org_id, routing_operation_id) WHERE (is_deleted = false);


--
-- Name: idx_routing_op_dep_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_routing_op_dep_unique ON public.routing_operation_dependency USING btree (org_id, routing_operation_id, predecessor_routing_operation_id) WHERE (is_deleted = false);


--
-- Name: idx_routing_op_routing; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_routing_op_routing ON public.routing_operation USING btree (routing_id) WHERE (NOT is_deleted);


--
-- Name: idx_routing_org_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_routing_org_item ON public.routing USING btree (org_id, item_id) WHERE (NOT is_deleted);


--
-- Name: idx_rx_item_record; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rx_item_record ON public.prescription_record_item USING btree (prescription_record_id);


--
-- Name: idx_rx_record_org_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rx_record_org_contact ON public.prescription_record USING btree (org_id, contact_id) WHERE (is_deleted = false);


--
-- Name: idx_rx_record_receipt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rx_record_receipt ON public.prescription_record USING btree (receipt_id) WHERE (receipt_id IS NOT NULL);


--
-- Name: idx_salary_component_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_salary_component_org ON public.salary_component USING btree (org_id);


--
-- Name: idx_salary_component_org_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_salary_component_org_code ON public.salary_component USING btree (org_id, code);


--
-- Name: idx_sales_order_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sales_order_branch ON public.sales_order USING btree (org_id, branch_id) WHERE (NOT is_deleted);


--
-- Name: idx_sales_order_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sales_order_contact ON public.sales_order USING btree (org_id, contact_id) WHERE (NOT is_deleted);


--
-- Name: idx_sales_order_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sales_order_org ON public.sales_order USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_sales_order_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sales_order_status ON public.sales_order USING btree (org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_sales_receipt_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sales_receipt_branch ON public.sales_receipt USING btree (org_id, branch_id);


--
-- Name: idx_sales_receipt_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sales_receipt_contact ON public.sales_receipt USING btree (contact_id);


--
-- Name: idx_sales_receipt_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sales_receipt_date ON public.sales_receipt USING btree (org_id, receipt_date);


--
-- Name: idx_sales_receipt_date_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sales_receipt_date_org ON public.sales_receipt USING btree (org_id, receipt_date);


--
-- Name: idx_sales_receipt_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sales_receipt_org ON public.sales_receipt USING btree (org_id);


--
-- Name: idx_salesman_target_person; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_salesman_target_person ON public.salesman_target USING btree (org_id, salesperson_id);


--
-- Name: idx_salt_master_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_salt_master_name_trgm ON public.salt_master USING gin (name public.gin_trgm_ops);


--
-- Name: idx_sc_alert_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sc_alert_org ON public.supply_chain_alert USING btree (org_id);


--
-- Name: idx_sc_alert_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sc_alert_status ON public.supply_chain_alert USING btree (org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_sc_alert_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sc_alert_type ON public.supply_chain_alert USING btree (org_id, alert_type) WHERE (NOT is_deleted);


--
-- Name: idx_schemes_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_schemes_item ON public.schemes USING btree (item_id) WHERE (item_id IS NOT NULL);


--
-- Name: idx_schemes_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_schemes_org ON public.schemes USING btree (org_id, is_deleted, is_active);


--
-- Name: idx_scrap_reason_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_scrap_reason_org ON public.scrap_reason_code USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_serial_number_org_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_serial_number_org_item ON public.serial_number USING btree (org_id, item_id) WHERE (NOT is_deleted);


--
-- Name: idx_serial_number_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_serial_number_status ON public.serial_number USING btree (org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_serial_number_warehouse; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_serial_number_warehouse ON public.serial_number USING btree (org_id, warehouse_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_shipment_line_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_shipment_line_item ON public.shipment_line USING btree (org_id, item_id) WHERE (NOT is_deleted);


--
-- Name: idx_shipment_line_shipment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_shipment_line_shipment ON public.shipment_line USING btree (shipment_id) WHERE (NOT is_deleted);


--
-- Name: idx_shipment_org_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_shipment_org_status ON public.shipment USING btree (org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_shipment_org_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_shipment_org_type ON public.shipment USING btree (org_id, shipment_type) WHERE (NOT is_deleted);


--
-- Name: idx_so_line_backorder; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_so_line_backorder ON public.sales_order_line USING btree (item_id) WHERE (quantity_backordered > (0)::numeric);


--
-- Name: idx_srl_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_srl_item ON public.sales_receipt_line USING btree (item_id);


--
-- Name: idx_srl_receipt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_srl_receipt ON public.sales_receipt_line USING btree (receipt_id);


--
-- Name: idx_statutory_payment_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_statutory_payment_org ON public.statutory_payment USING btree (org_id);


--
-- Name: idx_statutory_payment_org_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_statutory_payment_org_type ON public.statutory_payment USING btree (org_id, statutory_type);


--
-- Name: idx_stock_balance_item_wh; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_stock_balance_item_wh ON public.stock_balance USING btree (org_id, item_id, warehouse_id);


--
-- Name: idx_stock_balance_org_wh; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_balance_org_wh ON public.stock_balance USING btree (org_id, warehouse_id);


--
-- Name: idx_stock_batch_balance_batch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_batch_balance_batch ON public.stock_batch_balance USING btree (batch_id);


--
-- Name: idx_stock_batch_balance_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_stock_batch_balance_unique ON public.stock_batch_balance USING btree (org_id, batch_id, warehouse_id);


--
-- Name: idx_stock_batch_balance_warehouse; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_batch_balance_warehouse ON public.stock_batch_balance USING btree (org_id, warehouse_id);


--
-- Name: idx_stock_batch_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_batch_expiry ON public.stock_batch USING btree (expiry_date) WHERE ((expiry_date IS NOT NULL) AND (NOT is_deleted) AND (NOT is_expired));


--
-- Name: idx_stock_batch_fefo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_batch_fefo ON public.stock_batch USING btree (org_id, item_id, expiry_date) WHERE (is_active AND (NOT is_deleted));


--
-- Name: idx_stock_batch_org_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_batch_org_item ON public.stock_batch USING btree (org_id, item_id) WHERE (NOT is_deleted);


--
-- Name: idx_stock_batch_org_item_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_stock_batch_org_item_number ON public.stock_batch USING btree (org_id, item_id, batch_number) WHERE (NOT is_deleted);


--
-- Name: idx_stock_count_line_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_count_line_count ON public.stock_count_line USING btree (stock_count_id);


--
-- Name: idx_stock_count_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_count_org ON public.stock_count USING btree (org_id, count_date);


--
-- Name: idx_stock_count_org_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_stock_count_org_number ON public.stock_count USING btree (org_id, count_number) WHERE (NOT is_deleted);


--
-- Name: idx_stock_movement_batch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_movement_batch ON public.stock_movement USING btree (batch_id) WHERE (batch_id IS NOT NULL);


--
-- Name: idx_stock_movement_date_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_movement_date_org ON public.stock_movement USING btree (org_id, movement_date);


--
-- Name: idx_stock_movement_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_movement_item ON public.stock_movement USING btree (org_id, item_id, movement_date);


--
-- Name: idx_stock_movement_item_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_movement_item_date ON public.stock_movement USING btree (org_id, item_id, movement_date);


--
-- Name: idx_stock_movement_org_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_movement_org_date ON public.stock_movement USING btree (org_id, movement_date);


--
-- Name: idx_stock_movement_org_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_movement_org_type ON public.stock_movement USING btree (org_id, movement_type);


--
-- Name: idx_stock_movement_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_movement_reference ON public.stock_movement USING btree (reference_type, reference_id);


--
-- Name: idx_stock_movement_type_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_movement_type_date ON public.stock_movement USING btree (org_id, movement_type, movement_date);


--
-- Name: idx_stock_movement_warehouse; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_movement_warehouse ON public.stock_movement USING btree (org_id, warehouse_id, movement_date);


--
-- Name: idx_stock_receipt_line_batch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_receipt_line_batch ON public.stock_receipt_line USING btree (batch_id) WHERE (batch_id IS NOT NULL);


--
-- Name: idx_stock_receipt_line_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_receipt_line_item ON public.stock_receipt_line USING btree (item_id);


--
-- Name: idx_stock_receipt_line_receipt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_receipt_line_receipt ON public.stock_receipt_line USING btree (receipt_id);


--
-- Name: idx_stock_receipt_org_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_receipt_org_date ON public.stock_receipt USING btree (org_id, receipt_date);


--
-- Name: idx_stock_receipt_org_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_stock_receipt_org_number ON public.stock_receipt USING btree (org_id, receipt_number) WHERE (NOT is_deleted);


--
-- Name: idx_stock_receipt_org_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_receipt_org_status ON public.stock_receipt USING btree (org_id, status);


--
-- Name: idx_stock_receipt_org_supplier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_receipt_org_supplier ON public.stock_receipt USING btree (org_id, supplier_id);


--
-- Name: idx_stock_reservation_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_reservation_item ON public.stock_reservation USING btree (org_id, item_id, status);


--
-- Name: idx_stock_reservation_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stock_reservation_source ON public.stock_reservation USING btree (source_type, source_id);


--
-- Name: idx_stockist_line_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stockist_line_item ON public.stockist_sales_line USING btree (org_id, item_id);


--
-- Name: idx_stockist_line_stmt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stockist_line_stmt ON public.stockist_sales_line USING btree (org_id, statement_id);


--
-- Name: idx_supplier_org_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_supplier_org_active ON public.supplier USING btree (org_id, is_active) WHERE (NOT is_deleted);


--
-- Name: idx_supplier_org_gstin; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_supplier_org_gstin ON public.supplier USING btree (org_id, gstin) WHERE ((gstin IS NOT NULL) AND (NOT is_deleted));


--
-- Name: idx_supplier_org_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_supplier_org_name ON public.supplier USING btree (org_id, name) WHERE (NOT is_deleted);


--
-- Name: idx_supplier_perf_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_supplier_perf_org ON public.supplier_performance USING btree (org_id);


--
-- Name: idx_supplier_perf_supplier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_supplier_perf_supplier ON public.supplier_performance USING btree (org_id, supplier_id);


--
-- Name: idx_tax_config_org_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_tax_config_org_active ON public.tax_configuration USING btree (org_id) WHERE is_active;


--
-- Name: idx_tax_group_org_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_tax_group_org_name ON public.tax_group USING btree (org_id, name) WHERE is_active;


--
-- Name: idx_tax_group_rate_group; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tax_group_rate_group ON public.tax_group_rate USING btree (tax_group_id);


--
-- Name: idx_tax_line_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tax_line_org ON public.tax_line_item USING btree (org_id);


--
-- Name: idx_tax_line_regime; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tax_line_regime ON public.tax_line_item USING btree (org_id, tax_regime, component_code);


--
-- Name: idx_tax_line_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tax_line_source ON public.tax_line_item USING btree (source_type, source_id);


--
-- Name: idx_tax_line_source_line; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tax_line_source_line ON public.tax_line_item USING btree (source_line_id, source_type);


--
-- Name: idx_tax_rate_config; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tax_rate_config ON public.tax_rate USING btree (tax_config_id);


--
-- Name: idx_tax_rate_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tax_rate_org ON public.tax_rate USING btree (org_id) WHERE is_active;


--
-- Name: idx_tpe_plan; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tpe_plan ON public.tour_plan_entry USING btree (org_id, tour_plan_id);


--
-- Name: idx_trading_partner_buyer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trading_partner_buyer ON public.trading_partner USING btree (buyer_org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_trading_partner_seller; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trading_partner_seller ON public.trading_partner USING btree (seller_org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_transfer_order_line_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transfer_order_line_order ON public.transfer_order_line USING btree (transfer_order_id);


--
-- Name: idx_transfer_order_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transfer_order_org ON public.transfer_order USING btree (org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_uom_conv_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_uom_conv_org ON public.uom_conversion USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_uom_conv_org_wide; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_uom_conv_org_wide ON public.uom_conversion USING btree (org_id, from_uom_id, to_uom_id) WHERE ((item_id IS NULL) AND (NOT is_deleted));


--
-- Name: idx_uom_conv_per_item; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_uom_conv_per_item ON public.uom_conversion USING btree (org_id, item_id, from_uom_id, to_uom_id) WHERE ((item_id IS NOT NULL) AND (NOT is_deleted));


--
-- Name: idx_uom_org_abbr; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_uom_org_abbr ON public.uom USING btree (org_id, abbreviation) WHERE (NOT is_deleted);


--
-- Name: idx_uom_org_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_uom_org_active ON public.uom USING btree (org_id, is_active) WHERE (NOT is_deleted);


--
-- Name: idx_uom_org_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_uom_org_category ON public.uom USING btree (org_id, category) WHERE (NOT is_deleted);


--
-- Name: idx_user_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_email ON public.app_user USING btree (email) WHERE ((email IS NOT NULL) AND (is_deleted = false));


--
-- Name: idx_user_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_org ON public.app_user USING btree (org_id) WHERE (is_deleted = false);


--
-- Name: idx_user_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_phone ON public.app_user USING btree (phone) WHERE ((phone IS NOT NULL) AND (is_deleted = false));


--
-- Name: idx_van_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_van_org ON public.van USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_van_stock_balance_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_van_stock_balance_item ON public.van_stock_balance USING btree (org_id, item_id);


--
-- Name: idx_van_stock_balance_van; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_van_stock_balance_van ON public.van_stock_balance USING btree (org_id, van_id);


--
-- Name: idx_van_transfer_van; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_van_transfer_van ON public.van_stock_transfer USING btree (org_id, van_id);


--
-- Name: idx_vca_bill; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vca_bill ON public.vendor_credit_application USING btree (purchase_bill_id);


--
-- Name: idx_vca_credit; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vca_credit ON public.vendor_credit_application USING btree (vendor_credit_id);


--
-- Name: idx_vdal_aid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vdal_aid ON public.visit_detail_aid_log USING btree (org_id, detail_aid_id);


--
-- Name: idx_vdal_visit; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vdal_visit ON public.visit_detail_aid_log USING btree (org_id, field_visit_id);


--
-- Name: idx_vehicle_log_vehicle; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vehicle_log_vehicle ON public.vehicle_log USING btree (org_id, vehicle_number, log_date DESC) WHERE (is_deleted = false);


--
-- Name: idx_vendor_credit_bill; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_credit_bill ON public.vendor_credit USING btree (purchase_bill_id) WHERE (purchase_bill_id IS NOT NULL);


--
-- Name: idx_vendor_credit_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_credit_contact ON public.vendor_credit USING btree (contact_id);


--
-- Name: idx_vendor_credit_line_credit; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_credit_line_credit ON public.vendor_credit_line USING btree (vendor_credit_id);


--
-- Name: idx_vendor_credit_line_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_credit_line_item ON public.vendor_credit_line USING btree (item_id) WHERE (item_id IS NOT NULL);


--
-- Name: idx_vendor_credit_org_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_vendor_credit_org_number ON public.vendor_credit USING btree (org_id, credit_number) WHERE (NOT is_deleted);


--
-- Name: idx_vendor_credit_org_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_credit_org_status ON public.vendor_credit USING btree (org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_vendor_payment_branch; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_branch ON public.vendor_payment USING btree (org_id, branch_id) WHERE ((branch_id IS NOT NULL) AND (NOT is_deleted));


--
-- Name: idx_vendor_payment_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_contact ON public.vendor_payment USING btree (contact_id);


--
-- Name: idx_vendor_payment_org_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vendor_payment_org_date ON public.vendor_payment USING btree (org_id, payment_date);


--
-- Name: idx_vendor_payment_org_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_vendor_payment_org_number ON public.vendor_payment USING btree (org_id, payment_number) WHERE (NOT is_deleted);


--
-- Name: idx_vpa_bill; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vpa_bill ON public.vendor_payment_allocation USING btree (purchase_bill_id);


--
-- Name: idx_vpa_payment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vpa_payment ON public.vendor_payment_allocation USING btree (vendor_payment_id);


--
-- Name: idx_vpa_payment_bill; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_vpa_payment_bill ON public.vendor_payment_allocation USING btree (vendor_payment_id, purchase_bill_id);


--
-- Name: idx_vpl_visit; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vpl_visit ON public.visit_product_log USING btree (org_id, field_visit_id);


--
-- Name: idx_wallet_org_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_wallet_org_contact ON public.customer_wallet USING btree (org_id, contact_id) WHERE (is_deleted = false);


--
-- Name: idx_wallet_txn_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wallet_txn_contact ON public.wallet_transaction USING btree (org_id, contact_id);


--
-- Name: idx_wallet_txn_wallet; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wallet_txn_wallet ON public.wallet_transaction USING btree (wallet_id);


--
-- Name: idx_warehouse_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_warehouse_org ON public.warehouse USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_warehouse_org_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_warehouse_org_code ON public.warehouse USING btree (org_id, code) WHERE (NOT is_deleted);


--
-- Name: idx_warehouse_org_default; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_warehouse_org_default ON public.warehouse USING btree (org_id) WHERE (is_default AND (NOT is_deleted));


--
-- Name: idx_warehouse_zone_wh; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_warehouse_zone_wh ON public.warehouse_zone USING btree (org_id, warehouse_id) WHERE (NOT is_deleted);


--
-- Name: idx_whatsapp_message_doc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_whatsapp_message_doc ON public.whatsapp_message USING btree (org_id, doc_type, doc_id);


--
-- Name: idx_whatsapp_message_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_whatsapp_message_org ON public.whatsapp_message USING btree (org_id, created_at DESC);


--
-- Name: idx_wo_sales_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wo_sales_order ON public.work_order USING btree (sales_order_id) WHERE ((NOT is_deleted) AND (sales_order_id IS NOT NULL));


--
-- Name: idx_work_order_fg; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_work_order_fg ON public.work_order USING btree (org_id, finished_good_id) WHERE (NOT is_deleted);


--
-- Name: idx_work_order_journal; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_work_order_journal ON public.work_order USING btree (journal_entry_id) WHERE (journal_entry_id IS NOT NULL);


--
-- Name: idx_work_order_line_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_work_order_line_item ON public.work_order_line USING btree (org_id, item_id) WHERE (NOT is_deleted);


--
-- Name: idx_work_order_line_wo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_work_order_line_wo ON public.work_order_line USING btree (work_order_id) WHERE (NOT is_deleted);


--
-- Name: idx_work_order_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_work_order_number ON public.work_order USING btree (org_id, work_order_number) WHERE (NOT is_deleted);


--
-- Name: idx_work_order_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_work_order_org ON public.work_order USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: idx_work_order_org_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_work_order_org_created ON public.work_order USING btree (org_id, created_at) WHERE (is_deleted = false);


--
-- Name: idx_work_order_org_priority; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_work_order_org_priority ON public.work_order USING btree (org_id, priority) WHERE (is_deleted = false);


--
-- Name: idx_work_order_parent_wo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_work_order_parent_wo ON public.work_order USING btree (org_id, parent_work_order_id) WHERE ((parent_work_order_id IS NOT NULL) AND (is_deleted = false));


--
-- Name: idx_work_order_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_work_order_status ON public.work_order USING btree (org_id, status) WHERE (NOT is_deleted);


--
-- Name: idx_workflow_definition_org_doc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_workflow_definition_org_doc ON public.workflow_definition USING btree (org_id, document_type) WHERE (is_deleted = false);


--
-- Name: idx_workstation_alternate_op; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_workstation_alternate_op ON public.workstation_alternate USING btree (org_id, routing_operation_id) WHERE (is_deleted = false);


--
-- Name: idx_workstation_alternate_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_workstation_alternate_unique ON public.workstation_alternate USING btree (org_id, routing_operation_id, workstation_id) WHERE (is_deleted = false);


--
-- Name: idx_workstation_org; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_workstation_org ON public.workstation USING btree (org_id) WHERE (NOT is_deleted);


--
-- Name: uq_amort_entry_period; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_amort_entry_period ON public.amortization_entry USING btree (org_id, schedule_id, period_year, period_month);


--
-- Name: uq_api_key_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_api_key_hash ON public.api_key USING btree (key_hash);


--
-- Name: uq_attendance_day; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_attendance_day ON public.field_attendance USING btree (org_id, user_id, work_date);


--
-- Name: uq_cod_remittance_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_cod_remittance_number ON public.cod_remittance USING btree (org_id, remittance_number) WHERE (is_deleted = false);


--
-- Name: uq_courier_shipment_awb; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_courier_shipment_awb ON public.courier_shipment USING btree (org_id, courier_partner, awb_number) WHERE ((awb_number IS NOT NULL) AND (is_deleted = false));


--
-- Name: uq_courier_shipment_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_courier_shipment_number ON public.courier_shipment USING btree (org_id, courier_shipment_number) WHERE (is_deleted = false);


--
-- Name: uq_dcr_day; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_dcr_day ON public.dcr_report USING btree (org_id, salesperson_id, report_date) WHERE (is_deleted = false);


--
-- Name: uq_fac_day; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_fac_day ON public.field_allowance_claim USING btree (org_id, salesperson_id, claim_date);


--
-- Name: uq_field_sync_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_field_sync_entry ON public.field_sync_entry USING btree (org_id, salesperson_id, client_id);


--
-- Name: uq_fixed_asset_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_fixed_asset_code ON public.fixed_asset USING btree (org_id, asset_code) WHERE (is_deleted = false);


--
-- Name: uq_fixed_asset_dep_period; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_fixed_asset_dep_period ON public.fixed_asset_depreciation USING btree (org_id, fixed_asset_id, period_year, period_month);


--
-- Name: uq_gst_filing_snapshot; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_gst_filing_snapshot ON public.gst_filing_snapshot USING btree (org_id, return_period);


--
-- Name: uq_hr_employee_profile_user; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_hr_employee_profile_user ON public.hr_employee_profile USING btree (org_id, user_id) WHERE (is_deleted = false);


--
-- Name: uq_hr_holiday_date; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_hr_holiday_date ON public.hr_holiday USING btree (org_id, holiday_date) WHERE (is_deleted = false);


--
-- Name: uq_hr_leave_balance; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_hr_leave_balance ON public.hr_leave_balance USING btree (org_id, user_id, leave_type_id, year) WHERE (is_deleted = false);


--
-- Name: uq_hr_leave_type_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_hr_leave_type_code ON public.hr_leave_type USING btree (org_id, code) WHERE (is_deleted = false);


--
-- Name: uq_hr_shift_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_hr_shift_code ON public.hr_shift USING btree (org_id, code) WHERE (is_deleted = false);


--
-- Name: uq_lorry_receipt_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_lorry_receipt_number ON public.lorry_receipt USING btree (org_id, lr_number) WHERE (is_deleted = false);


--
-- Name: uq_portal_user_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_portal_user_contact ON public.portal_user USING btree (org_id, contact_id) WHERE (is_deleted = false);


--
-- Name: uq_portal_user_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_portal_user_email ON public.portal_user USING btree (lower((email)::text)) WHERE (is_deleted = false);


--
-- Name: uq_stockist_stmt_period; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_stockist_stmt_period ON public.stockist_sales_statement USING btree (org_id, stockist_contact_id, period_month) WHERE (is_deleted = false);


--
-- Name: uq_tour_plan_month; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_tour_plan_month ON public.tour_plan USING btree (org_id, salesperson_id, plan_month) WHERE (is_deleted = false);


--
-- Name: uq_van_stock_balance_grain; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_van_stock_balance_grain ON public.van_stock_balance USING btree (org_id, van_id, item_id, COALESCE(batch_id, '00000000-0000-0000-0000-000000000000'::uuid));


--
-- Name: uq_van_stock_balance_org_van_item_batch; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_van_stock_balance_org_van_item_batch ON public.van_stock_balance USING btree (org_id, van_id, item_id, COALESCE(batch_id, '00000000-0000-0000-0000-000000000000'::uuid));


--
-- Name: journal_entry trg_check_balance_on_post; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check_balance_on_post BEFORE UPDATE OF status ON public.journal_entry FOR EACH ROW WHEN ((((new.status)::text = 'POSTED'::text) AND ((old.status)::text = 'DRAFT'::text))) EXECUTE FUNCTION public.check_journal_balance();


--
-- Name: journal_entry trg_journal_entry_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_journal_entry_immutable BEFORE UPDATE ON public.journal_entry FOR EACH ROW EXECUTE FUNCTION public.prevent_journal_entry_update();


--
-- Name: journal_entry trg_journal_entry_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_journal_entry_no_delete BEFORE DELETE ON public.journal_entry FOR EACH ROW EXECUTE FUNCTION public.prevent_journal_entry_delete();


--
-- Name: journal_line trg_journal_line_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_journal_line_immutable BEFORE DELETE OR UPDATE ON public.journal_line FOR EACH ROW EXECUTE FUNCTION public.prevent_journal_line_mutation();


--
-- Name: stock_movement trg_stock_movement_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_stock_movement_immutable BEFORE UPDATE ON public.stock_movement FOR EACH ROW EXECUTE FUNCTION public.prevent_stock_movement_mutation();


--
-- Name: stock_movement trg_stock_movement_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_stock_movement_no_delete BEFORE DELETE ON public.stock_movement FOR EACH ROW EXECUTE FUNCTION public.prevent_stock_movement_delete();


--
-- Name: account account_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: account account_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.account(id);


--
-- Name: ai_model_run ai_model_run_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_model_run
    ADD CONSTRAINT ai_model_run_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: ai_pattern ai_pattern_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_pattern
    ADD CONSTRAINT ai_pattern_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: ai_suggestion ai_suggestion_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_suggestion
    ADD CONSTRAINT ai_suggestion_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: ai_suggestion ai_suggestion_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_suggestion
    ADD CONSTRAINT ai_suggestion_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES public.app_user(id);


--
-- Name: ai_training_example ai_training_example_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_training_example
    ADD CONSTRAINT ai_training_example_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id);


--
-- Name: ai_training_example ai_training_example_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_training_example
    ADD CONSTRAINT ai_training_example_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: ai_training_example ai_training_example_source_suggestion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_training_example
    ADD CONSTRAINT ai_training_example_source_suggestion_id_fkey FOREIGN KEY (source_suggestion_id) REFERENCES public.ai_suggestion(id);


--
-- Name: ai_usage_log ai_usage_log_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_usage_log
    ADD CONSTRAINT ai_usage_log_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: app_user app_user_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branch(id);


--
-- Name: app_user app_user_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: approval_decision approval_decision_approval_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_decision
    ADD CONSTRAINT approval_decision_approval_request_id_fkey FOREIGN KEY (approval_request_id) REFERENCES public.approval_request(id) ON DELETE CASCADE;


--
-- Name: approval_decision approval_decision_decided_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_decision
    ADD CONSTRAINT approval_decision_decided_by_fkey FOREIGN KEY (decided_by) REFERENCES public.app_user(id);


--
-- Name: approval_decision approval_decision_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_decision
    ADD CONSTRAINT approval_decision_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: approval_request approval_request_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_request
    ADD CONSTRAINT approval_request_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: approval_request approval_request_requested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_request
    ADD CONSTRAINT approval_request_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.app_user(id);


--
-- Name: approval_request approval_request_workflow_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_request
    ADD CONSTRAINT approval_request_workflow_id_fkey FOREIGN KEY (workflow_id) REFERENCES public.workflow_definition(id);


--
-- Name: bank_transaction bank_transaction_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bank_transaction
    ADD CONSTRAINT bank_transaction_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: bank_transaction bank_transaction_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bank_transaction
    ADD CONSTRAINT bank_transaction_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payment(id);


--
-- Name: beat_customer beat_customer_beat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.beat_customer
    ADD CONSTRAINT beat_customer_beat_id_fkey FOREIGN KEY (beat_id) REFERENCES public.beat(id);


--
-- Name: bmr_deviation bmr_deviation_wo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bmr_deviation
    ADD CONSTRAINT bmr_deviation_wo_fkey FOREIGN KEY (work_order_id) REFERENCES public.work_order(id);


--
-- Name: bmr_signoff bmr_signoff_wo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bmr_signoff
    ADD CONSTRAINT bmr_signoff_wo_fkey FOREIGN KEY (work_order_id) REFERENCES public.work_order(id);


--
-- Name: bmr_step_record bmr_step_record_wo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bmr_step_record
    ADD CONSTRAINT bmr_step_record_wo_fkey FOREIGN KEY (work_order_id) REFERENCES public.work_order(id);


--
-- Name: bom_alternate bom_alternate_alternate_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bom_alternate
    ADD CONSTRAINT bom_alternate_alternate_item_id_fkey FOREIGN KEY (alternate_item_id) REFERENCES public.item(id);


--
-- Name: bom_alternate bom_alternate_bom_component_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bom_alternate
    ADD CONSTRAINT bom_alternate_bom_component_id_fkey FOREIGN KEY (bom_component_id) REFERENCES public.bom_component(id);


--
-- Name: bom_alternate bom_alternate_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bom_alternate
    ADD CONSTRAINT bom_alternate_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: bom_co_product bom_co_product_co_product_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bom_co_product
    ADD CONSTRAINT bom_co_product_co_product_item_id_fkey FOREIGN KEY (co_product_item_id) REFERENCES public.item(id);


--
-- Name: bom_co_product bom_co_product_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bom_co_product
    ADD CONSTRAINT bom_co_product_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: bom_co_product bom_co_product_parent_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bom_co_product
    ADD CONSTRAINT bom_co_product_parent_item_id_fkey FOREIGN KEY (parent_item_id) REFERENCES public.item(id);


--
-- Name: bom_component bom_component_child_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bom_component
    ADD CONSTRAINT bom_component_child_item_id_fkey FOREIGN KEY (child_item_id) REFERENCES public.item(id);


--
-- Name: bom_component bom_component_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bom_component
    ADD CONSTRAINT bom_component_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: bom_component bom_component_parent_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bom_component
    ADD CONSTRAINT bom_component_parent_item_id_fkey FOREIGN KEY (parent_item_id) REFERENCES public.item(id);


--
-- Name: branch branch_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch
    ADD CONSTRAINT branch_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: budget_line budget_line_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.budget_line
    ADD CONSTRAINT budget_line_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: ca_alert_dismissal ca_alert_dismissal_assigned_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_alert_dismissal
    ADD CONSTRAINT ca_alert_dismissal_assigned_user_id_fkey FOREIGN KEY (assigned_user_id) REFERENCES public.app_user(id);


--
-- Name: ca_alert_dismissal ca_alert_dismissal_ca_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_alert_dismissal
    ADD CONSTRAINT ca_alert_dismissal_ca_firm_id_fkey FOREIGN KEY (ca_firm_id) REFERENCES public.ca_firm(id);


--
-- Name: ca_alert_dismissal ca_alert_dismissal_dismissed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_alert_dismissal
    ADD CONSTRAINT ca_alert_dismissal_dismissed_by_fkey FOREIGN KEY (dismissed_by) REFERENCES public.app_user(id);


--
-- Name: ca_alert_dismissal ca_alert_dismissal_suggestion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_alert_dismissal
    ADD CONSTRAINT ca_alert_dismissal_suggestion_id_fkey FOREIGN KEY (suggestion_id) REFERENCES public.ai_suggestion(id);


--
-- Name: ca_client_link ca_client_link_assigned_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_client_link
    ADD CONSTRAINT ca_client_link_assigned_user_id_fkey FOREIGN KEY (assigned_user_id) REFERENCES public.app_user(id);


--
-- Name: ca_client_link ca_client_link_backup_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_client_link
    ADD CONSTRAINT ca_client_link_backup_user_id_fkey FOREIGN KEY (backup_user_id) REFERENCES public.app_user(id);


--
-- Name: ca_client_link ca_client_link_ca_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_client_link
    ADD CONSTRAINT ca_client_link_ca_firm_id_fkey FOREIGN KEY (ca_firm_id) REFERENCES public.ca_firm(id);


--
-- Name: ca_client_link ca_client_link_client_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_client_link
    ADD CONSTRAINT ca_client_link_client_org_id_fkey FOREIGN KEY (client_org_id) REFERENCES public.organisation(id);


--
-- Name: ca_client_link ca_client_link_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_client_link
    ADD CONSTRAINT ca_client_link_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id);


--
-- Name: ca_compliance_deadline ca_compliance_deadline_ca_client_link_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_compliance_deadline
    ADD CONSTRAINT ca_compliance_deadline_ca_client_link_id_fkey FOREIGN KEY (ca_client_link_id) REFERENCES public.ca_client_link(id);


--
-- Name: ca_compliance_deadline ca_compliance_deadline_client_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_compliance_deadline
    ADD CONSTRAINT ca_compliance_deadline_client_org_id_fkey FOREIGN KEY (client_org_id) REFERENCES public.organisation(id);


--
-- Name: ca_compliance_deadline ca_compliance_deadline_filed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_compliance_deadline
    ADD CONSTRAINT ca_compliance_deadline_filed_by_fkey FOREIGN KEY (filed_by) REFERENCES public.app_user(id);


--
-- Name: ca_firm ca_firm_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_firm
    ADD CONSTRAINT ca_firm_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: ca_report_dispatch ca_report_dispatch_ca_client_link_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_report_dispatch
    ADD CONSTRAINT ca_report_dispatch_ca_client_link_id_fkey FOREIGN KEY (ca_client_link_id) REFERENCES public.ca_client_link(id);


--
-- Name: ca_report_dispatch ca_report_dispatch_client_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_report_dispatch
    ADD CONSTRAINT ca_report_dispatch_client_org_id_fkey FOREIGN KEY (client_org_id) REFERENCES public.organisation(id);


--
-- Name: ca_report_dispatch ca_report_dispatch_dispatched_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ca_report_dispatch
    ADD CONSTRAINT ca_report_dispatch_dispatched_by_fkey FOREIGN KEY (dispatched_by) REFERENCES public.app_user(id);


--
-- Name: capa_action capa_ncr_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.capa_action
    ADD CONSTRAINT capa_ncr_fk FOREIGN KEY (ncr_id) REFERENCES public.non_conformance_report(id);


--
-- Name: consignment_settlement consignment_settlement_consignment_stock_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consignment_settlement
    ADD CONSTRAINT consignment_settlement_consignment_stock_id_fkey FOREIGN KEY (consignment_stock_id) REFERENCES public.consignment_stock(id);


--
-- Name: consignment_stock consignment_stock_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consignment_stock
    ADD CONSTRAINT consignment_stock_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: consignment_stock consignment_stock_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consignment_stock
    ADD CONSTRAINT consignment_stock_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: contact contact_default_price_list_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact
    ADD CONSTRAINT contact_default_price_list_id_fkey FOREIGN KEY (default_price_list_id) REFERENCES public.price_list(id);


--
-- Name: contact contact_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact
    ADD CONSTRAINT contact_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: contact_person contact_person_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_person
    ADD CONSTRAINT contact_person_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: credit_note credit_note_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_note
    ADD CONSTRAINT credit_note_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branch(id);


--
-- Name: credit_note credit_note_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_note
    ADD CONSTRAINT credit_note_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: credit_note credit_note_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_note
    ADD CONSTRAINT credit_note_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoice(id);


--
-- Name: credit_note credit_note_journal_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_note
    ADD CONSTRAINT credit_note_journal_entry_id_fkey FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entry(id);


--
-- Name: credit_note_line credit_note_line_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_note_line
    ADD CONSTRAINT credit_note_line_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.stock_batch(id);


--
-- Name: credit_note_line credit_note_line_credit_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_note_line
    ADD CONSTRAINT credit_note_line_credit_note_id_fkey FOREIGN KEY (credit_note_id) REFERENCES public.credit_note(id) ON DELETE CASCADE;


--
-- Name: credit_note_line credit_note_line_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_note_line
    ADD CONSTRAINT credit_note_line_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: credit_note_line credit_note_line_tax_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_note_line
    ADD CONSTRAINT credit_note_line_tax_group_id_fkey FOREIGN KEY (tax_group_id) REFERENCES public.tax_group(id);


--
-- Name: credit_note credit_note_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.credit_note
    ADD CONSTRAINT credit_note_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: day_close day_close_route_execution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.day_close
    ADD CONSTRAINT day_close_route_execution_id_fkey FOREIGN KEY (route_execution_id) REFERENCES public.route_execution(id);


--
-- Name: day_close day_close_van_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.day_close
    ADD CONSTRAINT day_close_van_id_fkey FOREIGN KEY (van_id) REFERENCES public.van(id);


--
-- Name: debit_note_line debit_note_line_debit_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.debit_note_line
    ADD CONSTRAINT debit_note_line_debit_note_id_fkey FOREIGN KEY (debit_note_id) REFERENCES public.debit_note(id) ON DELETE CASCADE;


--
-- Name: delegated_access_token delegated_access_token_ca_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delegated_access_token
    ADD CONSTRAINT delegated_access_token_ca_user_id_fkey FOREIGN KEY (ca_user_id) REFERENCES public.app_user(id);


--
-- Name: delegated_access_token delegated_access_token_client_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delegated_access_token
    ADD CONSTRAINT delegated_access_token_client_org_id_fkey FOREIGN KEY (client_org_id) REFERENCES public.organisation(id);


--
-- Name: delivery_challan delivery_challan_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_challan
    ADD CONSTRAINT delivery_challan_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branch(id);


--
-- Name: delivery_challan delivery_challan_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_challan
    ADD CONSTRAINT delivery_challan_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: delivery_challan delivery_challan_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_challan
    ADD CONSTRAINT delivery_challan_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id);


--
-- Name: delivery_challan_line delivery_challan_line_delivery_challan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_challan_line
    ADD CONSTRAINT delivery_challan_line_delivery_challan_id_fkey FOREIGN KEY (delivery_challan_id) REFERENCES public.delivery_challan(id) ON DELETE CASCADE;


--
-- Name: delivery_challan_line delivery_challan_line_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_challan_line
    ADD CONSTRAINT delivery_challan_line_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: delivery_challan_line delivery_challan_line_sales_order_line_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_challan_line
    ADD CONSTRAINT delivery_challan_line_sales_order_line_id_fkey FOREIGN KEY (sales_order_line_id) REFERENCES public.sales_order_line(id);


--
-- Name: delivery_challan delivery_challan_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_challan
    ADD CONSTRAINT delivery_challan_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: delivery_challan delivery_challan_sales_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_challan
    ADD CONSTRAINT delivery_challan_sales_order_id_fkey FOREIGN KEY (sales_order_id) REFERENCES public.sales_order(id);


--
-- Name: delivery_challan delivery_challan_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_challan
    ADD CONSTRAINT delivery_challan_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: demand_forecast demand_forecast_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.demand_forecast
    ADD CONSTRAINT demand_forecast_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: demand_forecast demand_forecast_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.demand_forecast
    ADD CONSTRAINT demand_forecast_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: demand_forecast demand_forecast_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.demand_forecast
    ADD CONSTRAINT demand_forecast_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: document_state_config document_state_config_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_state_config
    ADD CONSTRAINT document_state_config_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: domain_event domain_event_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_event
    ADD CONSTRAINT domain_event_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: domain_events domain_events_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.domain_events
    ADD CONSTRAINT domain_events_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: drug_interaction drug_interaction_interacting_salt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drug_interaction
    ADD CONSTRAINT drug_interaction_interacting_salt_id_fkey FOREIGN KEY (interacting_salt_id) REFERENCES public.salt_master(id);


--
-- Name: drug_interaction drug_interaction_primary_salt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drug_interaction
    ADD CONSTRAINT drug_interaction_primary_salt_id_fkey FOREIGN KEY (primary_salt_id) REFERENCES public.salt_master(id);


--
-- Name: drug_master drug_master_salt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drug_master
    ADD CONSTRAINT drug_master_salt_id_fkey FOREIGN KEY (salt_id) REFERENCES public.salt_master(id);


--
-- Name: email_template email_template_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_template
    ADD CONSTRAINT email_template_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: email_verification_token email_verification_token_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_verification_token
    ADD CONSTRAINT email_verification_token_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id);


--
-- Name: entity_attachment entity_attachment_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_attachment
    ADD CONSTRAINT entity_attachment_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: entity_attachment entity_attachment_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_attachment
    ADD CONSTRAINT entity_attachment_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.app_user(id);


--
-- Name: entity_comment entity_comment_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_comment
    ADD CONSTRAINT entity_comment_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id);


--
-- Name: entity_comment entity_comment_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_comment
    ADD CONSTRAINT entity_comment_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: entry_number_sequence entry_number_sequence_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entry_number_sequence
    ADD CONSTRAINT entry_number_sequence_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: estimate estimate_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estimate
    ADD CONSTRAINT estimate_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branch(id);


--
-- Name: estimate estimate_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estimate
    ADD CONSTRAINT estimate_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: estimate estimate_converted_to_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estimate
    ADD CONSTRAINT estimate_converted_to_invoice_id_fkey FOREIGN KEY (converted_to_invoice_id) REFERENCES public.invoice(id);


--
-- Name: estimate estimate_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estimate
    ADD CONSTRAINT estimate_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id);


--
-- Name: estimate_line estimate_line_estimate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estimate_line
    ADD CONSTRAINT estimate_line_estimate_id_fkey FOREIGN KEY (estimate_id) REFERENCES public.estimate(id) ON DELETE CASCADE;


--
-- Name: estimate_line estimate_line_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estimate_line
    ADD CONSTRAINT estimate_line_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: estimate estimate_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.estimate
    ADD CONSTRAINT estimate_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: expense expense_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense
    ADD CONSTRAINT expense_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.account(id);


--
-- Name: expense expense_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense
    ADD CONSTRAINT expense_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branch(id);


--
-- Name: expense expense_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense
    ADD CONSTRAINT expense_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: expense expense_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense
    ADD CONSTRAINT expense_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id);


--
-- Name: expense expense_customer_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense
    ADD CONSTRAINT expense_customer_contact_id_fkey FOREIGN KEY (customer_contact_id) REFERENCES public.contact(id);


--
-- Name: expense expense_journal_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense
    ADD CONSTRAINT expense_journal_entry_id_fkey FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entry(id);


--
-- Name: expense expense_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense
    ADD CONSTRAINT expense_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: expense expense_paid_through_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense
    ADD CONSTRAINT expense_paid_through_id_fkey FOREIGN KEY (paid_through_id) REFERENCES public.account(id);


--
-- Name: expense expense_tax_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expense
    ADD CONSTRAINT expense_tax_group_id_fkey FOREIGN KEY (tax_group_id) REFERENCES public.tax_group(id);


--
-- Name: field_sales_assignment field_sales_assignment_route_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.field_sales_assignment
    ADD CONSTRAINT field_sales_assignment_route_id_fkey FOREIGN KEY (route_id) REFERENCES public.route(id);


--
-- Name: field_sales_assignment field_sales_assignment_van_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.field_sales_assignment
    ADD CONSTRAINT field_sales_assignment_van_id_fkey FOREIGN KEY (van_id) REFERENCES public.van(id);


--
-- Name: field_visit field_visit_beat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.field_visit
    ADD CONSTRAINT field_visit_beat_id_fkey FOREIGN KEY (beat_id) REFERENCES public.beat(id);


--
-- Name: field_visit field_visit_route_execution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.field_visit
    ADD CONSTRAINT field_visit_route_execution_id_fkey FOREIGN KEY (route_execution_id) REFERENCES public.route_execution(id);


--
-- Name: fiscal_period fiscal_period_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fiscal_period
    ADD CONSTRAINT fiscal_period_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: app_user fk_app_user_ca_firm; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT fk_app_user_ca_firm FOREIGN KEY (ca_firm_id) REFERENCES public.ca_firm(id);


--
-- Name: cod_remittance_line fk_cod_remittance_line_remittance; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cod_remittance_line
    ADD CONSTRAINT fk_cod_remittance_line_remittance FOREIGN KEY (cod_remittance_id) REFERENCES public.cod_remittance(id);


--
-- Name: courier_shipment_event fk_courier_shipment_event_shipment; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courier_shipment_event
    ADD CONSTRAINT fk_courier_shipment_event_shipment FOREIGN KEY (courier_shipment_id) REFERENCES public.courier_shipment(id);


--
-- Name: employee fk_employee_org; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee
    ADD CONSTRAINT fk_employee_org FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: employee_salary_component fk_esc_component; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_salary_component
    ADD CONSTRAINT fk_esc_component FOREIGN KEY (salary_component_id) REFERENCES public.salary_component(id);


--
-- Name: employee_salary_component fk_esc_org; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_salary_component
    ADD CONSTRAINT fk_esc_org FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: employee_salary_component fk_esc_structure; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_salary_component
    ADD CONSTRAINT fk_esc_structure FOREIGN KEY (salary_structure_id) REFERENCES public.employee_salary_structure(id);


--
-- Name: employee_salary_structure fk_ess_employee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_salary_structure
    ADD CONSTRAINT fk_ess_employee FOREIGN KEY (employee_id) REFERENCES public.employee(id);


--
-- Name: employee_salary_structure fk_ess_org; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.employee_salary_structure
    ADD CONSTRAINT fk_ess_org FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: payroll_audit_log fk_payroll_audit_org; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payroll_audit_log
    ADD CONSTRAINT fk_payroll_audit_org FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: payroll_payment fk_payroll_payment_org; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payroll_payment
    ADD CONSTRAINT fk_payroll_payment_org FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: payroll_payment fk_payroll_payment_run; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payroll_payment
    ADD CONSTRAINT fk_payroll_payment_run FOREIGN KEY (payroll_run_id) REFERENCES public.payroll_run(id);


--
-- Name: payroll_run fk_payroll_run_org; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payroll_run
    ADD CONSTRAINT fk_payroll_run_org FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: payroll_settings fk_payroll_settings_org; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payroll_settings
    ADD CONSTRAINT fk_payroll_settings_org FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: payroll_document_snapshot fk_payroll_snapshot_org; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payroll_document_snapshot
    ADD CONSTRAINT fk_payroll_snapshot_org FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: payroll_document_snapshot fk_payroll_snapshot_run; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payroll_document_snapshot
    ADD CONSTRAINT fk_payroll_snapshot_run FOREIGN KEY (payroll_run_id) REFERENCES public.payroll_run(id);


--
-- Name: payslip fk_payslip_employee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payslip
    ADD CONSTRAINT fk_payslip_employee FOREIGN KEY (employee_id) REFERENCES public.employee(id);


--
-- Name: payslip_line fk_payslip_line_component; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payslip_line
    ADD CONSTRAINT fk_payslip_line_component FOREIGN KEY (salary_component_id) REFERENCES public.salary_component(id);


--
-- Name: payslip_line fk_payslip_line_org; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payslip_line
    ADD CONSTRAINT fk_payslip_line_org FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: payslip_line fk_payslip_line_payslip; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payslip_line
    ADD CONSTRAINT fk_payslip_line_payslip FOREIGN KEY (payslip_id) REFERENCES public.payslip(id);


--
-- Name: payslip fk_payslip_org; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payslip
    ADD CONSTRAINT fk_payslip_org FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: payslip fk_payslip_run; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payslip
    ADD CONSTRAINT fk_payslip_run FOREIGN KEY (payroll_run_id) REFERENCES public.payroll_run(id);


--
-- Name: reminder_log fk_reminder_log_contact; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reminder_log
    ADD CONSTRAINT fk_reminder_log_contact FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: reminder_log fk_reminder_log_org; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reminder_log
    ADD CONSTRAINT fk_reminder_log_org FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: salary_component fk_salary_component_org; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.salary_component
    ADD CONSTRAINT fk_salary_component_org FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: statutory_payment fk_statutory_payment_org; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.statutory_payment
    ADD CONSTRAINT fk_statutory_payment_org FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: generic_substitution generic_substitution_drug_master_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generic_substitution
    ADD CONSTRAINT generic_substitution_drug_master_id_fkey FOREIGN KEY (drug_master_id) REFERENCES public.drug_master(id);


--
-- Name: generic_substitution generic_substitution_substitute_drug_master_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generic_substitution
    ADD CONSTRAINT generic_substitution_substitute_drug_master_id_fkey FOREIGN KEY (substitute_drug_master_id) REFERENCES public.drug_master(id);


--
-- Name: industry_feature_config industry_feature_config_industry_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.industry_feature_config
    ADD CONSTRAINT industry_feature_config_industry_template_id_fkey FOREIGN KEY (industry_template_id) REFERENCES public.industry_template(id);


--
-- Name: industry_sub_category industry_sub_category_industry_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.industry_sub_category
    ADD CONSTRAINT industry_sub_category_industry_template_id_fkey FOREIGN KEY (industry_template_id) REFERENCES public.industry_template(id);


--
-- Name: integration_sync_log integration_sync_log_integration_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_sync_log
    ADD CONSTRAINT integration_sync_log_integration_id_fkey FOREIGN KEY (integration_id) REFERENCES public.integration_config(id);


--
-- Name: invoice invoice_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice
    ADD CONSTRAINT invoice_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branch(id);


--
-- Name: invoice invoice_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice
    ADD CONSTRAINT invoice_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: invoice invoice_journal_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice
    ADD CONSTRAINT invoice_journal_entry_id_fkey FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entry(id);


--
-- Name: invoice_line invoice_line_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_line
    ADD CONSTRAINT invoice_line_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.stock_batch(id);


--
-- Name: invoice_line invoice_line_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_line
    ADD CONSTRAINT invoice_line_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoice(id) ON DELETE CASCADE;


--
-- Name: invoice_line invoice_line_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_line
    ADD CONSTRAINT invoice_line_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: invoice_line invoice_line_tax_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_line
    ADD CONSTRAINT invoice_line_tax_group_id_fkey FOREIGN KEY (tax_group_id) REFERENCES public.tax_group(id);


--
-- Name: invoice_number_sequence invoice_number_sequence_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice_number_sequence
    ADD CONSTRAINT invoice_number_sequence_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: invoice invoice_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoice
    ADD CONSTRAINT invoice_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: item item_base_uom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item
    ADD CONSTRAINT item_base_uom_id_fkey FOREIGN KEY (base_uom_id) REFERENCES public.uom(id);


--
-- Name: item item_default_tax_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item
    ADD CONSTRAINT item_default_tax_group_id_fkey FOREIGN KEY (default_tax_group_id) REFERENCES public.tax_group(id);


--
-- Name: item item_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item
    ADD CONSTRAINT item_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.item_group(id);


--
-- Name: item_group item_group_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_group
    ADD CONSTRAINT item_group_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: item item_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item
    ADD CONSTRAINT item_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: item item_purchase_uom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item
    ADD CONSTRAINT item_purchase_uom_id_fkey FOREIGN KEY (purchase_uom_id) REFERENCES public.uom(id);


--
-- Name: item item_rack_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item
    ADD CONSTRAINT item_rack_location_id_fkey FOREIGN KEY (rack_location_id) REFERENCES public.rack_location(id);


--
-- Name: item_supplier item_supplier_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_supplier
    ADD CONSTRAINT item_supplier_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: item_supplier item_supplier_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_supplier
    ADD CONSTRAINT item_supplier_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: item_supplier item_supplier_supplier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_supplier
    ADD CONSTRAINT item_supplier_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.supplier(id);


--
-- Name: item_unit_price item_unit_price_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_unit_price
    ADD CONSTRAINT item_unit_price_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: item_unit_price item_unit_price_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_unit_price
    ADD CONSTRAINT item_unit_price_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: item_unit_price item_unit_price_uom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_unit_price
    ADD CONSTRAINT item_unit_price_uom_id_fkey FOREIGN KEY (uom_id) REFERENCES public.uom(id);


--
-- Name: job_card job_card_operation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_card
    ADD CONSTRAINT job_card_operation_id_fkey FOREIGN KEY (operation_id) REFERENCES public.operation(id);


--
-- Name: job_card job_card_work_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_card
    ADD CONSTRAINT job_card_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES public.work_order(id);


--
-- Name: job_card job_card_workstation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_card
    ADD CONSTRAINT job_card_workstation_id_fkey FOREIGN KEY (workstation_id) REFERENCES public.workstation(id);


--
-- Name: job_work_order_line job_work_order_line_job_work_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_work_order_line
    ADD CONSTRAINT job_work_order_line_job_work_order_id_fkey FOREIGN KEY (job_work_order_id) REFERENCES public.job_work_order(id);


--
-- Name: job_work_order job_work_order_work_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_work_order
    ADD CONSTRAINT job_work_order_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES public.work_order(id);


--
-- Name: journal_entry journal_entry_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry
    ADD CONSTRAINT journal_entry_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: journal_entry journal_entry_reversal_of_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry
    ADD CONSTRAINT journal_entry_reversal_of_id_fkey FOREIGN KEY (reversal_of_id) REFERENCES public.journal_entry(id);


--
-- Name: journal_line journal_line_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_line
    ADD CONSTRAINT journal_line_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.account(id);


--
-- Name: journal_line journal_line_journal_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_line
    ADD CONSTRAINT journal_line_journal_entry_id_fkey FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entry(id) ON DELETE RESTRICT;


--
-- Name: mrp_demand mrp_demand_mrp_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mrp_demand
    ADD CONSTRAINT mrp_demand_mrp_run_id_fkey FOREIGN KEY (mrp_run_id) REFERENCES public.mrp_run(id);


--
-- Name: mrp_supply mrp_supply_mrp_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mrp_supply
    ADD CONSTRAINT mrp_supply_mrp_run_id_fkey FOREIGN KEY (mrp_run_id) REFERENCES public.mrp_run(id);


--
-- Name: network_order_event network_order_event_network_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.network_order_event
    ADD CONSTRAINT network_order_event_network_order_id_fkey FOREIGN KEY (network_order_id) REFERENCES public.network_order(id);


--
-- Name: network_order_line network_order_line_catalog_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.network_order_line
    ADD CONSTRAINT network_order_line_catalog_item_id_fkey FOREIGN KEY (catalog_item_id) REFERENCES public.published_catalog_item(id);


--
-- Name: network_order_line network_order_line_network_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.network_order_line
    ADD CONSTRAINT network_order_line_network_order_id_fkey FOREIGN KEY (network_order_id) REFERENCES public.network_order(id);


--
-- Name: network_order network_order_trading_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.network_order
    ADD CONSTRAINT network_order_trading_partner_id_fkey FOREIGN KEY (trading_partner_id) REFERENCES public.trading_partner(id);


--
-- Name: non_conformance_report non_conformance_report_qc_inspection_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.non_conformance_report
    ADD CONSTRAINT non_conformance_report_qc_inspection_id_fkey FOREIGN KEY (qc_inspection_id) REFERENCES public.qc_inspection(id);


--
-- Name: notification notification_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT notification_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: notification notification_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT notification_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id);


--
-- Name: operation operation_default_workstation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operation
    ADD CONSTRAINT operation_default_workstation_id_fkey FOREIGN KEY (default_workstation_id) REFERENCES public.workstation(id);


--
-- Name: org_bootstrap_status org_bootstrap_status_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_bootstrap_status
    ADD CONSTRAINT org_bootstrap_status_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: org_default_account org_default_account_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_default_account
    ADD CONSTRAINT org_default_account_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.account(id);


--
-- Name: org_default_account org_default_account_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_default_account
    ADD CONSTRAINT org_default_account_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: org_feature_flag org_feature_flag_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_feature_flag
    ADD CONSTRAINT org_feature_flag_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: org_settings org_settings_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_settings
    ADD CONSTRAINT org_settings_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: password_reset_token password_reset_token_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_token
    ADD CONSTRAINT password_reset_token_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id);


--
-- Name: payment payment_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branch(id);


--
-- Name: payment payment_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: payment payment_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoice(id);


--
-- Name: payment payment_journal_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_journal_entry_id_fkey FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entry(id);


--
-- Name: payment_match payment_match_bank_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_match
    ADD CONSTRAINT payment_match_bank_transaction_id_fkey FOREIGN KEY (bank_transaction_id) REFERENCES public.bank_transaction(id) ON DELETE CASCADE;


--
-- Name: payment_match payment_match_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_match
    ADD CONSTRAINT payment_match_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: payment_match payment_match_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_match
    ADD CONSTRAINT payment_match_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoice(id);


--
-- Name: payment_match payment_match_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_match
    ADD CONSTRAINT payment_match_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: payment_match payment_match_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_match
    ADD CONSTRAINT payment_match_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payment(id);


--
-- Name: payment payment_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: period_balance period_balance_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.period_balance
    ADD CONSTRAINT period_balance_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.account(id);


--
-- Name: picklist_line picklist_line_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.picklist_line
    ADD CONSTRAINT picklist_line_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.stock_batch(id);


--
-- Name: picklist_line picklist_line_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.picklist_line
    ADD CONSTRAINT picklist_line_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: picklist_line picklist_line_picklist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.picklist_line
    ADD CONSTRAINT picklist_line_picklist_id_fkey FOREIGN KEY (picklist_id) REFERENCES public.picklist(id) ON DELETE CASCADE;


--
-- Name: picklist_line picklist_line_rack_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.picklist_line
    ADD CONSTRAINT picklist_line_rack_location_id_fkey FOREIGN KEY (rack_location_id) REFERENCES public.rack_location(id);


--
-- Name: picklist_line picklist_line_sales_order_line_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.picklist_line
    ADD CONSTRAINT picklist_line_sales_order_line_id_fkey FOREIGN KEY (sales_order_line_id) REFERENCES public.sales_order_line(id);


--
-- Name: picklist picklist_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.picklist
    ADD CONSTRAINT picklist_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: picklist picklist_sales_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.picklist
    ADD CONSTRAINT picklist_sales_order_id_fkey FOREIGN KEY (sales_order_id) REFERENCES public.sales_order(id);


--
-- Name: picklist picklist_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.picklist
    ADD CONSTRAINT picklist_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: planned_order planned_order_mrp_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planned_order
    ADD CONSTRAINT planned_order_mrp_run_id_fkey FOREIGN KEY (mrp_run_id) REFERENCES public.mrp_run(id);


--
-- Name: platform_admin_audit platform_admin_audit_platform_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_admin_audit
    ADD CONSTRAINT platform_admin_audit_platform_admin_id_fkey FOREIGN KEY (platform_admin_id) REFERENCES public.platform_admin(id);


--
-- Name: pos_cash_expense pos_cash_expense_register_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pos_cash_expense
    ADD CONSTRAINT pos_cash_expense_register_id_fkey FOREIGN KEY (register_id) REFERENCES public.pos_cash_register(id) ON DELETE CASCADE;


--
-- Name: posted_document_snapshot posted_document_snapshot_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posted_document_snapshot
    ADD CONSTRAINT posted_document_snapshot_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: prescription_record_item prescription_record_item_prescription_record_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.prescription_record_item
    ADD CONSTRAINT prescription_record_item_prescription_record_id_fkey FOREIGN KEY (prescription_record_id) REFERENCES public.prescription_record(id) ON DELETE CASCADE;


--
-- Name: price_list_item price_list_item_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list_item
    ADD CONSTRAINT price_list_item_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: price_list_item price_list_item_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list_item
    ADD CONSTRAINT price_list_item_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: price_list_item price_list_item_price_list_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list_item
    ADD CONSTRAINT price_list_item_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_list(id);


--
-- Name: price_list price_list_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list
    ADD CONSTRAINT price_list_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: production_cost_summary production_cost_summary_work_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_cost_summary
    ADD CONSTRAINT production_cost_summary_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES public.work_order(id);


--
-- Name: production_scrap production_scrap_job_card_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_scrap
    ADD CONSTRAINT production_scrap_job_card_id_fkey FOREIGN KEY (job_card_id) REFERENCES public.job_card(id);


--
-- Name: production_scrap production_scrap_reason_code_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_scrap
    ADD CONSTRAINT production_scrap_reason_code_id_fkey FOREIGN KEY (reason_code_id) REFERENCES public.scrap_reason_code(id);


--
-- Name: production_scrap production_scrap_work_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_scrap
    ADD CONSTRAINT production_scrap_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES public.work_order(id);


--
-- Name: purchase_bill purchase_bill_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_bill
    ADD CONSTRAINT purchase_bill_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branch(id);


--
-- Name: purchase_bill purchase_bill_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_bill
    ADD CONSTRAINT purchase_bill_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: purchase_bill purchase_bill_journal_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_bill
    ADD CONSTRAINT purchase_bill_journal_entry_id_fkey FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entry(id);


--
-- Name: purchase_bill_line purchase_bill_line_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_bill_line
    ADD CONSTRAINT purchase_bill_line_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.account(id);


--
-- Name: purchase_bill_line purchase_bill_line_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_bill_line
    ADD CONSTRAINT purchase_bill_line_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: purchase_bill_line purchase_bill_line_purchase_bill_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_bill_line
    ADD CONSTRAINT purchase_bill_line_purchase_bill_id_fkey FOREIGN KEY (purchase_bill_id) REFERENCES public.purchase_bill(id) ON DELETE CASCADE;


--
-- Name: purchase_bill_line purchase_bill_line_tax_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_bill_line
    ADD CONSTRAINT purchase_bill_line_tax_group_id_fkey FOREIGN KEY (tax_group_id) REFERENCES public.tax_group(id);


--
-- Name: purchase_bill_line purchase_bill_line_unit_uom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_bill_line
    ADD CONSTRAINT purchase_bill_line_unit_uom_id_fkey FOREIGN KEY (unit_uom_id) REFERENCES public.uom(id);


--
-- Name: purchase_bill purchase_bill_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_bill
    ADD CONSTRAINT purchase_bill_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: purchase_order_lines purchase_order_lines_po_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_order_lines
    ADD CONSTRAINT purchase_order_lines_po_id_fkey FOREIGN KEY (po_id) REFERENCES public.purchase_orders(id) ON DELETE CASCADE;


--
-- Name: purchase_requisition_line purchase_requisition_line_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_requisition_line
    ADD CONSTRAINT purchase_requisition_line_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: purchase_requisition_line purchase_requisition_line_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_requisition_line
    ADD CONSTRAINT purchase_requisition_line_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: purchase_requisition_line purchase_requisition_line_requisition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_requisition_line
    ADD CONSTRAINT purchase_requisition_line_requisition_id_fkey FOREIGN KEY (requisition_id) REFERENCES public.purchase_requisition(id);


--
-- Name: purchase_requisition purchase_requisition_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_requisition
    ADD CONSTRAINT purchase_requisition_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: purchase_requisition purchase_requisition_supplier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_requisition
    ADD CONSTRAINT purchase_requisition_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.supplier(id);


--
-- Name: purchase_requisition purchase_requisition_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.purchase_requisition
    ADD CONSTRAINT purchase_requisition_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: qc_inspection_result qc_inspection_result_inspection_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qc_inspection_result
    ADD CONSTRAINT qc_inspection_result_inspection_id_fkey FOREIGN KEY (inspection_id) REFERENCES public.qc_inspection(id);


--
-- Name: qc_inspection_result qc_inspection_result_parameter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qc_inspection_result
    ADD CONSTRAINT qc_inspection_result_parameter_id_fkey FOREIGN KEY (parameter_id) REFERENCES public.qc_parameter(id);


--
-- Name: qc_inspection qc_inspection_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qc_inspection
    ADD CONSTRAINT qc_inspection_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.qc_template(id);


--
-- Name: qc_parameter qc_parameter_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qc_parameter
    ADD CONSTRAINT qc_parameter_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.qc_template(id);


--
-- Name: recurring_invoice recurring_invoice_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_invoice
    ADD CONSTRAINT recurring_invoice_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: recurring_invoice recurring_invoice_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_invoice
    ADD CONSTRAINT recurring_invoice_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id);


--
-- Name: recurring_invoice_generation recurring_invoice_generation_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_invoice_generation
    ADD CONSTRAINT recurring_invoice_generation_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoice(id);


--
-- Name: recurring_invoice_generation recurring_invoice_generation_recurring_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_invoice_generation
    ADD CONSTRAINT recurring_invoice_generation_recurring_invoice_id_fkey FOREIGN KEY (recurring_invoice_id) REFERENCES public.recurring_invoice(id) ON DELETE CASCADE;


--
-- Name: recurring_invoice recurring_invoice_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recurring_invoice
    ADD CONSTRAINT recurring_invoice_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: refresh_token refresh_token_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_token
    ADD CONSTRAINT refresh_token_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id);


--
-- Name: reminder_log reminder_log_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reminder_log
    ADD CONSTRAINT reminder_log_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: reminder_log reminder_log_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reminder_log
    ADD CONSTRAINT reminder_log_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: reorder_policy reorder_policy_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reorder_policy
    ADD CONSTRAINT reorder_policy_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: reorder_policy reorder_policy_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reorder_policy
    ADD CONSTRAINT reorder_policy_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: reorder_policy reorder_policy_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reorder_policy
    ADD CONSTRAINT reorder_policy_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: return_order_line return_order_line_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.return_order_line
    ADD CONSTRAINT return_order_line_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: return_order_line return_order_line_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.return_order_line
    ADD CONSTRAINT return_order_line_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: return_order_line return_order_line_return_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.return_order_line
    ADD CONSTRAINT return_order_line_return_order_id_fkey FOREIGN KEY (return_order_id) REFERENCES public.return_order(id);


--
-- Name: return_order return_order_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.return_order
    ADD CONSTRAINT return_order_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: return_order return_order_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.return_order
    ADD CONSTRAINT return_order_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: route_beat route_beat_beat_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.route_beat
    ADD CONSTRAINT route_beat_beat_id_fkey FOREIGN KEY (beat_id) REFERENCES public.beat(id);


--
-- Name: route_beat route_beat_route_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.route_beat
    ADD CONSTRAINT route_beat_route_id_fkey FOREIGN KEY (route_id) REFERENCES public.route(id);


--
-- Name: route_execution route_execution_route_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.route_execution
    ADD CONSTRAINT route_execution_route_id_fkey FOREIGN KEY (route_id) REFERENCES public.route(id);


--
-- Name: route_execution route_execution_van_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.route_execution
    ADD CONSTRAINT route_execution_van_id_fkey FOREIGN KEY (van_id) REFERENCES public.van(id);


--
-- Name: routing_operation_dependency routing_operation_dependency_op_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routing_operation_dependency
    ADD CONSTRAINT routing_operation_dependency_op_fkey FOREIGN KEY (routing_operation_id) REFERENCES public.routing_operation(id);


--
-- Name: routing_operation_dependency routing_operation_dependency_pred_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routing_operation_dependency
    ADD CONSTRAINT routing_operation_dependency_pred_fkey FOREIGN KEY (predecessor_routing_operation_id) REFERENCES public.routing_operation(id);


--
-- Name: routing_operation routing_operation_operation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routing_operation
    ADD CONSTRAINT routing_operation_operation_id_fkey FOREIGN KEY (operation_id) REFERENCES public.operation(id);


--
-- Name: routing_operation routing_operation_routing_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routing_operation
    ADD CONSTRAINT routing_operation_routing_id_fkey FOREIGN KEY (routing_id) REFERENCES public.routing(id);


--
-- Name: routing_operation routing_operation_workstation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routing_operation
    ADD CONSTRAINT routing_operation_workstation_id_fkey FOREIGN KEY (workstation_id) REFERENCES public.workstation(id);


--
-- Name: sales_order sales_order_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_order
    ADD CONSTRAINT sales_order_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branch(id);


--
-- Name: sales_order sales_order_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_order
    ADD CONSTRAINT sales_order_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: sales_order sales_order_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_order
    ADD CONSTRAINT sales_order_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id);


--
-- Name: sales_order sales_order_estimate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_order
    ADD CONSTRAINT sales_order_estimate_id_fkey FOREIGN KEY (estimate_id) REFERENCES public.estimate(id);


--
-- Name: sales_order_line sales_order_line_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_order_line
    ADD CONSTRAINT sales_order_line_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: sales_order_line sales_order_line_sales_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_order_line
    ADD CONSTRAINT sales_order_line_sales_order_id_fkey FOREIGN KEY (sales_order_id) REFERENCES public.sales_order(id) ON DELETE CASCADE;


--
-- Name: sales_order_line sales_order_line_tax_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_order_line
    ADD CONSTRAINT sales_order_line_tax_group_id_fkey FOREIGN KEY (tax_group_id) REFERENCES public.tax_group(id);


--
-- Name: sales_order sales_order_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_order
    ADD CONSTRAINT sales_order_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: sales_receipt sales_receipt_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_receipt
    ADD CONSTRAINT sales_receipt_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branch(id);


--
-- Name: sales_receipt sales_receipt_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_receipt
    ADD CONSTRAINT sales_receipt_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: sales_receipt sales_receipt_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_receipt
    ADD CONSTRAINT sales_receipt_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id);


--
-- Name: sales_receipt sales_receipt_journal_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_receipt
    ADD CONSTRAINT sales_receipt_journal_entry_id_fkey FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entry(id);


--
-- Name: sales_receipt_line sales_receipt_line_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_receipt_line
    ADD CONSTRAINT sales_receipt_line_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.stock_batch(id);


--
-- Name: sales_receipt_line sales_receipt_line_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_receipt_line
    ADD CONSTRAINT sales_receipt_line_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: sales_receipt_line sales_receipt_line_receipt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_receipt_line
    ADD CONSTRAINT sales_receipt_line_receipt_id_fkey FOREIGN KEY (receipt_id) REFERENCES public.sales_receipt(id) ON DELETE CASCADE;


--
-- Name: sales_receipt_line sales_receipt_line_stock_movement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_receipt_line
    ADD CONSTRAINT sales_receipt_line_stock_movement_id_fkey FOREIGN KEY (stock_movement_id) REFERENCES public.stock_movement(id);


--
-- Name: sales_receipt_line sales_receipt_line_tax_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_receipt_line
    ADD CONSTRAINT sales_receipt_line_tax_group_id_fkey FOREIGN KEY (tax_group_id) REFERENCES public.tax_group(id);


--
-- Name: sales_receipt_line sales_receipt_line_unit_uom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_receipt_line
    ADD CONSTRAINT sales_receipt_line_unit_uom_id_fkey FOREIGN KEY (unit_uom_id) REFERENCES public.uom(id);


--
-- Name: sales_receipt sales_receipt_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_receipt
    ADD CONSTRAINT sales_receipt_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: sales_receipt sales_receipt_paid_through_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sales_receipt
    ADD CONSTRAINT sales_receipt_paid_through_id_fkey FOREIGN KEY (paid_through_id) REFERENCES public.account(id);


--
-- Name: schemes schemes_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schemes
    ADD CONSTRAINT schemes_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: schemes schemes_supplier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schemes
    ADD CONSTRAINT schemes_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.supplier(id);


--
-- Name: serial_number serial_number_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.serial_number
    ADD CONSTRAINT serial_number_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.stock_batch(id);


--
-- Name: serial_number serial_number_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.serial_number
    ADD CONSTRAINT serial_number_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: serial_number serial_number_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.serial_number
    ADD CONSTRAINT serial_number_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: serial_number serial_number_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.serial_number
    ADD CONSTRAINT serial_number_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: shipment_line shipment_line_shipment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shipment_line
    ADD CONSTRAINT shipment_line_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id);


--
-- Name: stock_balance stock_balance_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_balance
    ADD CONSTRAINT stock_balance_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branch(id);


--
-- Name: stock_balance stock_balance_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_balance
    ADD CONSTRAINT stock_balance_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: stock_balance stock_balance_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_balance
    ADD CONSTRAINT stock_balance_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: stock_balance stock_balance_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_balance
    ADD CONSTRAINT stock_balance_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: stock_batch_balance stock_batch_balance_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_batch_balance
    ADD CONSTRAINT stock_batch_balance_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.stock_batch(id);


--
-- Name: stock_batch_balance stock_batch_balance_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_batch_balance
    ADD CONSTRAINT stock_batch_balance_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: stock_batch_balance stock_batch_balance_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_batch_balance
    ADD CONSTRAINT stock_batch_balance_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: stock_batch stock_batch_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_batch
    ADD CONSTRAINT stock_batch_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: stock_batch stock_batch_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_batch
    ADD CONSTRAINT stock_batch_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: stock_batch stock_batch_supplier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_batch
    ADD CONSTRAINT stock_batch_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.supplier(id);


--
-- Name: stock_count_line stock_count_line_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_count_line
    ADD CONSTRAINT stock_count_line_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: stock_count_line stock_count_line_stock_count_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_count_line
    ADD CONSTRAINT stock_count_line_stock_count_id_fkey FOREIGN KEY (stock_count_id) REFERENCES public.stock_count(id) ON DELETE CASCADE;


--
-- Name: stock_count stock_count_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_count
    ADD CONSTRAINT stock_count_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: stock_count stock_count_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_count
    ADD CONSTRAINT stock_count_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: stock_movement stock_movement_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.stock_batch(id);


--
-- Name: stock_movement stock_movement_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branch(id);


--
-- Name: stock_movement stock_movement_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: stock_movement stock_movement_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: stock_movement stock_movement_reversal_of_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_reversal_of_id_fkey FOREIGN KEY (reversal_of_id) REFERENCES public.stock_movement(id);


--
-- Name: stock_movement stock_movement_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movement
    ADD CONSTRAINT stock_movement_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: stock_receipt stock_receipt_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_receipt
    ADD CONSTRAINT stock_receipt_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branch(id);


--
-- Name: stock_receipt_line stock_receipt_line_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_receipt_line
    ADD CONSTRAINT stock_receipt_line_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.stock_batch(id);


--
-- Name: stock_receipt_line stock_receipt_line_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_receipt_line
    ADD CONSTRAINT stock_receipt_line_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: stock_receipt_line stock_receipt_line_receipt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_receipt_line
    ADD CONSTRAINT stock_receipt_line_receipt_id_fkey FOREIGN KEY (receipt_id) REFERENCES public.stock_receipt(id) ON DELETE CASCADE;


--
-- Name: stock_receipt_line stock_receipt_line_stock_movement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_receipt_line
    ADD CONSTRAINT stock_receipt_line_stock_movement_id_fkey FOREIGN KEY (stock_movement_id) REFERENCES public.stock_movement(id);


--
-- Name: stock_receipt stock_receipt_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_receipt
    ADD CONSTRAINT stock_receipt_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: stock_receipt stock_receipt_supplier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_receipt
    ADD CONSTRAINT stock_receipt_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.supplier(id);


--
-- Name: stock_receipt stock_receipt_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_receipt
    ADD CONSTRAINT stock_receipt_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: stock_reservation stock_reservation_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_reservation
    ADD CONSTRAINT stock_reservation_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: stock_reservation stock_reservation_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_reservation
    ADD CONSTRAINT stock_reservation_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: stock_reservation stock_reservation_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_reservation
    ADD CONSTRAINT stock_reservation_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: supplier supplier_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier
    ADD CONSTRAINT supplier_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: supplier_performance supplier_performance_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_performance
    ADD CONSTRAINT supplier_performance_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: supplier_performance supplier_performance_supplier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_performance
    ADD CONSTRAINT supplier_performance_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES public.supplier(id);


--
-- Name: supply_chain_alert supply_chain_alert_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supply_chain_alert
    ADD CONSTRAINT supply_chain_alert_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: tax_configuration tax_configuration_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tax_configuration
    ADD CONSTRAINT tax_configuration_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: tax_group tax_group_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tax_group
    ADD CONSTRAINT tax_group_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: tax_group_rate tax_group_rate_tax_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tax_group_rate
    ADD CONSTRAINT tax_group_rate_tax_group_id_fkey FOREIGN KEY (tax_group_id) REFERENCES public.tax_group(id) ON DELETE CASCADE;


--
-- Name: tax_group_rate tax_group_rate_tax_rate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tax_group_rate
    ADD CONSTRAINT tax_group_rate_tax_rate_id_fkey FOREIGN KEY (tax_rate_id) REFERENCES public.tax_rate(id);


--
-- Name: tax_line_item tax_line_item_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tax_line_item
    ADD CONSTRAINT tax_line_item_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: tax_rate tax_rate_gl_input_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tax_rate
    ADD CONSTRAINT tax_rate_gl_input_account_id_fkey FOREIGN KEY (gl_input_account_id) REFERENCES public.account(id);


--
-- Name: tax_rate tax_rate_gl_output_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tax_rate
    ADD CONSTRAINT tax_rate_gl_output_account_id_fkey FOREIGN KEY (gl_output_account_id) REFERENCES public.account(id);


--
-- Name: tax_rate tax_rate_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tax_rate
    ADD CONSTRAINT tax_rate_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: tax_rate tax_rate_tax_config_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tax_rate
    ADD CONSTRAINT tax_rate_tax_config_id_fkey FOREIGN KEY (tax_config_id) REFERENCES public.tax_configuration(id);


--
-- Name: tour_plan_entry tour_plan_entry_tour_plan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tour_plan_entry
    ADD CONSTRAINT tour_plan_entry_tour_plan_id_fkey FOREIGN KEY (tour_plan_id) REFERENCES public.tour_plan(id);


--
-- Name: transfer_order transfer_order_from_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfer_order
    ADD CONSTRAINT transfer_order_from_warehouse_id_fkey FOREIGN KEY (from_warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: transfer_order_line transfer_order_line_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfer_order_line
    ADD CONSTRAINT transfer_order_line_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES public.stock_batch(id);


--
-- Name: transfer_order_line transfer_order_line_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfer_order_line
    ADD CONSTRAINT transfer_order_line_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: transfer_order_line transfer_order_line_transfer_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfer_order_line
    ADD CONSTRAINT transfer_order_line_transfer_order_id_fkey FOREIGN KEY (transfer_order_id) REFERENCES public.transfer_order(id) ON DELETE CASCADE;


--
-- Name: transfer_order transfer_order_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfer_order
    ADD CONSTRAINT transfer_order_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: transfer_order transfer_order_to_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transfer_order
    ADD CONSTRAINT transfer_order_to_warehouse_id_fkey FOREIGN KEY (to_warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: uom_conversion uom_conversion_from_uom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uom_conversion
    ADD CONSTRAINT uom_conversion_from_uom_id_fkey FOREIGN KEY (from_uom_id) REFERENCES public.uom(id);


--
-- Name: uom_conversion uom_conversion_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uom_conversion
    ADD CONSTRAINT uom_conversion_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: uom_conversion uom_conversion_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uom_conversion
    ADD CONSTRAINT uom_conversion_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: uom_conversion uom_conversion_to_uom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uom_conversion
    ADD CONSTRAINT uom_conversion_to_uom_id_fkey FOREIGN KEY (to_uom_id) REFERENCES public.uom(id);


--
-- Name: uom uom_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uom
    ADD CONSTRAINT uom_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: user_invitation user_invitation_invited_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_invitation
    ADD CONSTRAINT user_invitation_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES public.app_user(id);


--
-- Name: user_invitation user_invitation_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_invitation
    ADD CONSTRAINT user_invitation_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: van_stock_balance van_stock_balance_van_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.van_stock_balance
    ADD CONSTRAINT van_stock_balance_van_id_fkey FOREIGN KEY (van_id) REFERENCES public.van(id);


--
-- Name: van_stock_transfer_line van_stock_transfer_line_van_stock_transfer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.van_stock_transfer_line
    ADD CONSTRAINT van_stock_transfer_line_van_stock_transfer_id_fkey FOREIGN KEY (van_stock_transfer_id) REFERENCES public.van_stock_transfer(id);


--
-- Name: van_stock_transfer van_stock_transfer_route_execution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.van_stock_transfer
    ADD CONSTRAINT van_stock_transfer_route_execution_id_fkey FOREIGN KEY (route_execution_id) REFERENCES public.route_execution(id);


--
-- Name: van_stock_transfer van_stock_transfer_van_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.van_stock_transfer
    ADD CONSTRAINT van_stock_transfer_van_id_fkey FOREIGN KEY (van_id) REFERENCES public.van(id);


--
-- Name: vendor_credit_application vendor_credit_application_purchase_bill_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_credit_application
    ADD CONSTRAINT vendor_credit_application_purchase_bill_id_fkey FOREIGN KEY (purchase_bill_id) REFERENCES public.purchase_bill(id);


--
-- Name: vendor_credit_application vendor_credit_application_vendor_credit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_credit_application
    ADD CONSTRAINT vendor_credit_application_vendor_credit_id_fkey FOREIGN KEY (vendor_credit_id) REFERENCES public.vendor_credit(id);


--
-- Name: vendor_credit vendor_credit_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_credit
    ADD CONSTRAINT vendor_credit_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branch(id);


--
-- Name: vendor_credit vendor_credit_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_credit
    ADD CONSTRAINT vendor_credit_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: vendor_credit vendor_credit_journal_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_credit
    ADD CONSTRAINT vendor_credit_journal_entry_id_fkey FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entry(id);


--
-- Name: vendor_credit_line vendor_credit_line_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_credit_line
    ADD CONSTRAINT vendor_credit_line_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.account(id);


--
-- Name: vendor_credit_line vendor_credit_line_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_credit_line
    ADD CONSTRAINT vendor_credit_line_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: vendor_credit_line vendor_credit_line_tax_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_credit_line
    ADD CONSTRAINT vendor_credit_line_tax_group_id_fkey FOREIGN KEY (tax_group_id) REFERENCES public.tax_group(id);


--
-- Name: vendor_credit_line vendor_credit_line_vendor_credit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_credit_line
    ADD CONSTRAINT vendor_credit_line_vendor_credit_id_fkey FOREIGN KEY (vendor_credit_id) REFERENCES public.vendor_credit(id) ON DELETE CASCADE;


--
-- Name: vendor_credit vendor_credit_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_credit
    ADD CONSTRAINT vendor_credit_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: vendor_credit vendor_credit_purchase_bill_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_credit
    ADD CONSTRAINT vendor_credit_purchase_bill_id_fkey FOREIGN KEY (purchase_bill_id) REFERENCES public.purchase_bill(id);


--
-- Name: vendor_payment_allocation vendor_payment_allocation_purchase_bill_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_payment_allocation
    ADD CONSTRAINT vendor_payment_allocation_purchase_bill_id_fkey FOREIGN KEY (purchase_bill_id) REFERENCES public.purchase_bill(id);


--
-- Name: vendor_payment_allocation vendor_payment_allocation_vendor_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_payment_allocation
    ADD CONSTRAINT vendor_payment_allocation_vendor_payment_id_fkey FOREIGN KEY (vendor_payment_id) REFERENCES public.vendor_payment(id) ON DELETE CASCADE;


--
-- Name: vendor_payment vendor_payment_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_payment
    ADD CONSTRAINT vendor_payment_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branch(id);


--
-- Name: vendor_payment vendor_payment_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_payment
    ADD CONSTRAINT vendor_payment_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: vendor_payment vendor_payment_journal_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_payment
    ADD CONSTRAINT vendor_payment_journal_entry_id_fkey FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entry(id);


--
-- Name: vendor_payment vendor_payment_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_payment
    ADD CONSTRAINT vendor_payment_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: vendor_payment vendor_payment_paid_through_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vendor_payment
    ADD CONSTRAINT vendor_payment_paid_through_id_fkey FOREIGN KEY (paid_through_id) REFERENCES public.account(id);


--
-- Name: visit_detail_aid_log visit_detail_aid_log_detail_aid_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visit_detail_aid_log
    ADD CONSTRAINT visit_detail_aid_log_detail_aid_id_fkey FOREIGN KEY (detail_aid_id) REFERENCES public.detail_aid(id);


--
-- Name: wallet_transaction wallet_transaction_wallet_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_transaction
    ADD CONSTRAINT wallet_transaction_wallet_id_fkey FOREIGN KEY (wallet_id) REFERENCES public.customer_wallet(id);


--
-- Name: warehouse warehouse_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warehouse
    ADD CONSTRAINT warehouse_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branch(id);


--
-- Name: warehouse warehouse_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.warehouse
    ADD CONSTRAINT warehouse_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: work_order work_order_finished_good_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_order
    ADD CONSTRAINT work_order_finished_good_id_fkey FOREIGN KEY (finished_good_id) REFERENCES public.item(id);


--
-- Name: work_order_line work_order_line_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_order_line
    ADD CONSTRAINT work_order_line_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item(id);


--
-- Name: work_order_line work_order_line_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_order_line
    ADD CONSTRAINT work_order_line_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: work_order_line work_order_line_work_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_order_line
    ADD CONSTRAINT work_order_line_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES public.work_order(id);


--
-- Name: work_order work_order_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_order
    ADD CONSTRAINT work_order_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: work_order work_order_warehouse_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_order
    ADD CONSTRAINT work_order_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id);


--
-- Name: workflow_definition workflow_definition_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflow_definition
    ADD CONSTRAINT workflow_definition_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: workflow_step workflow_step_approver_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflow_step
    ADD CONSTRAINT workflow_step_approver_user_id_fkey FOREIGN KEY (approver_user_id) REFERENCES public.app_user(id);


--
-- Name: workflow_step workflow_step_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflow_step
    ADD CONSTRAINT workflow_step_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organisation(id);


--
-- Name: workflow_step workflow_step_workflow_definition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workflow_step
    ADD CONSTRAINT workflow_step_workflow_definition_id_fkey FOREIGN KEY (workflow_definition_id) REFERENCES public.workflow_definition(id) ON DELETE CASCADE;


--
-- Name: workstation_alternate workstation_alternate_op_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workstation_alternate
    ADD CONSTRAINT workstation_alternate_op_fkey FOREIGN KEY (routing_operation_id) REFERENCES public.routing_operation(id);


--
-- Name: workstation_alternate workstation_alternate_ws_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workstation_alternate
    ADD CONSTRAINT workstation_alternate_ws_fkey FOREIGN KEY (workstation_id) REFERENCES public.workstation(id);


--
-- PostgreSQL database dump complete
--



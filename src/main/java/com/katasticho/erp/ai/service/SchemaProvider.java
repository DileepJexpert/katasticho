package com.katasticho.erp.ai.service;

import org.springframework.stereotype.Component;

/**
 * Provides the database schema description for Claude's SQL generation.
 * Only includes the tables/columns that are safe for AI read queries.
 * Never exposes auth/credential tables.
 */
@Component
public class SchemaProvider {

    /**
     * Returns a text description of the schema that Claude uses for SQL generation.
     * Filtered to only include financial/business tables.
     */
    public String getSchemaDescription() {
        return """
                PostgreSQL database schema (all tables have org_id UUID column for multi-tenancy):

                -- Chart of Accounts
                account (id UUID PK, org_id UUID, code VARCHAR, name VARCHAR, type VARCHAR [ASSET/LIABILITY/EQUITY/REVENUE/EXPENSE], parent_id UUID, is_deleted BOOLEAN, created_at TIMESTAMP)

                -- Journal Entries (immutable ledger)
                journal_entry (id UUID PK, org_id UUID, entry_number VARCHAR, effective_date DATE, description TEXT, source_module VARCHAR, status VARCHAR [DRAFT/POSTED/REVERSED], posted_at TIMESTAMP, created_at TIMESTAMP)
                journal_line (id UUID PK, org_id UUID, journal_entry_id UUID FK, account_id UUID FK, description TEXT, currency VARCHAR, exchange_rate DECIMAL, debit DECIMAL, credit DECIMAL, base_debit DECIMAL, base_credit DECIMAL)

                -- Customers
                customer (id UUID PK, org_id UUID, name VARCHAR, gstin VARCHAR, pan VARCHAR, billing_address_line1 TEXT, billing_city VARCHAR, billing_state VARCHAR, billing_state_code VARCHAR, billing_pincode VARCHAR, credit_limit DECIMAL, payment_terms_days INT, is_deleted BOOLEAN, created_at TIMESTAMP)

                -- Invoices (AR)
                invoice (id UUID PK, org_id UUID, invoice_number VARCHAR, customer_id UUID FK, invoice_date DATE, due_date DATE, status VARCHAR [DRAFT/SENT/PARTIALLY_PAID/PAID/CANCELLED/OVERDUE], currency VARCHAR, subtotal DECIMAL, tax_total DECIMAL, total DECIMAL, amount_paid DECIMAL, balance_due DECIMAL, base_subtotal DECIMAL, base_tax_total DECIMAL, base_total DECIMAL, journal_entry_id UUID, notes TEXT, created_at TIMESTAMP)
                invoice_line (id UUID PK, org_id UUID, invoice_id UUID FK, line_number INT, description TEXT, hsn_code VARCHAR, quantity DECIMAL, unit_price DECIMAL, discount_percent DECIMAL, taxable_amount DECIMAL, gst_rate DECIMAL, tax_amount DECIMAL, line_total DECIMAL, account_code VARCHAR)

                -- Payments
                payment (id UUID PK, org_id UUID, invoice_id UUID FK, payment_number VARCHAR, payment_date DATE, amount DECIMAL, currency VARCHAR, base_amount DECIMAL, payment_method VARCHAR [CASH/BANK_TRANSFER/UPI/CHEQUE/CARD/OTHER], reference_number VARCHAR, journal_entry_id UUID, created_at TIMESTAMP)

                -- Credit Notes
                credit_note (id UUID PK, org_id UUID, credit_note_number VARCHAR, customer_id UUID FK, invoice_id UUID, issue_date DATE, status VARCHAR [DRAFT/ISSUED/APPLIED/CANCELLED], subtotal DECIMAL, tax_total DECIMAL, total DECIMAL, reason TEXT, journal_entry_id UUID, created_at TIMESTAMP)

                -- Tax Line Items
                tax_line_item (id UUID PK, org_id UUID, source_type VARCHAR, source_id UUID, component_code VARCHAR [CGST/SGST/IGST], rate DECIMAL, taxable_amount DECIMAL, tax_amount DECIMAL, account_code VARCHAR)

                -- Organisation
                organisation (id UUID PK, name VARCHAR, country VARCHAR, base_currency VARCHAR, tax_regime VARCHAR, gstin VARCHAR, industry VARCHAR, created_at TIMESTAMP)

                Key relationships:
                - journal_line.account_id → account.id
                - journal_line.journal_entry_id → journal_entry.id
                - invoice.customer_id → customer.id
                - invoice_line.invoice_id → invoice.id
                - payment.invoice_id → invoice.id
                - credit_note.customer_id → customer.id

                Important conventions:
                - ALL monetary amounts in base currency use base_debit/base_credit (journal) or base_* columns
                - Account types: ASSET and EXPENSE are debit-normal; LIABILITY, EQUITY, REVENUE are credit-normal
                - For positive balances: ASSET/EXPENSE = SUM(base_debit) - SUM(base_credit); LIABILITY/EQUITY/REVENUE = SUM(base_credit) - SUM(base_debit)
                - journal_entry.status must be 'POSTED' for real financial data (ignore DRAFT/REVERSED)
                - invoice.status tracks lifecycle: DRAFT → SENT → PARTIALLY_PAID → PAID (also OVERDUE, CANCELLED)
                - Always filter by org_id = :orgId for multi-tenancy
                """;
    }
}

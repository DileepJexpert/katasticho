# Katasticho AI Approach and Roadmap

This document records the recommended AI architecture direction for Katasticho ERP. It is intentionally kept as a planning document and should not be treated as an implementation-complete specification.

## 1. Current Direction

Katasticho should implement AI first as a cross-cutting concern, similar to audit logging, security, tenant context, caching, and notifications.

The first AI foundation should not deeply modify every business table. Instead, AI should observe existing deterministic ERP workflows, create reviewable suggestions, learn from human decisions, and only later write approved business changes through existing services.

Core principle:

```text
AI observes -> AI suggests -> human reviews -> ERP service applies -> AI learns
```

The deterministic accounting, tax, and inventory engines must remain the source of truth.

AI should not directly mutate ledgers, journals, invoices, stock, GST records, or payments without passing through existing domain services and validations.

## 2. Why Cross-Cutting AI

Katasticho has many modules:

- Invoices
- Bills
- Sales receipts / POS
- Payments
- Vendor payments
- Journal entries
- Stock movements
- Items
- Contacts
- Expenses
- Credit notes
- Bank transactions
- GST reports

Adding AI-specific columns to every table at the beginning would create schema bloat and force every AI feature to modify business tables.

A cross-cutting AI layer gives one common workflow for all modules:

```text
Domain event created
AI agent analyzes event
AI suggestion is created
User accepts, rejects, or modifies
Correction becomes learning data
Patterns are updated
```

This design keeps the ERP modular and safer.

## 3. Recommended First AI Tables

### 3.1 ai_suggestions

This is the central AI decision and AI Inbox table.

It stores suggestions, risk flags, confidence, reasoning, review status, corrections, and user decisions.

Example uses:

- Suggested account category
- GST mismatch warning
- Duplicate invoice suspicion
- High-value transaction warning
- Reorder suggestion
- Credit risk suggestion
- Bank reconciliation match
- OCR extraction review

Suggested shape:

```sql
CREATE TABLE ai_suggestions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,

    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    entity_line_id UUID,

    suggestion_type VARCHAR(50) NOT NULL,
    suggested_action VARCHAR(80),
    suggested_value JSONB,
    reasoning TEXT,
    confidence DECIMAL(4,3),

    agent_name VARCHAR(50),
    model_name VARCHAR(80),
    model_version VARCHAR(50),
    prompt_version VARCHAR(50),

    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',

    reviewed_by UUID,
    reviewed_at TIMESTAMP,
    review_action VARCHAR(50),
    reviewed_value JSONB,
    correction_reason TEXT,

    priority VARCHAR(20) DEFAULT 'MEDIUM',
    priority_score DECIMAL(8,3),
    due_by TIMESTAMP,

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

The AI Inbox is simply all pending suggestions:

```sql
SELECT *
FROM ai_suggestions
WHERE org_id = :orgId
  AND status = 'PENDING'
ORDER BY priority_score DESC, created_at DESC;
```

### 3.2 domain_events

This table is for AI and workflow processing. It should not blindly duplicate audit logs.

Audit logs answer:

```text
Who changed what?
```

Domain events answer:

```text
What business event happened, and what agents/workflows should react?
```

Suggested shape:

```sql
CREATE TABLE domain_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,

    event_type VARCHAR(80) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,

    payload JSONB NOT NULL DEFAULT '{}',
    before_state JSONB,
    after_state JSONB,

    actor_type VARCHAR(30) NOT NULL,
    actor_id VARCHAR(100),

    processed BOOLEAN NOT NULL DEFAULT false,
    processed_at TIMESTAMP,
    processing_error TEXT,
    retry_count INT NOT NULL DEFAULT 0,

    created_at TIMESTAMP DEFAULT NOW()
);
```

Initial events:

- INVOICE_CREATED
- INVOICE_POSTED
- BILL_CREATED
- BILL_POSTED
- PAYMENT_RECEIVED
- PAYMENT_MADE
- STOCK_MOVED
- JOURNAL_POSTED
- AI_SUGGESTION_ACCEPTED
- AI_SUGGESTION_REJECTED
- AI_SUGGESTION_MODIFIED

### 3.3 ai_patterns

This stores learned business patterns.

Example patterns:

- Vendor + HSN -> account code
- Vendor -> expense account
- HSN -> GST rate
- Item -> reorder behavior
- Customer -> payment delay pattern
- Description keyword -> account code

Suggested shape:

```sql
CREATE TABLE ai_patterns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,

    pattern_type VARCHAR(50) NOT NULL,
    pattern_key JSONB NOT NULL,
    predicted_result JSONB NOT NULL,

    confidence DECIMAL(4,3) NOT NULL DEFAULT 0.500,
    match_count INT NOT NULL DEFAULT 0,
    accepted_count INT NOT NULL DEFAULT 0,
    rejected_count INT NOT NULL DEFAULT 0,
    corrected_count INT NOT NULL DEFAULT 0,

    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',

    last_matched_at TIMESTAMP,
    last_corrected_at TIMESTAMP,

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

### 3.4 ai_training_examples

This should not store every transaction.

It should store curated learning examples created only when users accept, reject, or modify AI suggestions.

Suggested shape:

```sql
CREATE TABLE ai_training_examples (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    org_id UUID NOT NULL,
    source_suggestion_id UUID REFERENCES ai_suggestions(id),

    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,

    task_type VARCHAR(50) NOT NULL,

    input_snapshot JSONB NOT NULL,
    ai_output JSONB,
    human_output JSONB NOT NULL,

    correction_type VARCHAR(30),
    correction_reason TEXT,

    created_by UUID,
    created_at TIMESTAMP DEFAULT NOW()
);
```

## 4. What Not To Do First

Do not begin by adding AI columns to every table.

Avoid this as a first migration:

```sql
ALTER TABLE invoice ADD COLUMN ai_metadata JSONB;
ALTER TABLE bill ADD COLUMN ai_metadata JSONB;
ALTER TABLE payment ADD COLUMN ai_metadata JSONB;
ALTER TABLE item ADD COLUMN ai_metadata JSONB;
```

This may become useful later for performance or fast filtering, but it should not be the foundation.

Also do not implement these in the first phase:

- MCP servers
- Kafka
- Redis Streams
- autonomous journal posting
- autonomous GST filing
- autonomous stock adjustment
- vector database
- custom ML model training
- fine-tuning
- automatic WhatsApp reminders

## 5. Hybrid Model for Later

The recommended long-term model is hybrid.

Use generic AI tables for source of truth:

- ai_suggestions
- domain_events
- ai_patterns
- ai_training_examples

Later add small summary fields to hot business tables only when needed.

Examples:

```sql
ALTER TABLE invoice ADD COLUMN ai_review_status VARCHAR(30);
ALTER TABLE invoice ADD COLUMN ai_risk_score DECIMAL(4,3);

ALTER TABLE contact ADD COLUMN ai_credit_risk_score DECIMAL(4,3);

ALTER TABLE item ADD COLUMN ai_reorder_score DECIMAL(4,3);

ALTER TABLE bank_transaction ADD COLUMN ai_match_status VARCHAR(30);
```

Rule:

```text
AI reasoning, confidence, suggestion, correction -> ai_suggestions
Permanent business result after approval -> normal business table
Fast dashboard/filter status -> small summary column on business table if needed
```

## 6. Phase Roadmap

### Phase 1: AI Foundation

Build:

- ai_suggestions
- domain_events
- ai_patterns
- ai_training_examples
- backend entities and repositories
- event publisher
- AI suggestion service
- AI Inbox API

No autonomous actions.

Expected result:

```text
ERP can store events, AI suggestions, reviews, and corrections.
```

### Phase 2: Rule-Based Agents

Build first agents without external AI calls:

- Anomaly Detection Agent
- GST Compliance Agent
- Inventory Intelligence Agent

These agents should only create pending AI suggestions.

Example outputs:

- High-value invoice posted
- Missing HSN code
- GST rate mismatch
- Large stock adjustment
- Low stock warning
- Expiry warning

Expected result:

```text
AI Inbox starts showing review items.
```

### Phase 3: Flutter AI Inbox

Build UI:

- AI Inbox list
- AI Inbox count card on dashboard
- Accept / Reject / Modify / Defer actions
- Priority filters
- Suggestion detail screen

Expected result:

```text
Users can review AI findings from the ERP UI.
```

### Phase 4: Pattern Learning

When a user accepts, rejects, or modifies a suggestion:

- create ai_training_examples row
- update ai_patterns
- improve future confidence

Expected result:

```text
ERP starts learning vendor, HSN, item, account, and customer behavior patterns.
```

### Phase 5: AI Assistant and Orchestrator

Add assistant endpoint:

```text
POST /api/v1/ai/assistant
```

Capabilities:

- classify user intent
- route to correct agent
- answer financial and inventory questions
- create draft suggestions
- never bypass deterministic services

Expected result:

```text
User can ask: "Why did profit drop?", "Which GST issues need review?", "What should I reorder?"
```

### Phase 6: Selective Business Table AI Fields

Add summary fields only where needed for speed and UX.

Examples:

- invoice.ai_review_status
- item.ai_reorder_score
- contact.ai_credit_risk_score
- bank_transaction.ai_match_status

Expected result:

```text
Fast dashboards and filters without losing the generic AI audit trail.
```

### Phase 7: External AI and MCP Integrations

Only after the foundation is stable:

- AI model gateway
- MCP-style external integrations
- GSTIN validation integration
- bank feed integration
- WhatsApp reminder integration
- document processing pipeline

Expected result:

```text
AI agents can use external tools safely through controlled interfaces.
```

## 7. First Practical Use Cases

### Use Case 1: High-Value Invoice Review

Invoice is posted for a high amount.

Flow:

```text
INVOICE_POSTED event
-> Anomaly agent checks amount
-> ai_suggestions row created
-> AI Inbox shows review item
-> owner accepts or rejects
```

### Use Case 2: GST Missing HSN Review

Invoice line has missing HSN or suspicious GST rate.

Flow:

```text
INVOICE_CREATED or INVOICE_POSTED event
-> GST agent validates line
-> ai_suggestions row created
-> accountant reviews before filing
```

### Use Case 3: Large Stock Adjustment Review

User records a large negative stock adjustment.

Flow:

```text
STOCK_MOVED event
-> Anomaly agent checks movement
-> ai_suggestions row created
-> owner reviews possible stock loss
```

### Use Case 4: Vendor Account Pattern Learning

AI suggests account code for vendor bill.

Flow:

```text
AI suggests account
-> user modifies account
-> ai_training_examples row created
-> ai_patterns updated
-> next similar bill gets better suggestion
```

## 8. Safety Rules

1. AI must not directly post journals.
2. AI must not directly change stock.
3. AI must not directly file GST.
4. AI must not bypass existing services.
5. Low-confidence suggestions must go to review.
6. Critical tax/accounting actions must require human approval.
7. All AI decisions must be auditable.
8. All AI data must be scoped by org_id.
9. Training data must come from reviewed suggestions, not raw transactions.
10. Deterministic ERP logic remains the source of truth.

## 9. Final Architecture Principle

Katasticho should not be built as:

```text
ERP + AI sidebar
```

It should become:

```text
Deterministic ERP core
+
Cross-cutting AI decision layer
+
Human review workflow
+
Learning loop
```

This gives Katasticho an AI-native foundation without making the schema messy too early or risking accounting correctness.

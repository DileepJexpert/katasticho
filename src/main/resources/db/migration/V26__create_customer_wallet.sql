-- V26: Customer wallet / loyalty points for pharmacy
CREATE TABLE customer_wallet (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL,
    contact_id      UUID NOT NULL,
    balance         DECIMAL(14,2) NOT NULL DEFAULT 0,  -- in rupee-equivalent
    total_earned    DECIMAL(14,2) NOT NULL DEFAULT 0,
    total_redeemed  DECIMAL(14,2) NOT NULL DEFAULT 0,
    is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(org_id, contact_id)
);
CREATE TABLE wallet_transaction (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL,
    wallet_id       UUID NOT NULL REFERENCES customer_wallet(id),
    contact_id      UUID NOT NULL,
    txn_type        VARCHAR(20) NOT NULL,  -- EARN, REDEEM, ADJUSTMENT, EXPIRE
    amount          DECIMAL(14,2) NOT NULL,  -- positive for EARN, negative for REDEEM
    balance_after   DECIMAL(14,2) NOT NULL,
    reference_id    UUID,  -- sale receipt id or debit note id
    reference_type  VARCHAR(30),  -- SALE, RETURN, MANUAL
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX idx_wallet_org_contact ON customer_wallet(org_id, contact_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_wallet_txn_wallet ON wallet_transaction(wallet_id);
CREATE INDEX idx_wallet_txn_contact ON wallet_transaction(org_id, contact_id);

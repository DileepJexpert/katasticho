-- V42: FMCG Field Execution Pack
-- Adds beat/route planning, van stock management, field visits, day-close, salesman targets.

-- Beat: geographical cluster of customers
CREATE TABLE beat (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    code VARCHAR(30) NOT NULL,
    name VARCHAR(100) NOT NULL,
    area VARCHAR(100),
    city VARCHAR(100),
    state VARCHAR(50),
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    UNIQUE(org_id, code)
);

-- Beat ↔ customer mapping with visit sequence and frequency
CREATE TABLE beat_customer (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    beat_id UUID NOT NULL REFERENCES beat(id),
    contact_id UUID NOT NULL,
    visit_sequence INT,
    visit_frequency VARCHAR(20) NOT NULL DEFAULT 'WEEKLY',
    geo_latitude DECIMAL(10,7),
    geo_longitude DECIMAL(10,7),
    notes TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(org_id, beat_id, contact_id)
);

-- Route: planned sequence of beats for a salesperson's day
CREATE TABLE route (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    code VARCHAR(30) NOT NULL,
    name VARCHAR(100) NOT NULL,
    day_of_week VARCHAR(10),
    frequency VARCHAR(20) NOT NULL DEFAULT 'WEEKLY',
    warehouse_id UUID,
    estimated_distance_km DECIMAL(8,2),
    estimated_duration_minutes INT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    UNIQUE(org_id, code)
);

-- Route ↔ beat ordering
CREATE TABLE route_beat (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    route_id UUID NOT NULL REFERENCES route(id),
    beat_id UUID NOT NULL REFERENCES beat(id),
    sequence_number INT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(org_id, route_id, beat_id)
);

-- Van: mobile warehouse (vehicle)
CREATE TABLE van (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    code VARCHAR(30) NOT NULL,
    vehicle_number VARCHAR(30) NOT NULL,
    name VARCHAR(100),
    vehicle_type VARCHAR(30) NOT NULL DEFAULT 'VAN',
    source_warehouse_id UUID,
    capacity_weight_kg DECIMAL(10,2),
    capacity_volume_litre DECIMAL(10,2),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    UNIQUE(org_id, code),
    UNIQUE(org_id, vehicle_number)
);

-- Van stock balance: item-level stock on van (derived cache)
CREATE TABLE van_stock_balance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    van_id UUID NOT NULL REFERENCES van(id),
    item_id UUID NOT NULL,
    batch_id UUID,
    quantity_on_hand DECIMAL(15,4) NOT NULL DEFAULT 0,
    last_movement_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_van_stock_balance_org_van_item_batch
    ON van_stock_balance(org_id, van_id, item_id, COALESCE(batch_id, '00000000-0000-0000-0000-000000000000'));

CREATE UNIQUE INDEX uq_van_stock_balance_grain
    ON van_stock_balance (
        org_id,
        van_id,
        item_id,
        COALESCE(batch_id, '00000000-0000-0000-0000-000000000000'::uuid)
    );

-- Field sales assignment: links salesperson → route + van
CREATE TABLE field_sales_assignment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    salesperson_id UUID NOT NULL,
    route_id UUID REFERENCES route(id),
    van_id UUID REFERENCES van(id),
    territory VARCHAR(100),
    effective_from DATE NOT NULL,
    effective_to DATE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    UNIQUE(org_id, salesperson_id, route_id, effective_from)
);

-- Route execution: a salesperson's daily field run
CREATE TABLE route_execution (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    route_id UUID NOT NULL REFERENCES route(id),
    salesperson_id UUID NOT NULL,
    van_id UUID REFERENCES van(id),
    execution_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PLANNED',
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    start_odometer DECIMAL(10,1),
    end_odometer DECIMAL(10,1),
    planned_visits INT NOT NULL DEFAULT 0,
    completed_visits INT NOT NULL DEFAULT 0,
    skipped_visits INT NOT NULL DEFAULT 0,
    total_orders_value DECIMAL(15,2) DEFAULT 0,
    total_collections DECIMAL(15,2) DEFAULT 0,
    notes TEXT,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    UNIQUE(org_id, route_id, salesperson_id, execution_date)
);

-- Field visit: individual customer stop within a route execution
CREATE TABLE field_visit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    route_execution_id UUID NOT NULL REFERENCES route_execution(id),
    contact_id UUID NOT NULL,
    beat_id UUID REFERENCES beat(id),
    sequence_number INT,
    status VARCHAR(20) NOT NULL DEFAULT 'PLANNED',
    check_in_time TIMESTAMPTZ,
    check_out_time TIMESTAMPTZ,
    check_in_latitude DECIMAL(10,7),
    check_in_longitude DECIMAL(10,7),
    check_out_latitude DECIMAL(10,7),
    check_out_longitude DECIMAL(10,7),
    sales_order_id UUID,
    order_value DECIMAL(15,2) DEFAULT 0,
    collection_amount DECIMAL(15,2) DEFAULT 0,
    delivery_challan_id UUID,
    skip_reason VARCHAR(200),
    notes TEXT,
    photo_url TEXT,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Van stock transfer: loading / unloading / return records
CREATE TABLE van_stock_transfer (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    van_id UUID NOT NULL REFERENCES van(id),
    warehouse_id UUID NOT NULL,
    transfer_type VARCHAR(20) NOT NULL,
    transfer_date DATE NOT NULL,
    route_execution_id UUID REFERENCES route_execution(id),
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    notes TEXT,
    confirmed_by UUID,
    confirmed_at TIMESTAMPTZ,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID
);

CREATE TABLE van_stock_transfer_line (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    van_stock_transfer_id UUID NOT NULL REFERENCES van_stock_transfer(id),
    item_id UUID NOT NULL,
    batch_id UUID,
    quantity DECIMAL(15,4) NOT NULL,
    unit VARCHAR(20),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Salesman target: period-based targets and achievement
CREATE TABLE salesman_target (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    salesperson_id UUID NOT NULL,
    period_type VARCHAR(20) NOT NULL DEFAULT 'MONTHLY',
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    target_type VARCHAR(30) NOT NULL,
    target_value DECIMAL(15,2) NOT NULL,
    achieved_value DECIMAL(15,2) NOT NULL DEFAULT 0,
    achievement_pct DECIMAL(5,2) NOT NULL DEFAULT 0,
    incentive_rate DECIMAL(10,2) DEFAULT 0,
    incentive_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    notes TEXT,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    UNIQUE(org_id, salesperson_id, period_type, period_start, target_type)
);

-- Day close: end-of-day reconciliation
CREATE TABLE day_close (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    route_execution_id UUID NOT NULL REFERENCES route_execution(id),
    salesperson_id UUID NOT NULL,
    van_id UUID REFERENCES van(id),
    close_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    opening_cash DECIMAL(15,2) DEFAULT 0,
    cash_collections DECIMAL(15,2) DEFAULT 0,
    cash_expenses DECIMAL(15,2) DEFAULT 0,
    closing_cash DECIMAL(15,2) DEFAULT 0,
    cash_deposited DECIMAL(15,2) DEFAULT 0,
    cash_variance DECIMAL(15,2) DEFAULT 0,
    items_loaded INT DEFAULT 0,
    items_sold INT DEFAULT 0,
    items_returned INT DEFAULT 0,
    items_closing INT DEFAULT 0,
    stock_variance_count INT DEFAULT 0,
    visits_planned INT DEFAULT 0,
    visits_completed INT DEFAULT 0,
    visits_productive INT DEFAULT 0,
    total_orders_value DECIMAL(15,2) DEFAULT 0,
    total_collections DECIMAL(15,2) DEFAULT 0,
    total_returns_value DECIMAL(15,2) DEFAULT 0,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    rejection_reason TEXT,
    notes TEXT,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID,
    UNIQUE(org_id, route_execution_id)
);

-- Indexes
CREATE INDEX idx_beat_org ON beat(org_id) WHERE NOT is_deleted;
CREATE INDEX idx_beat_customer_beat ON beat_customer(org_id, beat_id) WHERE is_active;
CREATE INDEX idx_beat_customer_contact ON beat_customer(org_id, contact_id);
CREATE INDEX idx_route_org ON route(org_id) WHERE NOT is_deleted;
CREATE INDEX idx_route_beat_route ON route_beat(org_id, route_id);
CREATE INDEX idx_van_org ON van(org_id) WHERE NOT is_deleted;
CREATE INDEX idx_van_stock_balance_van ON van_stock_balance(org_id, van_id);
CREATE INDEX idx_van_stock_balance_item ON van_stock_balance(org_id, item_id);
CREATE INDEX idx_field_assignment_person ON field_sales_assignment(org_id, salesperson_id) WHERE is_active;
CREATE INDEX idx_route_execution_date ON route_execution(org_id, execution_date);
CREATE INDEX idx_route_execution_person ON route_execution(org_id, salesperson_id);
CREATE INDEX idx_field_visit_execution ON field_visit(org_id, route_execution_id);
CREATE INDEX idx_field_visit_contact ON field_visit(org_id, contact_id);
CREATE INDEX idx_van_transfer_van ON van_stock_transfer(org_id, van_id);
CREATE INDEX idx_salesman_target_person ON salesman_target(org_id, salesperson_id);
CREATE INDEX idx_day_close_date ON day_close(org_id, close_date);

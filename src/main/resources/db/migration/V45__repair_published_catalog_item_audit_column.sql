-- Repair V43 published_catalog_item schema for databases where V43 already ran before
-- PublishedCatalogItem extends BaseEntity, so Hibernate validation requires created_by.
ALTER TABLE published_catalog_item
    ADD COLUMN IF NOT EXISTS created_by UUID;

package com.katasticho.erp.organisation;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Seeds industry template reference data once on first startup.
 * Subsequent startups are a no-op (count check). To update templates,
 * edit DB directly or add a new seed version check.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class IndustryTemplateSeedService {

    private final IndustryTemplateRepository templateRepo;
    private final IndustrySubCategoryRepository subCatRepo;
    private final IndustryFeatureConfigRepository featureConfigRepo;

    @EventListener(ApplicationReadyEvent.class)
    @Transactional
    public void seedOnStartup() {
        if (templateRepo.count() > 0) {
            log.info("[IndustryTemplateSeed] Templates already seeded ({} rows). Skipping.", templateRepo.count());
            return;
        }
        log.info("[IndustryTemplateSeed] Seeding industry templates...");
        seedRetailers();
        seedDistributors();
        seedManufacturers();
        seedServiceProviders();
        log.info("[IndustryTemplateSeed] Done. {} templates seeded.", templateRepo.count());
    }

    // ── RETAILERS ─────────────────────────────────────────────────────────

    private void seedRetailers() {
        createTemplate("RETAILER", "PHARMACY",      "Pharmacy",           "💊",  1,
            List.of("SINGLE_MEDICAL_STORE:Single Medical Store:1",
                    "PHARMACY_CHAIN:Pharmacy Chain (2-10 stores):2",
                    "AYURVEDIC_HOMEOPATHY:Ayurvedic / Homeopathy Store:3",
                    "SURGICAL_EQUIPMENT:Surgical & Medical Equipment:4"),
            cfg -> cfg.featureFlags(List.of("BATCH_TRACKING", "EXPIRY_TRACKING", "MRP_PRICING", "DRUG_SCHEDULE_FIELDS"))
                      .uomList(List.of("Strip", "Bottle", "Tube", "Vial", "Sachet", "Tablet", "ML", "MG", "Pieces"))
                      .itemFields(List.of("genericName", "drugSchedule", "composition", "dosageForm",
                                          "packSize", "storageCondition", "prescriptionRequired", "shelfLocation"))
                      .additionalAccounts(List.of(Map.of("code", "5010", "name", "Drug License Fee",
                                                          "type", "EXPENSE", "parentCode", "5000"))),
            Map.of("SURGICAL_EQUIPMENT",
                cfg2 -> cfg2.featureFlags(List.of("BATCH_TRACKING", "EXPIRY_TRACKING", "MRP_PRICING",
                                                   "DRUG_SCHEDULE_FIELDS", "SERIAL_TRACKING", "WARRANTY_MANAGEMENT"))
                            .uomList(List.of("Pieces", "Set", "Box", "Strip", "Bottle", "Tube"))
            )
        );

        createTemplate("RETAILER", "GROCERY",       "Grocery / Kirana",   "🛒",  2,
            List.of("KIRANA_GENERAL:Kirana / General Store:1",
                    "SUPERMARKET:Supermarket / Superstore:2",
                    "FRUITS_VEGETABLES:Fruits & Vegetables:3",
                    "ORGANIC_HEALTH:Organic / Health Food:4"),
            cfg -> cfg.featureFlags(List.of("BATCH_TRACKING", "EXPIRY_TRACKING", "MRP_PRICING", "WEIGHT_BASED_BILLING"))
                      .uomList(List.of("KG", "GM", "Litre", "ML", "Packet", "Dozen", "Pieces", "Box",
                                       "Bora", "Carton", "Tin", "Tray", "Peti", "Bundle", "Bag")),
            Map.of()
        );

        createTemplate("RETAILER", "ELECTRONICS",   "Electronics",        "💻",  3,
            List.of("COMPUTER_LAPTOP:Computer & Laptop Shop:1",
                    "MOBILE_ACCESSORIES:Mobile Phone & Accessories:2",
                    "HOME_APPLIANCES:Home Appliances:3",
                    "LED_LIGHTING:LED / Lighting:4",
                    "CCTV_SECURITY:CCTV / Security Systems:5"),
            cfg -> cfg.featureFlags(List.of("SERIAL_TRACKING", "WARRANTY_MANAGEMENT"))
                      .uomList(List.of("Pieces", "Set", "Pair", "Box"))
                      .itemFields(List.of("modelNumber", "brand", "warrantyMonths", "color")),
            Map.of()
        );

        createTemplate("RETAILER", "HARDWARE",      "Hardware",           "🔧",  4,
            List.of("HARDWARE_TOOLS:Hardware & Tools:1",
                    "PLUMBING_SANITARY:Plumbing & Sanitary:2",
                    "ELECTRICAL_SUPPLIES:Electrical Supplies:3",
                    "PAINT_ACCESSORIES:Paint & Accessories:4",
                    "BUILDING_MATERIALS:Building Materials:5"),
            cfg -> cfg.featureFlags(List.of("WEIGHT_BASED_BILLING"))
                      .uomList(List.of("KG", "Pieces", "Metres", "Feet", "Sq.Ft", "Cu.Ft", "Bag", "Bundle"))
                      .itemFields(List.of("material", "sizeGauge")),
            Map.of()
        );

        createTemplate("RETAILER", "GARMENTS",      "Garments",           "👔",  5,
            List.of("READYMADE_GARMENTS:Readymade Garments:1",
                    "FABRIC_TEXTILE:Fabric / Textile Shop:2",
                    "FOOTWEAR:Footwear:3",
                    "JEWELRY_ACCESSORIES:Jewelry & Accessories:4",
                    "COSMETICS_BEAUTY:Cosmetics & Beauty:5"),
            cfg -> cfg.featureFlags(List.of("SIZE_COLOR_VARIANTS"))
                      .uomList(List.of("Pieces", "Dozen", "Set", "Pair", "Metres"))
                      .itemFields(List.of("fabric", "season")),
            Map.of()
        );

        createTemplate("RETAILER", "FOOD_BEVERAGE", "Food & Beverage",    "🍕",  6,
            List.of("RESTAURANT_CAFE:Restaurant / Cafe:1",
                    "BAKERY_SWEET:Bakery / Sweet Shop:2",
                    "CATERING:Catering:3",
                    "CLOUD_KITCHEN:Cloud Kitchen:4",
                    "JUICE_ICECREAM:Juice / Ice Cream Parlor:5"),
            cfg -> cfg.featureFlags(List.of("BATCH_TRACKING", "EXPIRY_TRACKING", "BOM_ASSEMBLY", "WEIGHT_BASED_BILLING"))
                      .uomList(List.of("KG", "GM", "Litre", "ML", "Pieces", "Plate", "Glass"))
                      .itemFields(List.of("vegNonVeg", "allergens", "fssaiLicence")),
            Map.of()
        );

        createTemplate("RETAILER", "AUTO_PARTS",    "Auto Parts",         "🚗",  7,
            List.of("AUTO_SPARE:Auto Spare Parts:1",
                    "TWO_WHEELER:Two-Wheeler Parts:2",
                    "TYRE_SHOP:Tyre Shop:3",
                    "CAR_ACCESSORIES:Car Accessories:4"),
            cfg -> cfg.featureFlags(List.of("SERIAL_TRACKING", "WARRANTY_MANAGEMENT"))
                      .uomList(List.of("Pieces", "Set", "Pair", "Litre"))
                      .itemFields(List.of("vehicleType", "oemPartNumber", "compatibleModels")),
            Map.of()
        );

        createTemplate("RETAILER", "STATIONERY",    "Stationery",         "📚",  8,
            List.of(),
            cfg -> cfg.featureFlags(List.of())
                      .uomList(List.of("Pieces", "Box", "Dozen", "Set", "Bundle")),
            Map.of()
        );

        createTemplate("RETAILER", "AGRICULTURE",   "Agriculture",        "🌾",  9,
            List.of(),
            cfg -> cfg.featureFlags(List.of("WEIGHT_BASED_BILLING"))
                      .uomList(List.of("KG", "GM", "Bag", "Bundle", "Pieces", "Litre")),
            Map.of()
        );

        createTemplate("RETAILER", "OTHER_RETAIL",  "Other",              "📦",  99,
            List.of(),
            cfg -> cfg.featureFlags(List.of())
                      .uomList(List.of("Pieces", "Box", "Set", "Dozen", "KG", "GM", "Litre", "ML")),
            Map.of()
        );
    }

    // ── DISTRIBUTORS ──────────────────────────────────────────────────────

    private void seedDistributors() {
        createTemplate("DISTRIBUTOR", "PHARMA_DISTRIBUTOR",       "Medicines",  "💊",  1,
            List.of("ALLOPATHIC_DIST:Allopathic Medicine Distributor:1",
                    "AYURVEDIC_DIST:Ayurvedic Medicine Distributor:2",
                    "SURGICAL_DIST:Surgical Equipment Distributor:3"),
            cfg -> cfg.featureFlags(List.of("BATCH_TRACKING", "EXPIRY_TRACKING", "MRP_PRICING",
                                            "DRUG_SCHEDULE_FIELDS", "MULTI_WAREHOUSE", "MULTI_BRANCH"))
                      .uomList(List.of("Strip", "Bottle", "Tube", "Vial", "Sachet", "Tablet", "ML", "MG", "Pieces"))
                      .itemFields(List.of("genericName", "drugSchedule", "composition", "packSize")),
            Map.of()
        );

        createTemplate("DISTRIBUTOR", "FMCG_DISTRIBUTOR",         "FMCG",       "🛒",  2,
            List.of("FOOD_BEV_DIST:Food & Beverage Distributor:1",
                    "PERSONAL_CARE_DIST:Personal Care Distributor:2",
                    "HOUSEHOLD_DIST:Household Products Distributor:3"),
            cfg -> cfg.featureFlags(List.of("BATCH_TRACKING", "EXPIRY_TRACKING", "MRP_PRICING",
                                            "WEIGHT_BASED_BILLING", "MULTI_WAREHOUSE", "MULTI_BRANCH"))
                      .uomList(List.of("KG", "GM", "Litre", "ML", "Packet", "Box", "Carton", "Pieces")),
            Map.of()
        );

        createTemplate("DISTRIBUTOR", "ELECTRONICS_DISTRIBUTOR",  "Electronics", "💻", 3,
            List.of(),
            cfg -> cfg.featureFlags(List.of("SERIAL_TRACKING", "WARRANTY_MANAGEMENT",
                                            "MULTI_WAREHOUSE", "MULTI_BRANCH"))
                      .uomList(List.of("Pieces", "Set", "Box", "Pair")),
            Map.of()
        );

        createTemplate("DISTRIBUTOR", "HARDWARE_DISTRIBUTOR",     "Hardware",   "🔧",  4,
            List.of(),
            cfg -> cfg.featureFlags(List.of("WEIGHT_BASED_BILLING", "MULTI_WAREHOUSE", "MULTI_BRANCH"))
                      .uomList(List.of("KG", "Pieces", "Metres", "Bag", "Bundle")),
            Map.of()
        );

        createTemplate("DISTRIBUTOR", "GARMENTS_DISTRIBUTOR",     "Garments",   "👔",  5,
            List.of(),
            cfg -> cfg.featureFlags(List.of("SIZE_COLOR_VARIANTS", "MULTI_WAREHOUSE", "MULTI_BRANCH"))
                      .uomList(List.of("Pieces", "Dozen", "Set", "Pair", "Metres")),
            Map.of()
        );

        createTemplate("DISTRIBUTOR", "OTHER_DISTRIBUTOR",        "Other",      "📦",  99,
            List.of(),
            cfg -> cfg.featureFlags(List.of("MULTI_WAREHOUSE", "MULTI_BRANCH"))
                      .uomList(List.of("Pieces", "Box", "Set", "Dozen", "KG")),
            Map.of()
        );
    }

    // ── MANUFACTURERS ─────────────────────────────────────────────────────

    private void seedManufacturers() {
        createTemplate("MANUFACTURER", "PHARMA_MANUFACTURER",     "Medicines",     "💊",  1,
            List.of("ALLOPATHIC_MEDICINE:Allopathic Medicine:1",
                    "AYURVEDIC_HERBAL:Ayurvedic / Herbal:2",
                    "NUTRACEUTICALS:Nutraceuticals / Supplements:3",
                    "SURGICAL_CONSUMABLES:Surgical Consumables:4"),
            cfg -> cfg.featureFlags(List.of("BATCH_TRACKING", "EXPIRY_TRACKING", "BOM_ASSEMBLY",
                                            "DRUG_SCHEDULE_FIELDS", "MULTI_WAREHOUSE"))
                      .uomList(List.of("Strip", "Bottle", "Tube", "Vial", "Sachet",
                                       "Tablet", "ML", "MG", "KG", "Litre", "Pieces"))
                      .itemFields(List.of("apiName", "drugCategory", "mfgLicenceNumber", "dpcoControlled"))
                      .additionalAccounts(List.of(
                          Map.of("code", "1050", "name", "Raw Materials",   "type", "ASSET", "parentCode", "1000"),
                          Map.of("code", "1051", "name", "Work in Progress","type", "ASSET", "parentCode", "1000"),
                          Map.of("code", "1052", "name", "Finished Goods",  "type", "ASSET", "parentCode", "1000"))),
            Map.of()
        );

        createTemplate("MANUFACTURER", "FOOD_MANUFACTURER",       "Food Products", "🍞",  2,
            List.of("PACKAGED_FOOD:Packaged Food:1",
                    "BAKERY_CONFECTIONERY:Bakery / Confectionery:2",
                    "DAIRY_PRODUCTS:Dairy Products:3",
                    "SPICES_MASALA:Spices & Masala:4",
                    "BEVERAGES:Beverages:5",
                    "FROZEN_FOOD:Frozen Food:6"),
            cfg -> cfg.featureFlags(List.of("BATCH_TRACKING", "EXPIRY_TRACKING", "BOM_ASSEMBLY", "WEIGHT_BASED_BILLING"))
                      .uomList(List.of("KG", "GM", "Litre", "ML", "Pieces", "Box", "Carton", "Packet"))
                      .itemFields(List.of("fssaiCategory", "nutritionalInfo"))
                      .additionalAccounts(List.of(
                          Map.of("code", "1050", "name", "Raw Materials",   "type", "ASSET", "parentCode", "1000"),
                          Map.of("code", "1051", "name", "Work in Progress","type", "ASSET", "parentCode", "1000"),
                          Map.of("code", "1052", "name", "Finished Goods",  "type", "ASSET", "parentCode", "1000"))),
            Map.of()
        );

        createTemplate("MANUFACTURER", "GARMENT_MANUFACTURER",    "Garments",     "👔",  3,
            List.of("MFG_READYMADE:Readymade Garments:1",
                    "MFG_FABRIC:Fabric / Textile:2",
                    "MFG_ACCESSORIES:Accessories:3"),
            cfg -> cfg.featureFlags(List.of("SIZE_COLOR_VARIANTS", "BOM_ASSEMBLY"))
                      .uomList(List.of("Pieces", "Dozen", "Set", "Metres"))
                      .itemFields(List.of("fabricComposition", "washCare")),
            Map.of()
        );

        createTemplate("MANUFACTURER", "ELECTRONICS_MANUFACTURER", "Electronics", "💡",  4,
            List.of("ELECTRONIC_COMPONENTS:Electronic Components:1",
                    "MFG_LED_LIGHTING:LED / Lighting:2",
                    "CABLES_WIRING:Cables & Wiring:3",
                    "CONSUMER_ELECTRONICS:Consumer Electronics:4"),
            cfg -> cfg.featureFlags(List.of("SERIAL_TRACKING", "BOM_ASSEMBLY", "WARRANTY_MANAGEMENT"))
                      .uomList(List.of("Pieces", "Set", "Box"))
                      .itemFields(List.of("pcbVersion", "bisCertification")),
            Map.of()
        );

        createTemplate("MANUFACTURER", "CHEMICAL_MANUFACTURER",   "Chemicals",    "🧪",  5,
            List.of("INDUSTRIAL_CHEMICALS:Industrial Chemicals:1",
                    "PAINTS_COATINGS:Paints & Coatings:2",
                    "CLEANING_PRODUCTS:Cleaning Products:3",
                    "ADHESIVES:Adhesives:4"),
            cfg -> cfg.featureFlags(List.of("BATCH_TRACKING", "EXPIRY_TRACKING", "BOM_ASSEMBLY"))
                      .uomList(List.of("KG", "GM", "Litre", "ML", "Pieces", "Drum", "Barrel"))
                      .itemFields(List.of("colorCode", "colorFamily", "finishType")),
            Map.of()
        );

        createTemplate("MANUFACTURER", "HARDWARE_MANUFACTURER",   "Hardware",     "🔧",  6,
            List.of("TOOLS_FASTENERS:Tools & Fasteners:1",
                    "FURNITURE:Furniture:2",
                    "PLASTIC_PRODUCTS:Plastic Products:3",
                    "PACKAGING_MATERIALS:Packaging Materials:4"),
            cfg -> cfg.featureFlags(List.of("WEIGHT_BASED_BILLING", "BOM_ASSEMBLY"))
                      .uomList(List.of("KG", "Pieces", "Metres", "Set", "Box"))
                      .itemFields(List.of("material", "sizeGauge")),
            Map.of()
        );

        createTemplate("MANUFACTURER", "OTHER_MANUFACTURER",      "Other",        "📦",  99,
            List.of(),
            cfg -> cfg.featureFlags(List.of("BOM_ASSEMBLY"))
                      .uomList(List.of("Pieces", "Box", "KG", "GM", "Litre", "Set")),
            Map.of()
        );
    }

    // ── SERVICE PROVIDERS ─────────────────────────────────────────────────

    private void seedServiceProviders() {
        createTemplate("SERVICE_PROVIDER", "IT_SERVICES",          "IT Services",    "💻",  1,
            List.of(),
            cfg -> cfg.featureFlags(List.of())
                      .uomList(List.of("Hours", "Sessions", "Visits", "Pieces")),
            Map.of()
        );

        createTemplate("SERVICE_PROVIDER", "PROFESSIONAL_SERVICES","Professional",   "💼",  2,
            List.of(),
            cfg -> cfg.featureFlags(List.of())
                      .uomList(List.of("Hours", "Sessions", "Visits")),
            Map.of()
        );

        createTemplate("SERVICE_PROVIDER", "REPAIR_SERVICES",      "Repair",         "🔧",  3,
            List.of("MOBILE_LAPTOP_REPAIR:Mobile / Laptop Repair:1",
                    "HOME_APPLIANCE_REPAIR:Home Appliance Repair:2",
                    "AUTO_REPAIR_GARAGE:Auto Repair / Garage:3",
                    "AC_REFRIGERATION:AC / Refrigeration:4"),
            cfg -> cfg.featureFlags(List.of("SERIAL_TRACKING", "WARRANTY_MANAGEMENT"))
                      .uomList(List.of("Pieces", "Hours", "Visits")),
            Map.of()
        );

        createTemplate("SERVICE_PROVIDER", "EDUCATION",            "Education",      "📚",  4,
            List.of("COACHING_TUITION:Coaching Centre / Tuition:1",
                    "TRAINING_INSTITUTE:Training Institute:2",
                    "PLAYSCHOOL_DAYCARE:Playschool / Daycare:3"),
            cfg -> cfg.featureFlags(List.of())
                      .uomList(List.of("Sessions", "Hours", "Visits")),
            Map.of()
        );

        createTemplate("SERVICE_PROVIDER", "HEALTHCARE",           "Healthcare",     "🏥",  5,
            List.of("CLINIC_DOCTOR:Clinic / Doctor:1",
                    "DIAGNOSTIC_LAB:Diagnostic Lab:2",
                    "DENTAL_CLINIC:Dental Clinic:3",
                    "PHYSIOTHERAPY:Physiotherapy:4"),
            cfg -> cfg.featureFlags(List.of("BATCH_TRACKING", "EXPIRY_TRACKING"))
                      .uomList(List.of("Visits", "Sessions", "Pieces", "Strip", "Bottle")),
            Map.of()
        );

        createTemplate("SERVICE_PROVIDER", "OTHER_SERVICE",        "Other",          "📦",  99,
            List.of(),
            cfg -> cfg.featureFlags(List.of())
                      .uomList(List.of("Hours", "Sessions", "Visits", "Pieces")),
            Map.of()
        );
    }

    // ── Builder helper ────────────────────────────────────────────────────

    @FunctionalInterface
    private interface ConfigCustomizer {
        IndustryFeatureConfig.IndustryFeatureConfigBuilder customize(
                IndustryFeatureConfig.IndustryFeatureConfigBuilder builder);
    }

    private void createTemplate(
            String businessType, String industryCode, String label, String icon, int sortOrder,
            List<String> subCategoryDefs,
            ConfigCustomizer defaultConfigCustomizer,
            Map<String, ConfigCustomizer> subCatConfigOverrides) {

        IndustryTemplate template = templateRepo.save(IndustryTemplate.builder()
                .businessType(businessType)
                .industryCode(industryCode)
                .industryLabel(label)
                .industryIcon(icon)
                .sortOrder(sortOrder)
                .build());

        UUID tid = template.getId();

        // Seed sub-categories
        for (String def : subCategoryDefs) {
            String[] parts = def.split(":", 3);
            subCatRepo.save(IndustrySubCategory.builder()
                    .industryTemplateId(tid)
                    .subCategoryCode(parts[0])
                    .subCategoryLabel(parts[1])
                    .sortOrder(Integer.parseInt(parts[2]))
                    .build());
        }

        // Industry-level default config (sub_category_code = null)
        IndustryFeatureConfig defaultCfg = defaultConfigCustomizer.customize(
                IndustryFeatureConfig.builder()
                        .industryTemplateId(tid)
        ).build();
        featureConfigRepo.save(defaultCfg);

        // Sub-category-specific overrides
        for (Map.Entry<String, ConfigCustomizer> entry : subCatConfigOverrides.entrySet()) {
            IndustryFeatureConfig subCfg = entry.getValue().customize(
                    IndustryFeatureConfig.builder()
                            .industryTemplateId(tid)
                            .subCategoryCode(entry.getKey())
            ).build();
            featureConfigRepo.save(subCfg);
        }

        log.debug("[IndustryTemplateSeed] Created: {} {} with {} sub-cats", businessType, industryCode,
                subCategoryDefs.size());
    }
}

package com.katasticho.erp.common.country;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Gates a controller / service / method to specific countries. Mirror of
 * {@code @RequiresModule}: enforced by {@link CountryAccessAspect}, which reads
 * the current org's country and throws {@code FEATURE_NOT_AVAILABLE_IN_COUNTRY}
 * if it is not in {@link #value()}.
 *
 * <p>Use it to keep India-only compliance (GST filing, e-invoice IRN, e-way bill,
 * TDS/TCS, Tally migration) from firing on a Gulf org. Example:
 *
 * <pre>{@code
 * @RestController
 * @RequiresCountry("IN")          // GST returns are India-only
 * public class GstController { ... }
 * }</pre>
 */
@Target({ElementType.TYPE, ElementType.METHOD})
@Retention(RetentionPolicy.RUNTIME)
public @interface RequiresCountry {
    /** Allowed ISO country codes, e.g. {"IN"} or {"AE", "OM"}. */
    String[] value();
}

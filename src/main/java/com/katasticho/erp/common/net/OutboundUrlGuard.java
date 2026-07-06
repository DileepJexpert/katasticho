package com.katasticho.erp.common.net;

import com.katasticho.erp.common.exception.BusinessException;
import org.springframework.http.HttpStatus;

import java.net.InetAddress;
import java.net.URI;
import java.net.UnknownHostException;

/**
 * SSRF guard for server-side requests to admin-configured URLs (webhooks, GSP
 * aggregator endpoints, …). Rejects non-https URLs and any host that resolves to
 * an internal/loopback/link-local/site-local address. Resolve-and-inspect (not
 * literal string matching) so encoded IP literals (decimal/hex/octal), IPv6
 * loopback forms, and public hostnames that resolve to internal ranges (incl. the
 * 169.254.169.254 cloud-metadata endpoint) are all caught.
 *
 * <p>Error codes are built from a caller-supplied {@code codePrefix} so each
 * feature keeps its own stable codes (e.g. {@code WORKFLOW_WEBHOOK_NOT_HTTPS},
 * {@code GSP_URL_INTERNAL_HOST}).
 */
public final class OutboundUrlGuard {

    private OutboundUrlGuard() {}

    public static void validate(String url, String codePrefix) {
        if (url == null || url.isBlank()) {
            throw bad(codePrefix, "NO_URL", "A URL is required");
        }
        URI uri;
        try {
            uri = URI.create(url.trim());
        } catch (Exception e) {
            throw bad(codePrefix, "BAD_URL", "Invalid URL");
        }
        if (!"https".equalsIgnoreCase(uri.getScheme())) {
            throw bad(codePrefix, "NOT_HTTPS", "URL must be https");
        }
        String host = uri.getHost();
        if (host == null || host.isBlank()) {
            // URI.getHost() returns null for malformed/unbracketed IPv6 or hosts
            // with illegal chars — refuse rather than let the client resolve it.
            throw bad(codePrefix, "INTERNAL_HOST", "URL host is not allowed");
        }
        String cleanHost = host;
        if (cleanHost.startsWith("[") && cleanHost.endsWith("]")) {
            cleanHost = cleanHost.substring(1, cleanHost.length() - 1); // strip IPv6 brackets
        }
        InetAddress[] addrs;
        try {
            addrs = InetAddress.getAllByName(cleanHost);
        } catch (UnknownHostException e) {
            throw bad(codePrefix, "UNRESOLVABLE", "URL host could not be resolved");
        }
        if (addrs.length == 0) {
            throw bad(codePrefix, "UNRESOLVABLE", "URL host could not be resolved");
        }
        for (InetAddress addr : addrs) {
            if (isBlockedAddress(addr)) {
                throw bad(codePrefix, "INTERNAL_HOST", "URL host is not allowed (internal/loopback)");
            }
        }
    }

    /** True for loopback/any-local/link-local (incl. 169.254 metadata)/site-local/multicast/CGNAT
     *  and IPv6 Unique-Local Addresses (fc00::/7), which the InetAddress predicates do not cover. */
    public static boolean isBlockedAddress(InetAddress addr) {
        if (addr.isAnyLocalAddress() || addr.isLoopbackAddress() || addr.isLinkLocalAddress()
                || addr.isSiteLocalAddress() || addr.isMulticastAddress()) {
            return true;
        }
        byte[] b = addr.getAddress();
        if (b.length == 4) {
            int o0 = b[0] & 0xFF, o1 = b[1] & 0xFF;
            if (o0 == 100 && o1 >= 64 && o1 <= 127) return true; // 100.64.0.0/10 CGNAT
        } else if (b.length == 16 && (b[0] & 0xFE) == 0xFC) {
            // RFC 4193 IPv6 Unique-Local Addresses (fc00::/7). Inet6Address
            // .isSiteLocalAddress() only matches the deprecated fec0::/10 block,
            // not fc00::/7 — check the top 7 bits explicitly.
            return true;
        }
        return false;
    }

    private static BusinessException bad(String prefix, String suffix, String message) {
        return new BusinessException(message, prefix + "_" + suffix, HttpStatus.BAD_REQUEST);
    }
}

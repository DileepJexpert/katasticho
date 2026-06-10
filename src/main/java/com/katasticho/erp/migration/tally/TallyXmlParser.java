package com.katasticho.erp.migration.tally;

import com.katasticho.erp.common.exception.BusinessException;
import com.katasticho.erp.migration.tally.TallyMasters.TallyLedger;
import com.katasticho.erp.migration.tally.TallyMasters.TallyStockItem;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilderFactory;
import java.io.ByteArrayInputStream;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Parses TallyPrime master-export XML (Gateway of Tally → Export → Masters →
 * XML). Scans for {@code <GROUP>}, {@code <LEDGER>} and {@code <STOCKITEM>}
 * messages anywhere in the envelope, so minor structural differences between
 * Tally releases don't break the import.
 */
@Component
public class TallyXmlParser {

    /** Leading signed decimal — Tally writes "10 Nos", "500.00/Nos", "-15000.00". */
    private static final Pattern LEADING_NUMBER = Pattern.compile("^\\s*(-?\\d+(?:\\.\\d+)?)");

    public TallyMasters parse(byte[] xmlBytes) {
        Document doc;
        try {
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            // Tally XML never needs DTDs/entities — lock them out (XXE hardening).
            factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
            factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
            factory.setExpandEntityReferences(false);
            doc = factory.newDocumentBuilder().parse(new ByteArrayInputStream(xmlBytes));
        } catch (Exception e) {
            throw new BusinessException(
                    "Could not read the Tally XML file — export Masters from Tally as XML and upload that file ("
                            + e.getMessage() + ")",
                    "TALLY_XML_INVALID", HttpStatus.BAD_REQUEST);
        }

        Map<String, String> groupParents = new HashMap<>();
        NodeList groups = doc.getElementsByTagName("GROUP");
        for (int i = 0; i < groups.getLength(); i++) {
            Element group = (Element) groups.item(i);
            String name = nameOf(group);
            String parent = childText(group, "PARENT");
            if (name != null && parent != null) {
                groupParents.put(name, parent);
            }
        }

        List<TallyLedger> ledgers = new ArrayList<>();
        NodeList ledgerNodes = doc.getElementsByTagName("LEDGER");
        for (int i = 0; i < ledgerNodes.getLength(); i++) {
            Element ledger = (Element) ledgerNodes.item(i);
            String name = nameOf(ledger);
            if (name == null) continue;
            ledgers.add(new TallyLedger(
                    name,
                    childText(ledger, "PARENT"),
                    decimal(childText(ledger, "OPENINGBALANCE")),
                    firstNonBlank(childText(ledger, "PARTYGSTIN"), childText(ledger, "GSTIN")),
                    firstNonBlank(childText(ledger, "LEDSTATENAME"), childText(ledger, "STATENAME")),
                    joinAddressLines(ledger),
                    childText(ledger, "EMAIL"),
                    childText(ledger, "LEDGERPHONE"),
                    childText(ledger, "LEDGERMOBILE"),
                    childText(ledger, "INCOMETAXNUMBER")
            ));
        }

        List<TallyStockItem> items = new ArrayList<>();
        NodeList itemNodes = doc.getElementsByTagName("STOCKITEM");
        for (int i = 0; i < itemNodes.getLength(); i++) {
            Element item = (Element) itemNodes.item(i);
            String name = nameOf(item);
            if (name == null) continue;

            BigDecimal qty = decimal(childText(item, "OPENINGBALANCE"));
            BigDecimal rate = decimal(childText(item, "OPENINGRATE"));
            if ((rate == null || rate.signum() == 0) && qty != null && qty.signum() > 0) {
                // Derive rate from opening value when OPENINGRATE is absent.
                BigDecimal value = decimal(childText(item, "OPENINGVALUE"));
                if (value != null && value.signum() != 0) {
                    rate = value.abs().divide(qty, 2, java.math.RoundingMode.HALF_UP);
                }
            }

            items.add(new TallyStockItem(
                    name,
                    childText(item, "PARENT"),
                    childText(item, "BASEUNITS"),
                    descendantText(item, "HSNCODE"),
                    decimal(firstNonBlank(descendantText(item, "GSTRATE"),
                            descendantText(item, "GSTREPRATE"))),
                    qty,
                    rate
            ));
        }

        if (ledgers.isEmpty() && items.isEmpty()) {
            throw new BusinessException(
                    "No ledgers or stock items found — make sure you exported Masters (not a report) from Tally as XML",
                    "TALLY_XML_EMPTY", HttpStatus.BAD_REQUEST);
        }
        return new TallyMasters(groupParents, ledgers, items);
    }

    // ── Voucher (Day Book) parsing ─────────────────────────────────────

    private static final DateTimeFormatter TALLY_DATE = DateTimeFormatter.ofPattern("yyyyMMdd");

    /**
     * Parse vouchers from a Tally Day Book XML export.
     * Each {@code <VOUCHER>} element becomes one {@link TallyVoucher}.
     */
    public List<TallyVoucher> parseVouchers(byte[] xmlBytes) {
        Document doc;
        try {
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
            factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
            factory.setExpandEntityReferences(false);
            doc = factory.newDocumentBuilder().parse(new ByteArrayInputStream(xmlBytes));
        } catch (Exception e) {
            throw new BusinessException(
                    "Could not read the Tally XML file — export the Day Book from Tally as XML and upload that file ("
                            + e.getMessage() + ")",
                    "TALLY_XML_INVALID", HttpStatus.BAD_REQUEST);
        }

        List<TallyVoucher> vouchers = new ArrayList<>();
        NodeList voucherNodes = doc.getElementsByTagName("VOUCHER");
        for (int i = 0; i < voucherNodes.getLength(); i++) {
            Element v = (Element) voucherNodes.item(i);
            TallyVoucher voucher = parseOneVoucher(v);
            if (voucher != null) vouchers.add(voucher);
        }

        if (vouchers.isEmpty()) {
            throw new BusinessException(
                    "No vouchers found — make sure you exported the Day Book (not Masters) from Tally as XML",
                    "TALLY_VOUCHERS_EMPTY", HttpStatus.BAD_REQUEST);
        }
        return vouchers;
    }

    private TallyVoucher parseOneVoucher(Element v) {
        String vchType = firstNonBlank(v.getAttribute("VCHTYPE"),
                firstNonBlank(childText(v, "VOUCHERTYPENAME"), childText(v, "VCHTYPE")));
        if (vchType == null || vchType.isBlank()) return null;

        String dateStr = firstNonBlank(v.getAttribute("DATE"), childText(v, "DATE"));
        LocalDate date = parseDate(dateStr);
        if (date == null) return null;

        String vchNumber = firstNonBlank(childText(v, "VOUCHERNUMBER"),
                v.getAttribute("VCHKEY"));
        String partyName = childText(v, "PARTYLEDGERNAME");
        String narration = childText(v, "NARRATION");

        List<TallyVoucher.LedgerEntry> entries = new ArrayList<>();
        NodeList ledgerLists = v.getElementsByTagName("ALLLEDGERENTRIES.LIST");
        for (int j = 0; j < ledgerLists.getLength(); j++) {
            Element le = (Element) ledgerLists.item(j);
            String name = childText(le, "LEDGERNAME");
            BigDecimal amount = decimal(childText(le, "AMOUNT"));
            if (name != null && amount != null) {
                entries.add(new TallyVoucher.LedgerEntry(name, amount));
            }
        }
        // Also check LEDGERENTRIES.LIST (older Tally versions)
        NodeList altLists = v.getElementsByTagName("LEDGERENTRIES.LIST");
        for (int j = 0; j < altLists.getLength(); j++) {
            Element le = (Element) altLists.item(j);
            String name = childText(le, "LEDGERNAME");
            BigDecimal amount = decimal(childText(le, "AMOUNT"));
            if (name != null && amount != null) {
                entries.add(new TallyVoucher.LedgerEntry(name, amount));
            }
        }

        if (entries.isEmpty()) return null;
        return new TallyVoucher(vchType.trim(), vchNumber, date, partyName, narration, entries);
    }

    static LocalDate parseDate(String raw) {
        if (raw == null || raw.isBlank()) return null;
        String digits = raw.replaceAll("[^0-9]", "");
        if (digits.length() < 8) return null;
        try {
            return LocalDate.parse(digits.substring(0, 8), TALLY_DATE);
        } catch (DateTimeParseException e) {
            return null;
        }
    }

    // ── Element helpers ──────────────────────────────────────────────────

    /** Master name: the NAME attribute, falling back to a NAME child element. */
    private String nameOf(Element master) {
        String attr = master.getAttribute("NAME");
        if (attr != null && !attr.isBlank()) return attr.trim();
        return descendantText(master, "NAME");
    }

    /** Text of a DIRECT child element (avoids picking nested same-named tags). */
    private String childText(Element parent, String tag) {
        for (Node n = parent.getFirstChild(); n != null; n = n.getNextSibling()) {
            if (n.getNodeType() == Node.ELEMENT_NODE && tag.equals(n.getNodeName())) {
                String text = n.getTextContent();
                return text == null || text.isBlank() ? null : text.trim();
            }
        }
        return null;
    }

    /** First non-blank descendant text — for fields Tally nests in .LIST wrappers. */
    private String descendantText(Element parent, String tag) {
        NodeList nodes = parent.getElementsByTagName(tag);
        for (int i = 0; i < nodes.getLength(); i++) {
            String text = nodes.item(i).getTextContent();
            if (text != null && !text.isBlank()) return text.trim();
        }
        return null;
    }

    private String joinAddressLines(Element ledger) {
        NodeList nodes = ledger.getElementsByTagName("ADDRESS");
        List<String> lines = new ArrayList<>();
        for (int i = 0; i < nodes.getLength(); i++) {
            String text = nodes.item(i).getTextContent();
            if (text != null && !text.isBlank()) lines.add(text.trim());
        }
        return lines.isEmpty() ? null : String.join(", ", lines);
    }

    /** Parse Tally's numeric strings: "-15000.00", "10 Nos", "500.00/Nos". */
    static BigDecimal decimal(String raw) {
        if (raw == null || raw.isBlank()) return null;
        Matcher m = LEADING_NUMBER.matcher(raw.trim());
        if (!m.find()) return null;
        try {
            return new BigDecimal(m.group(1));
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static String firstNonBlank(String a, String b) {
        if (a != null && !a.isBlank()) return a;
        return b == null || b.isBlank() ? null : b;
    }
}

package com.katasticho.erp.common.util;

import java.math.BigDecimal;
import java.math.RoundingMode;

public final class AmountToWordsConverter {

    private AmountToWordsConverter() {}

    private static final String[] ONES = {
            "", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine",
            "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen",
            "Seventeen", "Eighteen", "Nineteen"
    };

    private static final String[] TENS = {
            "", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"
    };

    public static String convert(BigDecimal amount) {
        if (amount == null || amount.compareTo(BigDecimal.ZERO) == 0) {
            return "Zero Rupees Only";
        }

        amount = amount.abs().setScale(2, RoundingMode.HALF_UP);
        long rupees = amount.longValue();
        int paise = amount.remainder(BigDecimal.ONE)
                .movePointRight(2)
                .intValue();

        StringBuilder sb = new StringBuilder();
        if (rupees > 0) {
            sb.append(convertWholeNumber(rupees));
            sb.append(rupees == 1 ? " Rupee" : " Rupees");
        }

        if (paise > 0) {
            if (rupees > 0) sb.append(" and ");
            sb.append(convertWholeNumber(paise));
            sb.append(paise == 1 ? " Paisa" : " Paise");
        }

        sb.append(" Only");
        return sb.toString();
    }

    private static String convertWholeNumber(long n) {
        if (n == 0) return "Zero";
        if (n < 0) return "Minus " + convertWholeNumber(-n);

        StringBuilder sb = new StringBuilder();

        // Indian numbering: Crore (10^7), Lakh (10^5), Thousand, Hundred
        if (n >= 10_000_000) {
            sb.append(convertWholeNumber(n / 10_000_000)).append(" Crore");
            n %= 10_000_000;
            if (n > 0) sb.append(' ');
        }

        if (n >= 100_000) {
            sb.append(convertWholeNumber(n / 100_000)).append(" Lakh");
            n %= 100_000;
            if (n > 0) sb.append(' ');
        }

        if (n >= 1_000) {
            sb.append(convertWholeNumber(n / 1_000)).append(" Thousand");
            n %= 1_000;
            if (n > 0) sb.append(' ');
        }

        if (n >= 100) {
            sb.append(ONES[(int) (n / 100)]).append(" Hundred");
            n %= 100;
            if (n > 0) sb.append(" and ");
        }

        if (n >= 20) {
            sb.append(TENS[(int) (n / 10)]);
            n %= 10;
            if (n > 0) sb.append(' ');
        }

        if (n > 0) {
            sb.append(ONES[(int) n]);
        }

        return sb.toString();
    }
}

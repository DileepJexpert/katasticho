package com.katasticho.erp.accounting.posting;

import com.katasticho.erp.accounting.dto.JournalPostRequest;

public interface PostingRuleStrategy {

    boolean supports(String sourceType);

    JournalPostRequest generate(PostingContext context);
}

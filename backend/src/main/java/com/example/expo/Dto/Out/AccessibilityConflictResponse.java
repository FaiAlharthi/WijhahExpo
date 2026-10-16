package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// the pavilion is marked accessible for a need, but most visitors with that need said it was not suitable
@Data
@AllArgsConstructor
@NoArgsConstructor
public class AccessibilityConflictResponse {
    private Integer pavilionId;
    private String pavilionName;
    private String needType;
    private String officialStatus;
    private Long notSuitableCount;
    private Long totalCount;
}

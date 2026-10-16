package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// a need of the trip that this stop does not fully serve (PARTIAL, NOT_ACCESSIBLE or UNKNOWN)
@Data
@AllArgsConstructor
@NoArgsConstructor
public class AccessibilityWarningResponse {
    private String needType;
    private String status;
    private String note;
    private String noteAr;
}

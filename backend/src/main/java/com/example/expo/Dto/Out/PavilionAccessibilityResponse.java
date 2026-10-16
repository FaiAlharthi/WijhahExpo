package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// one type of need in the pavilion page: the official status and what the visitors said
@Data
@AllArgsConstructor
@NoArgsConstructor
public class PavilionAccessibilityResponse {
    private String needType;
    private String status;
    private String note;
    private String noteAr;
    private Long suitableCount;
    private Long partialCount;
    private Long notSuitableCount;
}

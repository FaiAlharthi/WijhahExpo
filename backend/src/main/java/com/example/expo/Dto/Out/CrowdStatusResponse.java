package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// expected queue of one pavilion now: CALM (10 min or less), MODERATE, CROWDED (20 min or more)
@Data
@AllArgsConstructor
@NoArgsConstructor
public class CrowdStatusResponse {
    private Integer pavilionId;
    private String pavilionName;
    private Integer waitMinutes;
    private String level;
    private Integer expectedPeople;
    private Integer capacity;
    private Boolean manual;          // set by the admin, not estimated
}

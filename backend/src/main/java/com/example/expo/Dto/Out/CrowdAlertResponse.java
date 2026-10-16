package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class CrowdAlertResponse {
    private Integer alertId;
    private Integer roadmapId;
    private Integer pavilionId;
    private String pavilionName;
    private LocalDateTime sentAt;
    private String calmAt;
    private Integer waitNow;
    private Integer waitCalm;
    private Boolean delivered;
    private Boolean accepted;
}

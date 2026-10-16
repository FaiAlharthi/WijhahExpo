package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

// pavilion queue now and for the rest of the day
@Data
@AllArgsConstructor
@NoArgsConstructor
public class CrowdPavilionResponse {
    private Integer pavilionId;
    private String pavilionName;
    private Integer waitNow;
    private String level;
    private Integer capacity;
    private Integer avgVisitMinutes;
    private String calmAt;           // next time it is expected to be calm (HH:mm), null if it is calm now or stays crowded
    private List<CrowdSlotResponse> slots;
}

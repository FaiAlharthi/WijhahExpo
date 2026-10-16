package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.util.List;
import java.util.Set;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class RoadmapResponse {
    private Integer roadmapId;
    private LocalDate visitDate;
    private Integer entranceId;
    private String entranceName;
    private String summary;
    private Boolean aiUsed;
    private List<RoadmapBreakResponse> breaks;
    private List<RoadmapStopResponse> stops;
    private Set<String> accessibilityNeeds;
    private Boolean whatsappAlerts;
}

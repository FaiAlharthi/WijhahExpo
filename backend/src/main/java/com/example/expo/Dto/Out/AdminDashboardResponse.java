package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

// all admin statistics in one response
@Data
@AllArgsConstructor
@NoArgsConstructor
public class AdminDashboardResponse {
    private Long totalVisitors;
    private Long totalCheckIns;
    private Long totalRoadmaps;
    private List<PavilionStatResponse> mostVisitedPavilions;
    private List<PavilionStatResponse> topRatedPavilions;
    private List<PavilionStatResponse> lowestRatedPavilions;
    private List<CountResponse> topInterests;
    private List<CountResponse> visitsPerDay;
    private List<CountResponse> visitsPerZone;
    private List<CountResponse> entrances;
    private Long roadmapsWithNeeds;                          // trips with someone who has a need
    private List<CountResponse> accessibilityNeeds;          // how many trips asked for each need
    private List<AccessibilityConflictResponse> accessibilityConflicts; // official data the visitors disagree with
    private List<CrowdStatusResponse> crowdedNow;            // pavilions with the longest expected queue now
    private Long alertsSentToday;                            // WhatsApp crowd alerts sent today
    private Long alertsAcceptedToday;                        // alerts the visitors accepted (pavilion moved in the plan)
}

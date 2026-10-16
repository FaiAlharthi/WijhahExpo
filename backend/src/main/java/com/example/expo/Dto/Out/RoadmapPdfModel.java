package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

// everything the PDF template (templates/journey.xhtml) needs, filled in JourneyPdfService
@Data
@NoArgsConstructor
@AllArgsConstructor
public class RoadmapPdfModel {
    private String title;
    private String dateLabel;
    private String departureTime;
    private String distanceKm;      // null when the map scale is not set, the card is hidden then
    private String partyLine;      // e.g. "عدد المرافقين: 3 | مع أطفال", null for a solo trip (the line is hidden)
    private String entranceName;
    private String exitName;
    private Integer stopsCount;
    private Integer mapWidth;       // px, the map box in the PDF
    private Integer mapHeight;      // px, same ratio as the map bounds so nothing is stretched differently from the web map
    private String closingMessage; // the friendly line before the footer, singular or plural
    private String routePoints;     // "x,y x,y ..." in percent of the map box
    private List<StopView> stops;
    private List<GateView> gates;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class StopView {
        private Integer order;
        private String name;
        private String zone;
        private String visitTime;   // null until the visitor checks in
        private String status;      // STAMPED (visited) or PLANNED
        private String x;           // percent of the map box, null if the pavilion has no location
        private String y;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class GateView {
        private String label;       // entry or exit
        private String x;
        private String y;
    }
}

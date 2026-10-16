package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

// pavilion page: info and every review, newest first (no average)
@Data
@AllArgsConstructor
@NoArgsConstructor
public class PavilionDetailsResponse {
    private Integer pavilionId;
    private String name;
    private String country;
    private String description;
    private String imageUrl;
    private Integer zoneId;
    private String zoneName;
    private Double x;
    private Double y;
    private List<PavilionReviewResponse> reviews;
    private List<PavilionAccessibilityResponse> accessibility;
}

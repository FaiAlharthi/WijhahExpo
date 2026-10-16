package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// pavilion numbers for the dashboard
@Data
@AllArgsConstructor
@NoArgsConstructor
public class PavilionStatResponse {
    private Integer pavilionId;
    private String name;
    private String country;
    private String zoneName;
    private Long visits;
    private Double averageRating;
    private Long reviewsCount;
}

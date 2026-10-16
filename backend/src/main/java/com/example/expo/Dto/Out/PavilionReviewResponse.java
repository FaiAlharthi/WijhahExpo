package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

// one visitor review shown on the pavilion page
@Data
@AllArgsConstructor
@NoArgsConstructor
public class PavilionReviewResponse {
    private Integer reviewId;
    private String visitorName;
    private Integer rating;
    private String comment;
    private LocalDateTime createdAt;
}

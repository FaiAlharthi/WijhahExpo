package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

// one stamp in the passport
@Data
@AllArgsConstructor
@NoArgsConstructor
public class PassportVisitResponse {
    private Integer visitId;
    private Integer pavilionId;
    private String pavilionName;
    private String country;
    private String zoneName;
    private String imageUrl;
    // check-in time
    private LocalDateTime visitedAt;
}

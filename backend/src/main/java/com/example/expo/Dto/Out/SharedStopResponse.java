package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// a stop of someone else's shared roadmap, without anything about his progress (visited or not)
@Data
@AllArgsConstructor
@NoArgsConstructor
public class SharedStopResponse {
    private Integer stopOrder;
    private Integer pavilionId;
    private String pavilionName;
    private String zoneName;
    private String imageUrl;
}

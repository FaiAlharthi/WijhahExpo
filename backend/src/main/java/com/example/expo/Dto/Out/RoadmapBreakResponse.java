package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class RoadmapBreakResponse {
    private String type;
    private String time;
    private Integer minutes;
    private String note;
}

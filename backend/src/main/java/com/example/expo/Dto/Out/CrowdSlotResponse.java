package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// expected queue in one 15 minute slot of the day
@Data
@AllArgsConstructor
@NoArgsConstructor
public class CrowdSlotResponse {
    private String time;             // HH:mm, start of the slot
    private Integer waitMinutes;
    private String level;
}

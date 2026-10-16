package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class PassportStampDTO {
    private Integer stampId;
    private String title;
    private String imageUrl;
    private Integer pavilionId;
    private String pavilionName;
    private Boolean earned;           // false = faded stamp in the passport
    private LocalDateTime earnedAt;   // first check-in time, null if not earned
}

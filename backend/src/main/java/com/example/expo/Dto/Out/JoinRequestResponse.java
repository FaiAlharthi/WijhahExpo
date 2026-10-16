package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

// one incoming join request, as the founder sees it
@Data
@AllArgsConstructor
@NoArgsConstructor
public class JoinRequestResponse {
    private Integer requestId;
    private String status;
    private String message;
    private LocalDateTime createdAt;
    private String firstName;
    private String nationality;
    private List<InterestResponse> interests;
    private Integer commonInterests; // interests shared with the founder
}

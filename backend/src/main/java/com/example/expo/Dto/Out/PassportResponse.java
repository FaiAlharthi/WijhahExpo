package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class PassportResponse {
    private Integer passportId;
    private String passportNumber;
    private Integer visitsCount;
    // newest visit first
    private List<PassportVisitResponse> visits;
}

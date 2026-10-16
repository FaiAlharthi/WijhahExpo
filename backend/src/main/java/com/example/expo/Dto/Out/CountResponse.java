package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// a name and how many times it appears, used in the dashboard
@Data
@AllArgsConstructor
@NoArgsConstructor
public class CountResponse {
    private String name;
    private Long count;
}

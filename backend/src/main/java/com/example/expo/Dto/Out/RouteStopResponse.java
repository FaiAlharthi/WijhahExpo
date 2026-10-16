package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// one stop on the route, visited ones stay with isVisited true
@Data
@AllArgsConstructor
@NoArgsConstructor
public class RouteStopResponse {
    private Integer visitId;
    private Integer stopOrder;
    private Integer pavilionId;
    private String pavilionName;
    private Boolean isVisited;
}

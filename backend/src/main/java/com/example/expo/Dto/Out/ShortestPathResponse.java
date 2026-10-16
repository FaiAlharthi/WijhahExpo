package com.example.expo.Dto.Out;

import com.example.expo.Model.Location;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class ShortestPathResponse {
    private Double totalDistance;
    private List<Location> locations;
}
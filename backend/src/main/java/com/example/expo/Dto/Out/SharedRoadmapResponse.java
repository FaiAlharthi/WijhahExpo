package com.example.expo.Dto.Out;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

// what other visitors see in "Find a group", only the fields the owner agreed to show
@Data
@AllArgsConstructor
@NoArgsConstructor
public class SharedRoadmapResponse {
    private Integer roadmapId;
    private LocalDate visitDate;
    private LocalTime arrivalTime;
    private LocalTime departureTime;
    private String visitPace;
    private String firstName;
    private String nationality;
    private List<InterestResponse> interests;
    private Integer commonInterests; // how many of the owner interests the viewer has too
    private String shareNote;
    private String entranceName;
    private List<SharedStopResponse> stops;
    private Integer copyCount;
    private Boolean locked;

    // only sent when the owner turned on "show my number", otherwise it is not in the JSON at all
    @JsonInclude(JsonInclude.Include.NON_NULL)
    private String phone;
}

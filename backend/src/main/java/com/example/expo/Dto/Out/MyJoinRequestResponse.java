package com.example.expo.Dto.Out;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalTime;

// one of the requester's own join requests and its current status
@Data
@AllArgsConstructor
@NoArgsConstructor
public class MyJoinRequestResponse {
    private Integer requestId;
    private String status;              // PENDING / ACCEPTED / REJECTED / WITHDRAWN
    private String message;
    private Integer roadmapId;          // the founder's shared roadmap
    private String ownerFirstName;
    private String ownerNationality;
    private LocalDate visitDate;
    private LocalTime arrivalTime;
    private LocalTime departureTime;
    private String entranceName;
    private Integer stopsCount;

    // set only when the request is ACCEPTED
    @JsonInclude(JsonInclude.Include.NON_NULL)
    private Integer memberRoadmapId;    // the member's own copy to open in the journey

    // the founder's WhatsApp, only when ACCEPTED and the founder turned on "show contact"
    @JsonInclude(JsonInclude.Include.NON_NULL)
    private String ownerPhone;
}

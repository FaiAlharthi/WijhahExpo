package com.example.expo.Dto.Out;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

// the group view for a member or the founder: the read-only plan, the members, and the founder's contact
@Data
@AllArgsConstructor
@NoArgsConstructor
public class GroupResponse {
    private Integer roadmapId;
    private String founderFirstName;
    private String founderNationality;
    private LocalDate visitDate;
    private LocalTime arrivalTime;
    private LocalTime departureTime;
    private String entranceName;
    private Boolean confirmed;
    private List<SharedStopResponse> stops;
    private List<GroupMemberResponse> members;
    private Integer capacity;
    private Integer memberCount;    // founder + accepted members
    private Boolean full;
    private Boolean viewerIsFounder;

    // the founder's WhatsApp, shown to the founder and to accepted members when the founder turned it on
    @JsonInclude(JsonInclude.Include.NON_NULL)
    private String founderPhone;
}

package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// one accepted member of a group (no contact details of members are shared)
@Data
@AllArgsConstructor
@NoArgsConstructor
public class GroupMemberResponse {
    private String firstName;
    private String nationality;
    private Boolean isFounder;
}

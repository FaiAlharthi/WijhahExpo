package com.example.expo.Dto.In;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// admin changes the status of one need in a pavilion
@Data
@AllArgsConstructor
@NoArgsConstructor
public class AccessibilityUpdateRequest {

    @NotEmpty(message = "status cannot be empty")
    @Pattern(regexp = "^(ACCESSIBLE|PARTIAL|NOT_ACCESSIBLE)$", message = "status must be ACCESSIBLE, PARTIAL or NOT_ACCESSIBLE")
    private String status;

    @Size(max = 200, message = "note must be 200 characters max")
    private String note;

    @Size(max = 200, message = "arabic note must be 200 characters max")
    private String noteAr;
}

package com.example.expo.Dto.In;

import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// admin marks a path as step free (no stairs) and shaded
@Data
@AllArgsConstructor
@NoArgsConstructor
public class PathAccessibilityRequest {

    @NotNull(message = "step free cannot be empty")
    private Boolean stepFree;

    @NotNull(message = "shaded cannot be empty")
    private Boolean shaded;
}

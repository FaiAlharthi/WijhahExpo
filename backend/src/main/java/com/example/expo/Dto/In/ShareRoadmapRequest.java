package com.example.expo.Dto.In;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// the visitor publishes his roadmap in "Find a group"
@Data
@AllArgsConstructor
@NoArgsConstructor
public class ShareRoadmapRequest {

    @Size(max = 140, message = "Share note must be 140 letters max")
    private String shareNote; // optional

    @NotNull(message = "Show contact cannot be empty!")
    private Boolean showContact; // true = his WhatsApp number is shown to the people who see the roadmap

    @NotEmpty(message = "Audience cannot be empty!")
    @Pattern(regexp = "^(ALL|SAME_GENDER)$", message = "Audience must be ALL or SAME_GENDER.")
    private String audience;
}

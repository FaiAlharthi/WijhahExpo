package com.example.expo.Dto.In;

import jakarta.validation.constraints.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Set;

// answers of the day questions, sent before generating a roadmap
@Data
@AllArgsConstructor
@NoArgsConstructor
public class GenerateRoadmapRequest {

    @NotNull(message = "visit date cannot be empty")
    private LocalDate visitDate;

    @NotEmpty(message = "party type cannot be empty")
    @Pattern(regexp = "^(SOLO|GROUP)$", message = "party type must be SOLO or GROUP")
    private String partyType;

    @NotNull(message = "party size cannot be empty")
    @Min(value = 1, message = "party size must be at least 1")
    private Integer partySize;

    @NotNull(message = "arrival time cannot be empty")
    private LocalTime arrivalTime;

    @NotNull(message = "departure time cannot be empty")
    private LocalTime departureTime;

    @NotEmpty(message = "experience types cannot be empty")
    private Set<@Pattern(regexp = "^(ENTERTAINMENT|CULTURAL|EDUCATIONAL|RELAXATION|CULINARY)$", message = "experience type must be ENTERTAINMENT, CULTURAL, EDUCATIONAL, RELAXATION or CULINARY") String> experienceTypes;

    @NotEmpty(message = "visit pace cannot be empty")
    @Pattern(regexp = "^(RELAXED|INTENSIVE)$", message = "visit pace must be RELAXED or INTENSIVE")
    private String visitPace;

    private Boolean includePrayerBreaks = false;

    private Boolean includeMealBreaks = false;

    private Boolean includeChildRestBreaks = false;

    @NotNull(message = "allow revisits cannot be empty")
    private Boolean allowRevisits;

    // optional, extra interests for this day only
    private List<Integer> extraInterestIds;

    // optional, WhatsApp alert when a crowded pavilion of the roadmap is about to be calm
    private Boolean whatsappAlerts = false;

    // optional, needs of anyone in this trip, empty or missing when there are none
    private Set<@Pattern(regexp = "^(WHEELCHAIR|LIMITED_MOBILITY|VISUAL|HEARING|SENSORY|STROLLER_ELDERLY)$", message = "accessibility need must be WHEELCHAIR, LIMITED_MOBILITY, VISUAL, HEARING, SENSORY or STROLLER_ELDERLY") String> accessibilityNeeds;
}

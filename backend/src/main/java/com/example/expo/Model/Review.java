package com.example.expo.Model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.*;

import java.time.LocalDateTime;
import java.util.Set;

@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class Review {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotNull(message = "Rating cannot be empty")
    @Min(value = 1, message = "Rating must be at least 1")
    @Max(value = 5, message = "Rating must be at most 5")
    @Column(nullable = false)
    private Integer rating;

    @Size(max = 500, message = "A comment must be less than 500 characters")
    @Column(length = 500)
    private String comment;

    @Column(updatable = false)
    private LocalDateTime createdAt;

    // optional: was the pavilion really suitable for the needs of the trip
    @Pattern(regexp = "^(SUITABLE|PARTIAL|NOT_SUITABLE)$", message = "accessibility verdict must be SUITABLE, PARTIAL or NOT_SUITABLE")
    @Column(columnDefinition = "VARCHAR(12)")
    private String accessibilityVerdict;

    // the needs the verdict is about, taken from the day roadmap or sent by the visitor
    @ElementCollection
    private Set<@Pattern(regexp = "^(WHEELCHAIR|LIMITED_MOBILITY|VISUAL|HEARING|SENSORY|STROLLER_ELDERLY)$",
            message = "accessibility need must be WHEELCHAIR, LIMITED_MOBILITY, VISUAL, HEARING, SENSORY or STROLLER_ELDERLY")
            String> accessibilityNeeds;

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Pavilion pavilion;

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Visitor visitor;
}

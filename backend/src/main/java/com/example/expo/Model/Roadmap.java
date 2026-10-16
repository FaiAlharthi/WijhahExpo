package com.example.expo.Model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.Set;

@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class Roadmap {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotNull(message = "Visit date cannot be empty!")
    @Column(columnDefinition = "DATE NOT NULL")
    private LocalDate visitDate; // Checked in service

    @NotEmpty(message = "Party type cannot be empty!")
    @Pattern(regexp = "^(SOLO|GROUP)$", message = "Party type must be SOLO or GROUP.")
    @Column(columnDefinition = "VARCHAR(5) NOT NULL")
    private String partyType;

    @NotNull(message = "Party size cannot be empty!")
    @Min(value = 1, message = "Party size must be at least 1")
    @Column(columnDefinition = "INTEGER NOT NULL")
    private Integer partySize;

    @NotNull(message = "Arrival time cannot be empty!")
    @Column(columnDefinition = "TIME NOT NULL")
    private LocalTime arrivalTime;

    // checked in service
    @NotNull(message = "Departure time cannot be empty!")
    @Column(columnDefinition = "TIME NOT NULL")
    private LocalTime departureTime;

    @NotEmpty(message = "Experience types cannot be empty!")
    @ElementCollection
    private Set<@Pattern(regexp = "^(ENTERTAINMENT|CULTURAL|EDUCATIONAL|RELAXATION|CULINARY)$",
            message = "Experience type must be ENTERTAINMENT, CULTURAL, EDUCATIONAL, RELAXATION, or CULINARY.")
            String> experienceTypes;

    // needs of anyone in this trip (the visitor or someone with him), empty when there are none
    @ElementCollection
    private Set<@Pattern(regexp = "^(WHEELCHAIR|LIMITED_MOBILITY|VISUAL|HEARING|SENSORY|STROLLER_ELDERLY)$",
            message = "accessibility need must be WHEELCHAIR, LIMITED_MOBILITY, VISUAL, HEARING, SENSORY or STROLLER_ELDERLY")
            String> accessibilityNeeds;

    // the visitor agreed to get WhatsApp alerts when a crowded pavilion in this roadmap is about to be calm
    @Column(columnDefinition = "BOOLEAN DEFAULT FALSE")
    private Boolean whatsappAlerts = false;

    @NotEmpty(message = "Visit pace cannot be empty!")
    @Pattern(regexp = "^(RELAXED|INTENSIVE)$", message = "Visit pace must be RELAXED or INTENSIVE.")
    @Column(columnDefinition = "VARCHAR(9) NOT NULL")
    private String visitPace;

    @Column(columnDefinition = "BOOLEAN DEFAULT FALSE")
    private Boolean includePrayerBreaks = false;

    @Column(columnDefinition = "BOOLEAN DEFAULT FALSE")
    private Boolean includeMealBreaks = false;

    @Column(columnDefinition = "BOOLEAN DEFAULT FALSE")
    private Boolean includeChildRestBreaks = false;

    @NotNull(message = "Allow revisits cannot be empty!")
    @Column(columnDefinition = "BOOLEAN NOT NULL")
    private Boolean allowRevisits; // True == can include visited pavilions

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime createdAt; // Set in service

    @Column(columnDefinition = "TEXT")
    private String aiBreaks; // Set by AI, breaks are saved as json text.

    @Column(columnDefinition = "TEXT")
    private String aiSummary;

    // ===== Group sharing ("Find a group") =====
    // the owner published this roadmap, others can see it and copy it into their own journey
    @Column(columnDefinition = "BOOLEAN DEFAULT FALSE")
    private Boolean isShared = false;

    @Size(max = 140, message = "Share note must be 140 letters max")
    @Column(columnDefinition = "VARCHAR(140)")
    private String shareNote;

    // the owner agreed to show his WhatsApp number to the people who see this roadmap
    @Column(columnDefinition = "BOOLEAN DEFAULT FALSE")
    private Boolean showContact = false;

    @Pattern(regexp = "^(ALL|SAME_GENDER)$", message = "Share audience must be ALL or SAME_GENDER.")
    @Column(columnDefinition = "VARCHAR(11) DEFAULT 'ALL'")
    private String shareAudience = "ALL";

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime sharedAt;

    // how many visitors copied this roadmap, increased in the database
    @Column(columnDefinition = "INTEGER DEFAULT 0")
    private Integer copyCount = 0;

    // the id of the roadmap this one was copied from, null for roadmaps made by the visitor himself
    @Column(columnDefinition = "INTEGER")
    private Integer copiedFromId;

    // once the owner confirms the roadmap it is fixed and cannot be edited, null = still editable
    @Column(columnDefinition = "DATETIME")
    private LocalDateTime lockedAt;

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Visitor visitor;

    @ManyToOne
    @JoinColumn
    private Entrance entrance; // The entrance the visitor starts from

    @ManyToMany
    private Set<Interest> extraInterests; // Roadmap stops, optional interests added for this day ONLY.

    @OneToMany(mappedBy = "roadmap")
    private Set<Visit> visits;
}

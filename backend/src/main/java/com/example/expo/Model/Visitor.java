package com.example.expo.Model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

import java.util.Set;

@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class Visitor {

    // ==== Variables ====
    @Id
    private Integer id;

    @NotNull(message = "Age cannot be empty!")
    @Min(value = 1, message = "Age must be at least 1")
    @Max(value = 120, message = "Age must be at most 120")
    @Column(columnDefinition = "INTEGER NOT NULL")
    private Integer age;

    @NotEmpty(message = "Gender cannot be empty!")
    @Pattern(regexp = "^(MALE|FEMALE)$", message = "Gender must be MALE or FEMALE.")
    @Column(columnDefinition = "VARCHAR(6) NOT NULL")
    private String gender;

    @NotEmpty(message = "Preferred language cannot be empty!")
    @Pattern(regexp = "^(AR|EN)$", message = "Preferred language must be AR or EN.")
    @Column(columnDefinition = "VARCHAR(2) NOT NULL")
    private String preferredLanguage;

    @NotEmpty(message = "Nationality cannot be empty!")
    @Size(max = 50, message = "Nationality cannot be longer that 50 letters.")
    @Column(columnDefinition = "VARCHAR(50) NOT NULL")
    private String nationality;

    // ===== Relations =====
    @OneToOne
    @MapsId
    @JsonIgnore
    private User user;

    @OneToOne(cascade = CascadeType.ALL, mappedBy = "visitor")
    private Passport passport;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "visitor")
    private Set<Roadmap> roadmaps;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "visitor")
    private Set<Review> reviews;

    @ManyToMany
    private Set<Interest> interests;
}

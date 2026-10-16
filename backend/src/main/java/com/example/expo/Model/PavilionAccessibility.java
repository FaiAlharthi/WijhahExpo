package com.example.expo.Model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.*;

// how ready a pavilion is for one type of need, every pavilion has one row per need
@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
@Table(uniqueConstraints = @UniqueConstraint(columnNames = {"pavilion_id", "need_type"}))
public class PavilionAccessibility {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotEmpty(message = "need type cannot be empty")
    @Pattern(regexp = "^(WHEELCHAIR|LIMITED_MOBILITY|VISUAL|HEARING|SENSORY|STROLLER_ELDERLY)$",
            message = "need type must be WHEELCHAIR, LIMITED_MOBILITY, VISUAL, HEARING, SENSORY or STROLLER_ELDERLY")
    @Column(columnDefinition = "VARCHAR(16) NOT NULL")
    private String needType;

    @NotEmpty(message = "status cannot be empty")
    @Pattern(regexp = "^(ACCESSIBLE|PARTIAL|NOT_ACCESSIBLE)$", message = "status must be ACCESSIBLE, PARTIAL or NOT_ACCESSIBLE")
    @Column(columnDefinition = "VARCHAR(14) NOT NULL")
    private String status;

    @Size(max = 200, message = "note must be 200 characters max")
    @Column(length = 200)
    private String note;

    @Size(max = 200, message = "arabic note must be 200 characters max")
    @Column(length = 200)
    private String noteAr;

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Pavilion pavilion;
}

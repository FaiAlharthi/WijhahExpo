package com.example.expo.Model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import lombok.*;

import java.util.Set;

@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class Zone {

    // ==== Variables ====
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotEmpty(message = "Name cannot be empty!")
    @Size(min = 2, max = 50, message = "Name must be between 2 and 50 characters.")
    @Column(nullable = false, unique = true)
    private String name;

    @Size(max = 500, message = "Description must be less than 500 characters.")
    @Column(length = 500)
    private String description;

    // ==== Relations ====
    @OneToOne
    @JoinColumn
    private Location location;

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "zone")
    private Set<Pavilion> pavilions;
}

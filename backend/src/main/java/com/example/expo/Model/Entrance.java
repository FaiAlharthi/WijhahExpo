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
public class Entrance {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotEmpty(message = "Name cannot be empty.")
    @Size(max = 50, message = "Name cannot be longer than 50 letters.")
    @Column(columnDefinition = "VARCHAR(50) NOT NULL UNIQUE")
    private String name;

    //Relations
    @OneToOne
    @JoinColumn
    private Location location;

    @OneToMany(mappedBy = "entrance")
    @JsonIgnore
    private Set<Roadmap> roadmaps;
}

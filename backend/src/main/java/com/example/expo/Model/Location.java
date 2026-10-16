package com.example.expo.Model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.NotNull;
import lombok.*;

import java.util.Set;

@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class Location {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotNull(message = "X cannot be empty!")
    @Column(nullable = false)
    private Double x;

    @NotNull(message = "Y cannot be empty!")
    @Column(nullable = false)
    private Double y;

    //Relations
    @OneToOne(cascade = CascadeType.ALL, mappedBy = "location")
    @JsonIgnore
    private Zone zone;

    @OneToOne(cascade = CascadeType.ALL, mappedBy = "location")
    @JsonIgnore
    private Pavilion pavilion;
}

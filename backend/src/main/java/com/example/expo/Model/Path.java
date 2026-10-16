package com.example.expo.Model;

import jakarta.persistence.*;
import lombok.*;

@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class Path {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(nullable = false)
    private Double distance;  // Automatically counted in path service from X to Y

    @Column(columnDefinition = "BOOLEAN")
    private Boolean stepFree; // no stairs on this path, null counts as step free

    @Column(columnDefinition = "BOOLEAN")
    private Boolean shaded; // covered from the sun, null counts as not shaded

    //Relations
    @ManyToOne
    @JoinColumn
    private Location fromLocation;

    @ManyToOne
    @JoinColumn
    private Location toLocation;
}
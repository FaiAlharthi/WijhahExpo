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
public class Pavilion {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotEmpty(message = "Name cannot be empty")
    @Size(min = 2, max = 100, message = "Name must be between 2 and 100 characters")
    @Column(nullable = false, unique = true)
    private String name;//unique

    @NotEmpty(message = "Country cannot be empty")
    @Size(max = 100, message = "Country must be less than 100 characters")
    @Column(nullable = false)
    private String country;

    @NotEmpty(message = "Description cannot be empty")
    @Size(max = 1000, message = "Description must be less than 1000 characters")
    @Column(length = 1000,nullable = false)
    private String description;
    private String imageUrl;

    @Min(value = 1, message = "capacity must be at least 1")
    @Column(columnDefinition = "INTEGER")
    private Integer capacity; // people inside at the same time, used for the queue estimate

    @Min(value = 1, message = "visit minutes must be at least 1")
    @Column(columnDefinition = "INTEGER")
    private Integer avgVisitMinutes; // usual time inside the pavilion

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Zone zone;

    @OneToOne
    @JoinColumn
    private Location location; //ماعليها جاسون اقنور معناته اتاكد في الكرد مافي تكرار

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "pavilion")
    private Set<Review> reviews; //نفس الشي من ناحية

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "pavilion")
    @JsonIgnore
    private Set<Visit> visits;
    
    @OneToOne(cascade = CascadeType.ALL, mappedBy = "pavilion")
    @JsonIgnore
    private Stamp stamp; // the stamp a passport earns by visiting this pavilion

    @OneToMany(cascade = CascadeType.ALL, mappedBy = "pavilion", orphanRemoval = true)
    private Set<PavilionAccessibility> accessibility; // one status for every type of need

}

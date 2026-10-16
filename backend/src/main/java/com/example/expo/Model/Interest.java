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
public class Interest {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotEmpty(message = "Name cannot be empty!")
    @Size(min = 2, max = 50, message = "Name must be between 2 and 50 characters.")
    @Column(nullable = false, unique = true)
    private String name;

    // arabic name for the frontend
    @NotEmpty(message = "Arabic name cannot be empty!")
    @Size(min = 2, max = 50, message = "Arabic name must be between 2 and 50 characters.")
    @Column(nullable = false)
    private String nameAr;

    //Relations
    @ManyToMany(mappedBy = "interests")
    @JsonIgnore
    private Set<Visitor> visitors;
}

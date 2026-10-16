package com.example.expo.Model;

import com.fasterxml.jackson.annotation.JsonIgnore;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class Visit {

    // Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime visitedAt; // Null until check-in

    @Column(columnDefinition = "BOOLEAN default false")
    private Boolean isVisited = false;

    @Column(columnDefinition = "INTEGER")
    private Integer stopOrder;  // Order in the roadmap, null if not in a roadmap

    //Relations
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Passport passport;

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Roadmap roadmap;

    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Pavilion pavilion;

    @JsonProperty("pavilionName")
    public String getPavilionName() {
        if (pavilion == null) {
            return null;
        }
        return pavilion.getName();
    }  // يرجع اسم الجناح في الـ JSON بدل الجناح كامل لان عليه جاسون اقنورز ال بافلين فيصير نحط اسمه بس

    @JsonProperty("pavilionId")
    public Integer getPavilionId() {
        if (pavilion == null) {
            return null;
        }
        return pavilion.getId();
    } // Pavilion id for the frontend, used in check-in

}

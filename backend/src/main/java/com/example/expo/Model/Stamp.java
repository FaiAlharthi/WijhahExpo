package com.example.expo.Model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class Stamp {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @NotEmpty(message = "Title cannot be empty")
    @Size(max = 120, message = "Title must be less than 120 characters")
    @Column(nullable = false)
    private String title; // e.g. "Japan Pavilion Stamp"

    private String imageUrl; // the stamp design shown in the passport

    //Relations
    // one stamp design per pavilion, a passport earns it by visiting the pavilion
    @OneToOne
    @JoinColumn
    @JsonIgnore
    private Pavilion pavilion;

    @JsonProperty("pavilionId")
    public Integer getPavilionId() {
        if (pavilion == null) {
            return null;
        }
        return pavilion.getId();
    }

    @JsonProperty("pavilionName")
    public String getPavilionName() {
        if (pavilion == null) {
            return null;
        }
        return pavilion.getName();
    }

    //Temporary
    // stamp design file in static/stamps, named after the country: /stamps/Japan@1x.png
    // joint pavilions (country has commas, e.g. "Latvia, Lithuania") use the pavilion name: "The Baltics@1x.png"
    public static String imageUrlFor(Pavilion pavilion) {
        String fileName = pavilion.getCountry().trim();
        if (fileName.contains(",")) {
            fileName = pavilion.getName().replace(" Pavilion", "").trim();
        }
        return "/stamps/" + fileName.replace(" ", "%20") + "@1x.png";
    }
}
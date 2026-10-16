package com.example.expo.Model;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import jakarta.validation.constraints.Size;
import lombok.*;

import java.time.LocalDateTime;

// a request from a visitor to join another visitor's shared plan ("Find a group").
// the founder accepts or rejects it; on accept a locked copy of the plan is created for the member.
@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class JoinRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    // PENDING -> ACCEPTED / REJECTED, or WITHDRAWN by the requester
    @Column(columnDefinition = "VARCHAR(10) DEFAULT 'PENDING'")
    private String status = "PENDING";

    @Size(max = 140, message = "Message must be 140 letters max")
    @Column(columnDefinition = "VARCHAR(140)")
    private String message;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime createdAt;

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime decidedAt;

    // the member's locked copy of the plan, set when the request is accepted
    @Column(columnDefinition = "INTEGER")
    private Integer memberRoadmapId;

    // the founder's shared roadmap being joined
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Roadmap roadmap;

    // the visitor who wants to join
    @ManyToOne
    @JoinColumn
    @JsonIgnore
    private Visitor requester;
}

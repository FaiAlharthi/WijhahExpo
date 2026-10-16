package com.example.expo.Model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;
import java.time.LocalTime;

// a WhatsApp alert: a crowded pavilion of the visitor's roadmap is about to be calm
// keeps ids only, so deleting a roadmap, visitor or pavilion is never blocked by old alerts
@Setter
@Getter
@AllArgsConstructor
@NoArgsConstructor
@Entity
public class CrowdAlert {

    //Variables
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(nullable = false)
    private Integer visitorId;

    @Column(nullable = false)
    private Integer roadmapId;

    @Column(nullable = false)
    private Integer pavilionId;

    @Column(columnDefinition = "DATETIME NOT NULL")
    private LocalDateTime sentAt;

    @Column(columnDefinition = "TIME")
    private LocalTime calmAt;        // when the pavilion is expected to be calm

    private Integer waitNow;         // queue minutes when the alert was sent
    private Integer waitCalm;        // expected queue minutes at calmAt

    @Column(columnDefinition = "BOOLEAN DEFAULT FALSE")
    private Boolean delivered = false; // UltraMsg said the message was sent

    @Column(columnDefinition = "BOOLEAN DEFAULT FALSE")
    private Boolean accepted = false;  // the visitor moved the pavilion to be the next stop

    @Column(columnDefinition = "DATETIME")
    private LocalDateTime acceptedAt;
}

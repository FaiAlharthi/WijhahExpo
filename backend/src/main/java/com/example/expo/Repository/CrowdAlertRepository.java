package com.example.expo.Repository;

import com.example.expo.Model.CrowdAlert;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public interface CrowdAlertRepository extends JpaRepository<CrowdAlert, Integer> {
    CrowdAlert findCrowdAlertById(Integer id);
    List<CrowdAlert> findCrowdAlertsByVisitorIdAndSentAtBetweenOrderBySentAtDesc(Integer visitorId, LocalDateTime start, LocalDateTime end);
    Boolean existsByRoadmapIdAndPavilionId(Integer roadmapId, Integer pavilionId);
    Long countBySentAtBetween(LocalDateTime start, LocalDateTime end);
    Long countByAcceptedTrueAndSentAtBetween(LocalDateTime start, LocalDateTime end);
}

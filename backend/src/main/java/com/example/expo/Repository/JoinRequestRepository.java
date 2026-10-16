package com.example.expo.Repository;

import com.example.expo.Model.JoinRequest;
import com.example.expo.Model.Roadmap;
import com.example.expo.Model.Visitor;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface JoinRequestRepository extends JpaRepository<JoinRequest, Integer> {
    JoinRequest findJoinRequestById(Integer id);

    // the founder's inbox for one roadmap, newest first
    List<JoinRequest> findByRoadmapOrderByCreatedAtDesc(Roadmap roadmap);

    // accepted members of a roadmap (also used to count the group size)
    List<JoinRequest> findByRoadmapAndStatus(Roadmap roadmap, String status);

    long countByRoadmapAndStatus(Roadmap roadmap, String status);

    // the requester's own outgoing requests, newest first
    List<JoinRequest> findByRequesterOrderByCreatedAtDesc(Visitor requester);

    // does this requester already have a still-active request (PENDING or ACCEPTED) for this roadmap
    boolean existsByRoadmapAndRequesterAndStatusIn(Roadmap roadmap, Visitor requester, List<String> statuses);

    // the member's own accepted membership of a roadmap
    JoinRequest findByRoadmapAndRequesterAndStatus(Roadmap roadmap, Visitor requester, String status);
}

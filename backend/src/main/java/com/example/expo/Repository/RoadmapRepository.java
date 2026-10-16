package com.example.expo.Repository;

import com.example.expo.Model.Roadmap;
import com.example.expo.Model.Visitor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface RoadmapRepository extends JpaRepository<Roadmap, Integer> {
    Roadmap findRoadmapById(Integer id);

    // every roadmap of one day, used to estimate the crowd
    List<Roadmap> findRoadmapsByVisitDate(LocalDate visitDate);

    // one roadmap per visitor per day
    Roadmap findRoadmapByVisitorAndVisitDate(Visitor visitor, LocalDate visitDate);

    // all roadmaps of the visitor, newest day first
    List<Roadmap> findRoadmapsByVisitorOrderByVisitDateDesc(Visitor visitor);

    // shared roadmaps of one day that this viewer is allowed to see (not his own, SAME_GENDER only for the same gender)
    // the audience is filtered here in the query, never after loading
    @Query("select r from Roadmap r where r.isShared = true and r.visitDate = :date and r.visitor.id <> :viewerId " +
            "and (r.shareAudience = 'ALL' or r.visitor.gender = :gender) order by r.sharedAt desc")
    List<Roadmap> findSharedForViewer(@Param("date") LocalDate date, @Param("viewerId") Integer viewerId,
                                      @Param("gender") String gender, Pageable pageable);

    // +1 in one SQL statement, so two visitors copying at the same time are both counted
    @Modifying
    @Query("update Roadmap r set r.copyCount = coalesce(r.copyCount, 0) + 1 where r.id = :id")
    void increaseCopyCount(@Param("id") Integer id);
}

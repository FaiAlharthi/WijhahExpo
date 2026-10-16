package com.example.expo.Repository;

import com.example.expo.Model.Pavilion;
import com.example.expo.Model.Review;
import com.example.expo.Model.Visitor;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ReviewRepository extends JpaRepository<Review, Integer> {
    Review findReviewById(Integer id);
    Review findReviewByVisitorAndPavilion(Visitor visitor, Pavilion pavilion);
    List<Review> findReviewsByPavilion(Pavilion pavilion);
    @Query("select avg(r.rating) from Review r where r.pavilion.id = ?1")
    Double getAverageRating(Integer pavilionId);

    List<Review> findReviewsByVisitor(Visitor visitor);
    List<Review> findReviewsByPavilionOrderByCreatedAtDesc(Pavilion pavilion);
}

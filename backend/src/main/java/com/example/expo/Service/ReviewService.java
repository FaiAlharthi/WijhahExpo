package com.example.expo.Service;

import com.example.expo.Api.ApiException;
import com.example.expo.Model.*;
import com.example.expo.Repository.PavilionRepository;
import com.example.expo.Repository.ReviewRepository;
import com.example.expo.Repository.VisitorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.Set;
import java.util.List;

@Service
@RequiredArgsConstructor
public class ReviewService {
    private final ReviewRepository reviewRepository;
    private final VisitorRepository visitorRepository;
    private final PavilionRepository pavilionRepository;
    private final ModerationService moderationService;

    public List<Review>getAllReviews(){
        return reviewRepository.findAll();
    }

    public void addReview(Integer visitorId,Integer pavilionId, Review review){
        Visitor visitor=visitorRepository.findVisitorById(visitorId);
        if(visitor == null){
            throw new ApiException("Visitor not found");
        }
        Pavilion pavilion = pavilionRepository.findPavilionById(pavilionId);
        if(pavilion == null){
            throw new ApiException("Pavilion not found");
        }
        Passport passport=visitor.getPassport();
        if(passport==null||passport.getVisits()==null){
            throw new ApiException("You must visit the pavilion before reviewing it");
        }
        boolean visited = false;
        for(Visit visit : passport.getVisits()){
            if(visit.getIsVisited() && visit.getPavilion().getId().equals(pavilionId)){
                visited = true;
            }
        }
        if(!visited){
            throw new ApiException("You must visit the pavilion before reviewing it");
        }


        if(reviewRepository.findReviewByVisitorAndPavilion(visitor, pavilion) != null){
            throw new ApiException("You already reviewed this pavilion");
        }
        // AI checks the comment for racism and rude language
        moderationService.checkComment(review.getComment());
        applyAccessibility(visitor, pavilion, review, review);
        review.setVisitor(visitor);
        review.setPavilion(pavilion);
        review.setCreatedAt(LocalDateTime.now());
        reviewRepository.save(review);
    }




    public void updateReview(Integer visitorId, Integer reviewId, Review review){
        Review oldReview = reviewRepository.findReviewById(reviewId);
        if(oldReview == null){
            throw new ApiException("Review not found");
        }
        if(!oldReview.getVisitor().getId().equals(visitorId)){
            throw new ApiException("You can only update your own review");
        }
        moderationService.checkComment(review.getComment());
        oldReview.setRating(review.getRating());
        oldReview.setComment(review.getComment());
        applyAccessibility(oldReview.getVisitor(), oldReview.getPavilion(), review, oldReview);
        reviewRepository.save(oldReview);
    }

    // the accessibility verdict is about the needs of the trip: sent by the visitor, or taken from the roadmap of that visit
    private void applyAccessibility(Visitor visitor, Pavilion pavilion, Review from, Review to){
        if(from.getAccessibilityVerdict() == null){
            to.setAccessibilityVerdict(null);
            to.setAccessibilityNeeds(new HashSet<>());
            return;
        }
        Set<String> needs = from.getAccessibilityNeeds() == null ? new HashSet<>() : new HashSet<>(from.getAccessibilityNeeds());
        if(needs.isEmpty()){
            needs = tripNeeds(visitor, pavilion);
        }
        if(needs.isEmpty()){
            throw new ApiException("choose the accessibility needs this verdict is about");
        }
        to.setAccessibilityVerdict(from.getAccessibilityVerdict());
        to.setAccessibilityNeeds(needs);
    }

    // needs of the latest roadmap where this pavilion was visited
    private Set<String> tripNeeds(Visitor visitor, Pavilion pavilion){
        Set<String> needs = new HashSet<>();
        Passport passport = visitor.getPassport();
        if(passport == null || passport.getVisits() == null){
            return needs;
        }
        Visit latest = null;
        for(Visit visit : passport.getVisits()){
            if(!visit.getIsVisited() || !visit.getPavilion().getId().equals(pavilion.getId()) || visit.getRoadmap() == null){
                continue;
            }
            Set<String> roadmapNeeds = visit.getRoadmap().getAccessibilityNeeds();
            if(roadmapNeeds == null || roadmapNeeds.isEmpty()){
                continue;
            }
            if(latest == null || (visit.getVisitedAt() != null && latest.getVisitedAt() != null && visit.getVisitedAt().isAfter(latest.getVisitedAt()))){
                latest = visit;
            }
        }
        if(latest != null){
            needs.addAll(latest.getRoadmap().getAccessibilityNeeds());
        }
        return needs;
    }

    // the visitor deletes his own review, the admin can delete any review
    public void deleteReview(User user, Integer reviewId){
        Review review = reviewRepository.findReviewById(reviewId);
        if(review == null){
            throw new ApiException("Review not found");
        }
        if(!"ADMIN".equals(user.getRole()) && !review.getVisitor().getId().equals(user.getId())){
            throw new ApiException("You can only delete your own review");
        }
        reviewRepository.delete(review);
    }

    // متوسط تقييم جناح
    public Double getPavilionAverageRating(Integer pavilionId){
        Pavilion pavilion = pavilionRepository.findPavilionById(pavilionId);
        if(pavilion == null){
            throw new ApiException("Pavilion not found");
        }
        Double average = reviewRepository.getAverageRating(pavilionId);
        if(average == null){
            return 0.0;
        }
        return average;
    }



    // الأجنحة اللي زارها وما قيّمها
    public List<Pavilion> getPendingReviews(Integer visitorId){
        Visitor visitor = visitorRepository.findVisitorById(visitorId);
        if(visitor == null){
            throw new ApiException("Visitor not found");
        }
        if(visitor.getPassport() == null || visitor.getPassport().getVisits() == null){
            throw new ApiException("You did not visit any pavilion yet");
        }
        List<Pavilion> pending = new ArrayList<>();
        for(Visit visit : visitor.getPassport().getVisits()){
            if(visit.getIsVisited()
                    && reviewRepository.findReviewByVisitorAndPavilion(visitor, visit.getPavilion()) == null
                    && !pending.contains(visit.getPavilion())){
                pending.add(visit.getPavilion());
            }
        }
        return pending;
    }


    // تقييماتي
    public List<Review> getVisitorReviews(Integer visitorId){
        Visitor visitor = visitorRepository.findVisitorById(visitorId);
        if(visitor == null){
            throw new ApiException("Visitor not found");
        }
        return reviewRepository.findReviewsByVisitor(visitor);
    }

    // أحدث تقييمات جناح
    public List<Review> getLatestReviews(Integer pavilionId){
        Pavilion pavilion = pavilionRepository.findPavilionById(pavilionId);
        if(pavilion == null){
            throw new ApiException("Pavilion not found");
        }
        return reviewRepository.findReviewsByPavilionOrderByCreatedAtDesc(pavilion);
    }




}

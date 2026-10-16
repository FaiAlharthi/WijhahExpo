package com.example.expo.Controller;


import com.example.expo.Api.ApiResponse;
import com.example.expo.Model.User;
import com.example.expo.Model.Review;
import com.example.expo.Service.ReviewService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/review")
@RequiredArgsConstructor
public class ReviewController {

    private final ReviewService reviewService;

    @GetMapping("/get")
    public ResponseEntity<?> getAllReview() {
        return ResponseEntity.status(200).body(reviewService.getAllReviews());
    }

    @PostMapping("/add/{pavilionId}")
    public ResponseEntity<?> addReview(@AuthenticationPrincipal User user, @PathVariable Integer pavilionId, @RequestBody @Valid Review review) {
        reviewService.addReview(user.getId(), pavilionId, review);
        return ResponseEntity.status(200).body(new ApiResponse("Review added"));
    }

    @PutMapping("/update/{reviewId}")
    public ResponseEntity<?> updateReview(@AuthenticationPrincipal User user, @PathVariable Integer reviewId, @RequestBody @Valid Review review) {
        reviewService.updateReview(user.getId(), reviewId, review);
        return ResponseEntity.status(200).body(new ApiResponse("Review updated"));
    }

    @DeleteMapping("/delete/{reviewId}")
    public ResponseEntity<?> deleteReview(@AuthenticationPrincipal User user, @PathVariable Integer reviewId) {
        reviewService.deleteReview(user, reviewId);
        return ResponseEntity.status(200).body(new ApiResponse("Review deleted"));
    }

    @GetMapping("/pavilion/{pavilionId}/average")
    public ResponseEntity<?> getPavilionAverageRating(@PathVariable Integer pavilionId) {
        return ResponseEntity.status(200).body(reviewService.getPavilionAverageRating(pavilionId));
    }

    @GetMapping("/getPending")
    public ResponseEntity<?> getPendingReviews(@AuthenticationPrincipal User user) {
        return ResponseEntity.status(200).body(reviewService.getPendingReviews(user.getId()));
    }

    @GetMapping("/getMyReviews")
    public ResponseEntity<?> getVisitorReviews(@AuthenticationPrincipal User user) {
        return ResponseEntity.status(200).body(reviewService.getVisitorReviews(user.getId()));
    }

    @GetMapping("/pavilion/{pavilionId}/latest")
    public ResponseEntity<?> getLatestReviews(@PathVariable Integer pavilionId) {
        return ResponseEntity.status(200).body(reviewService.getLatestReviews(pavilionId));
    }
}

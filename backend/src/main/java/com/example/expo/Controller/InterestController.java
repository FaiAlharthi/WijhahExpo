package com.example.expo.Controller;

import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;



import com.example.expo.Api.ApiResponse;
import com.example.expo.Model.Interest;
import com.example.expo.Service.InterestService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/interest")
@RequiredArgsConstructor
public class InterestController {

    private final InterestService interestService;

    @GetMapping("/get")
    public ResponseEntity<?> getAllInterest() {
        return ResponseEntity.status(200).body(interestService.getAllInterest());
    }

    @PostMapping("/add")
    public ResponseEntity<?> addInterest(@RequestBody @Valid Interest interest) {
        interestService.addInterest(interest);
        return ResponseEntity.status(200).body(new ApiResponse("Interest added"));
    }

    @PutMapping("/update/{id}")
    public ResponseEntity<?> updateInterest(@PathVariable Integer id, @RequestBody @Valid Interest interest) {
        interestService.updateInterest(id, interest);
        return ResponseEntity.status(200).body(new ApiResponse("Interest updated"));
    }

    @DeleteMapping("/delete/{id}")
    public ResponseEntity<?> deleteInterest(@PathVariable Integer id) {
        interestService.deleteInterest(id);
        return ResponseEntity.status(200).body(new ApiResponse("Interest deleted"));
    }
}
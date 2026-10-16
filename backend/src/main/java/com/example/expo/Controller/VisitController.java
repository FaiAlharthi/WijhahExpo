package com.example.expo.Controller;

import com.example.expo.Api.ApiResponse;
import com.example.expo.Service.VisitService;
import com.example.expo.Model.User;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/visit")
@RequiredArgsConstructor
public class VisitController {
    private final VisitService visitService;

    @GetMapping("/getAll")
    public ResponseEntity<?> getAllVisits(){
        return ResponseEntity.status(200).body(visitService.getAllVisits());
    }

    @PostMapping("/checkIn/{pavilionId}")
    public ResponseEntity<?> checkIn(@AuthenticationPrincipal User user, @PathVariable Integer pavilionId){
        visitService.checkIn(user.getId(), pavilionId);
        return ResponseEntity.status(200).body(new ApiResponse("check-in done"));
    }
}

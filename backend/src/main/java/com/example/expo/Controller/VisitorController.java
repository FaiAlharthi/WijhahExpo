package com.example.expo.Controller;

import com.example.expo.Api.ApiResponse;
import com.example.expo.Dto.In.VisitorRegisterRequest;
import com.example.expo.Model.Visitor;
import com.example.expo.Service.VisitorService;
import jakarta.validation.Valid;
import com.example.expo.Model.User;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/visitor")
@RequiredArgsConstructor
public class VisitorController {
    private final VisitorService visitorService;

    @PostMapping("/register")
    public ResponseEntity<?> registerVisitor(@RequestBody @Valid VisitorRegisterRequest request){
        visitorService.registerVisitor(request);
        return ResponseEntity.status(200).body(new ApiResponse("visitor registered"));
    }

    @GetMapping("/getAll")
    public ResponseEntity<?> getAllVisitors(){
        return ResponseEntity.status(200).body(visitorService.getAllVisitors());
    }

    // the logged in visitor
    @GetMapping("/getMyInfo")
    public ResponseEntity<?> getMyInfo(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(visitorService.getVisitor(user.getId()));
    }

    // admin
    @GetMapping("/get/{id}")
    public ResponseEntity<?> getVisitor(@PathVariable Integer id){
        return ResponseEntity.status(200).body(visitorService.getVisitor(id));
    }

    @PutMapping("/updateVisitor")
    public ResponseEntity<?> updateVisitor(@AuthenticationPrincipal User user, @RequestBody @Valid Visitor visitor){
        visitorService.updateVisitor(user.getId(), visitor);
        return ResponseEntity.status(200).body(new ApiResponse("visitor updated"));
    }

    @PutMapping("/addInterest/{interestId}")
    public ResponseEntity<?> addInterestToVisitor(@AuthenticationPrincipal User user, @PathVariable Integer interestId){
        visitorService.addInterestToVisitor(user.getId(), interestId);
        return ResponseEntity.status(200).body(new ApiResponse("interest added to visitor"));
    }

    @DeleteMapping("/removeInterest/{interestId}")
    public ResponseEntity<?> removeInterestFromVisitor(@AuthenticationPrincipal User user, @PathVariable Integer interestId){
        visitorService.removeInterestFromVisitor(user.getId(), interestId);
        return ResponseEntity.status(200).body(new ApiResponse("interest removed from visitor"));
    }

    // the visitor deletes his own visitor data
    @DeleteMapping("/deleteVisitor")
    public ResponseEntity<?> deleteMyVisitor(@AuthenticationPrincipal User user){
        visitorService.deleteVisitor(user.getId());
        return ResponseEntity.status(200).body(new ApiResponse("visitor deleted"));
    }

    // admin
    @DeleteMapping("/deleteVisitor/{id}")
    public ResponseEntity<?> deleteVisitor(@PathVariable Integer id){
        visitorService.deleteVisitor(id);
        return ResponseEntity.status(200).body(new ApiResponse("visitor deleted"));
    }
}

package com.example.expo.Controller;

import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.expo.Api.ApiResponse;
import com.example.expo.Model.User;
import com.example.expo.Model.Pavilion;
import com.example.expo.Service.PavilionService;
import com.example.expo.Service.AccessibilityService;
import com.example.expo.Dto.In.AccessibilityUpdateRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/pavilion")
@RequiredArgsConstructor
public class PavilionController {

    private final PavilionService pavilionService;
    private final AccessibilityService accessibilityService;

    @GetMapping("/get")
    public ResponseEntity<?> getAllPavilion() {
        return ResponseEntity.status(200).body(pavilionService.getAllPavilion());
    }

    @GetMapping("/details/{pavilionId}")
    public ResponseEntity<?> getPavilionDetails(@PathVariable Integer pavilionId) {
        return ResponseEntity.status(200).body(pavilionService.getPavilionDetails(pavilionId));
    }

    @PostMapping("/add/{zoneId}/{locationId}")
    public ResponseEntity<?> addPavilion(@PathVariable Integer zoneId, @PathVariable Integer locationId, @RequestBody @Valid Pavilion pavilion) {
        pavilionService.addPavilion(zoneId, locationId, pavilion);
        return ResponseEntity.status(200).body(new ApiResponse("Pavilion added"));
    }

    @PutMapping("/update/{id}")
    public ResponseEntity<?> updatePavilion(@PathVariable Integer id, @RequestBody @Valid Pavilion pavilion) {
        pavilionService.updatePavilion(id, pavilion);
        return ResponseEntity.status(200).body(new ApiResponse("Pavilion updated"));
    }

    @DeleteMapping("/delete/{id}")
    public ResponseEntity<?> deletePavilion(@PathVariable Integer id) {
        pavilionService.deletePavilion(id);
        return ResponseEntity.status(200).body(new ApiResponse("Pavilion deleted"));
    }

    @GetMapping("/zone/{zoneId}")
    public ResponseEntity<?> getPavilionsByZone(@PathVariable Integer zoneId) {
        return ResponseEntity.status(200).body(pavilionService.getPavilionsByZone(zoneId));
    }

    @GetMapping("/search/{name}")
    public ResponseEntity<?> searchPavilion(@PathVariable String name) {
        return ResponseEntity.status(200).body(pavilionService.searchPavilion(name));
    }

    @GetMapping("/top-rated")
    public ResponseEntity<?> getTopRatedPavilions() {
        return ResponseEntity.status(200).body(pavilionService.getTopRatedPavilions());
    }

    // pavilions that serve all these needs, for example WHEELCHAIR,SENSORY
    @GetMapping("/accessible/{needs}")
    public ResponseEntity<?> getAccessiblePavilions(@PathVariable String needs) {
        return ResponseEntity.status(200).body(accessibilityService.getAccessiblePavilions(needs));
    }

    @PutMapping("/accessibility/{pavilionId}/{needType}")
    public ResponseEntity<?> updateAccessibility(@PathVariable Integer pavilionId, @PathVariable String needType, @RequestBody @Valid AccessibilityUpdateRequest request) {
        accessibilityService.updatePavilionAccessibility(pavilionId, needType, request);
        return ResponseEntity.status(200).body(new ApiResponse("Pavilion accessibility updated"));
    }

    @GetMapping("/unvisited")
    public ResponseEntity<?> getUnvisitedPavilions(@AuthenticationPrincipal User user) {
        return ResponseEntity.status(200).body(pavilionService.getUnvisitedPavilions(user.getId()));
    }
}

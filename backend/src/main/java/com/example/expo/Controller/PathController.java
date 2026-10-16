package com.example.expo.Controller;

import com.example.expo.Api.ApiResponse;
import com.example.expo.Dto.In.PathAccessibilityRequest;
import jakarta.validation.Valid;
import com.example.expo.Model.User;
import com.example.expo.Service.PathService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/path")
@RequiredArgsConstructor
public class PathController {
    private final PathService pathService;

    @GetMapping("/get")
    public ResponseEntity<?> getAllPaths(){
        return ResponseEntity.status(200).body(pathService.getAllPaths());
    }

    @PostMapping("/add/{fromId}/{toId}")
    public ResponseEntity<?> addPath(@PathVariable Integer fromId, @PathVariable Integer toId){
        pathService.addPath(fromId, toId);
        return ResponseEntity.status(200).body(new ApiResponse("Path added"));
    }

    @DeleteMapping("/delete/{id}")
    public ResponseEntity<?> deletePath(@PathVariable Integer id){
        pathService.deletePath(id);
        return ResponseEntity.status(200).body(new ApiResponse("Path deleted"));
    }

    @GetMapping("/shortest/{fromId}/{toId}")
    public ResponseEntity<?> getShortestPath(@PathVariable Integer fromId, @PathVariable Integer toId){
        return ResponseEntity.status(200).body(pathService.getShortestPath(fromId, toId));
    }

    // بدون درج ويفضّل الظل (كرسي متحرك، صعوبة مشي، عربة أطفال)
    @GetMapping("/shortest-accessible/{fromId}/{toId}")
    public ResponseEntity<?> getAccessibleShortestPath(@PathVariable Integer fromId, @PathVariable Integer toId){
        return ResponseEntity.status(200).body(pathService.getAccessibleShortestPath(fromId, toId));
    }

    @PutMapping("/accessibility/{id}")
    public ResponseEntity<?> updatePathAccessibility(@PathVariable Integer id, @RequestBody @Valid PathAccessibilityRequest request){
        pathService.updatePathAccessibility(id, request);
        return ResponseEntity.status(200).body(new ApiResponse("Path accessibility updated"));
    }

    // من بوابة الرحلة
    @GetMapping("/roadmap/{roadmapId}")
    public ResponseEntity<?> getRoadmapRouteFromEntrance(@AuthenticationPrincipal User user, @PathVariable Integer roadmapId){
        return ResponseEntity.status(200).body(pathService.getRoadmapRouteFromEntrance(user.getId(), roadmapId));
    }

    // من أي نقطة (مكان الزائر الحين)
    @GetMapping("/roadmap/{roadmapId}/{startLocationId}")
    public ResponseEntity<?> getRoadmapRoute(@AuthenticationPrincipal User user, @PathVariable Integer roadmapId, @PathVariable Integer startLocationId){
        return ResponseEntity.status(200).body(pathService.getRoadmapRoute(user.getId(), roadmapId, startLocationId));
    }

    @PostMapping("/generate")
    public ResponseEntity<?> generatePaths(){
        Integer added = pathService.generatePaths();
        return ResponseEntity.status(200).body(new ApiResponse("Paths generated: " + added));
    }
}
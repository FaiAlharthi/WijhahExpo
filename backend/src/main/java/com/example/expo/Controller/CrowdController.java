package com.example.expo.Controller;

import com.example.expo.Api.ApiResponse;
import com.example.expo.Model.User;
import com.example.expo.Service.CrowdService;
import com.example.expo.Service.RoadmapService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/crowd")
@RequiredArgsConstructor
public class CrowdController {
    private final CrowdService crowdService;
    private final RoadmapService roadmapService;

    // expected queue of every pavilion now
    @GetMapping("/now")
    public ResponseEntity<?> getCrowdNow(){
        return ResponseEntity.status(200).body(crowdService.getCrowdNow());
    }

    // queue of one pavilion now and every 15 minutes until the end of the day
    @GetMapping("/pavilion/{pavilionId}")
    public ResponseEntity<?> getPavilionCrowd(@PathVariable Integer pavilionId){
        return ResponseEntity.status(200).body(crowdService.getPavilionCrowd(pavilionId));
    }

    // WhatsApp alerts the visitor got today
    @GetMapping("/alerts/my")
    public ResponseEntity<?> getMyAlerts(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(crowdService.getMyAlerts(user.getId()));
    }

    // the visitor accepts the alert, the pavilion becomes the next stop
    @PostMapping("/alerts/{alertId}/accept")
    public ResponseEntity<?> acceptAlert(@AuthenticationPrincipal User user, @PathVariable Integer alertId){
        return ResponseEntity.status(200).body(roadmapService.acceptCrowdAlert(user.getId(), alertId));
    }

    // admin: how many visitors one app user stands for
    @PutMapping("/factor/{value}")
    public ResponseEntity<?> setFactor(@PathVariable Double value){
        crowdService.setAppFactor(value);
        return ResponseEntity.status(200).body(new ApiResponse("Crowd factor updated"));
    }

    // admin: manual queue for the next 30 minutes
    @PutMapping("/override/{pavilionId}/{minutes}")
    public ResponseEntity<?> setManualWait(@PathVariable Integer pavilionId, @PathVariable Integer minutes){
        crowdService.setManualWait(pavilionId, minutes, 30);
        return ResponseEntity.status(200).body(new ApiResponse("Manual queue set for 30 minutes"));
    }

    // admin: manual queue for a chosen number of minutes
    @PutMapping("/override/{pavilionId}/{minutes}/{duration}")
    public ResponseEntity<?> setManualWaitFor(@PathVariable Integer pavilionId, @PathVariable Integer minutes, @PathVariable Integer duration){
        crowdService.setManualWait(pavilionId, minutes, duration);
        return ResponseEntity.status(200).body(new ApiResponse("Manual queue set for " + duration + " minutes"));
    }

    @DeleteMapping("/override/{pavilionId}")
    public ResponseEntity<?> clearManualWait(@PathVariable Integer pavilionId){
        crowdService.clearManualWait(pavilionId);
        return ResponseEntity.status(200).body(new ApiResponse("Manual queue removed"));
    }

    // admin: run the alert check now instead of waiting for the next 5 minutes
    @PostMapping("/check")
    public ResponseEntity<?> checkNow(){
        int sent = crowdService.checkAlerts();
        return ResponseEntity.status(200).body(new ApiResponse("Crowd alerts sent: " + sent));
    }
}

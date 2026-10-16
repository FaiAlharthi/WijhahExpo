package com.example.expo.Controller;

import com.example.expo.Api.ApiResponse;
import com.example.expo.Dto.In.GenerateRoadmapRequest;
import com.example.expo.Dto.In.ReorderStopsRequest;
import com.example.expo.Dto.In.ShareRoadmapRequest;
import com.example.expo.Dto.In.JoinRequestBody;
import com.example.expo.Service.JourneyPdfService;
import com.example.expo.Service.RoadmapService;
import com.example.expo.Service.SharedRoadmapService;
import com.example.expo.Service.GroupService;
import jakarta.validation.Valid;
import com.example.expo.Model.User;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/v1/roadmap")
@RequiredArgsConstructor
public class RoadmapController {
    private final RoadmapService roadmapService;
    private final JourneyPdfService journeyPdfService;
    private final SharedRoadmapService sharedRoadmapService;
    private final GroupService groupService;

    @GetMapping("/getAll")
    public ResponseEntity<?> getAllRoadmaps(){
        return ResponseEntity.status(200).body(roadmapService.getAllRoadmaps());
    }

    @GetMapping("/getMyRoadmaps")
    public ResponseEntity<?> getMyRoadmaps(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(roadmapService.getVisitorRoadmaps(user.getId()));
    }

    // the nearest entrance is chosen by the system
    @PostMapping("/generate")
    public ResponseEntity<?> generateRoadmap(@AuthenticationPrincipal User user, @RequestBody @Valid GenerateRoadmapRequest request){
        return ResponseEntity.status(200).body(roadmapService.generateRoadmap(user.getId(), request));
    }

    // only before the first visit
    @PutMapping("/changeEntrance/{roadmapId}/{entranceId}")
    public ResponseEntity<?> changeEntrance(@AuthenticationPrincipal User user, @PathVariable Integer roadmapId, @PathVariable Integer entranceId){
        return ResponseEntity.status(200).body(roadmapService.changeEntrance(user.getId(), roadmapId, entranceId));
    }

    @GetMapping("/getStops/{roadmapId}")
    public ResponseEntity<?> getStops(@AuthenticationPrincipal User user, @PathVariable Integer roadmapId){
        return ResponseEntity.status(200).body(roadmapService.getStops(user.getId(), roadmapId));
    }

    @PostMapping("/addStop/{roadmapId}/{pavilionId}/{position}")
    public ResponseEntity<?> addStop(@AuthenticationPrincipal User user, @PathVariable Integer roadmapId, @PathVariable Integer pavilionId, @PathVariable Integer position){
        return ResponseEntity.status(200).body(roadmapService.addStop(user.getId(), roadmapId, pavilionId, position));
    }

    @DeleteMapping("/removeStop/{roadmapId}/{visitId}")
    public ResponseEntity<?> removeStop(@AuthenticationPrincipal User user, @PathVariable Integer roadmapId, @PathVariable Integer visitId){
        return ResponseEntity.status(200).body(roadmapService.removeStop(user.getId(), roadmapId, visitId));
    }

    @PutMapping("/reorder/{roadmapId}")
    public ResponseEntity<?> reorderStops(@AuthenticationPrincipal User user, @PathVariable Integer roadmapId, @RequestBody @Valid ReorderStopsRequest request){
        return ResponseEntity.status(200).body(roadmapService.reorderStops(user.getId(), roadmapId, request));
    }

    @PutMapping("/makeDynamic/{roadmapId}")
    public ResponseEntity<?> makeDynamic(@AuthenticationPrincipal User user, @PathVariable Integer roadmapId){
        return ResponseEntity.status(200).body(roadmapService.makeDynamic(user.getId(), roadmapId));
    }

    @DeleteMapping("/deleteRoadmap/{id}")
    public ResponseEntity<?> deleteRoadmap(@AuthenticationPrincipal User user, @PathVariable Integer id){
        roadmapService.deleteRoadmap(user.getId(), id);
        return ResponseEntity.status(200).body(new ApiResponse("roadmap deleted"));
    }

    @GetMapping("/pdf/{roadmapId}")
    public ResponseEntity<?> getRoadmapPdf(@AuthenticationPrincipal User user, @PathVariable Integer roadmapId){
        byte[] pdf = journeyPdfService.getRoadmapPdf(user.getId(), roadmapId);
        return ResponseEntity.status(200)
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.attachment().filename("wijha-journey.pdf").build().toString())
                .contentType(MediaType.APPLICATION_PDF)
                .body(pdf);
    } // the roadmap as a PDF the visitor can share (map with the route, stops and stamps status)

    // ===== Find a group =====
    // publishes the roadmap, or changes the share settings of a published one
    @PutMapping("/share/{roadmapId}")
    public ResponseEntity<?> shareRoadmap(@AuthenticationPrincipal User user, @PathVariable Integer roadmapId, @RequestBody @Valid ShareRoadmapRequest request){
        sharedRoadmapService.shareRoadmap(user.getId(), roadmapId, request);
        return ResponseEntity.status(200).body(new ApiResponse("roadmap shared"));
    }

    @PutMapping("/unshare/{roadmapId}")
    public ResponseEntity<?> unshareRoadmap(@AuthenticationPrincipal User user, @PathVariable Integer roadmapId){
        sharedRoadmapService.unshareRoadmap(user.getId(), roadmapId);
        return ResponseEntity.status(200).body(new ApiResponse("roadmap is not shared anymore"));
    }

    // after this the stops of the roadmap are fixed
    @PutMapping("/confirm/{roadmapId}")
    public ResponseEntity<?> confirmRoadmap(@AuthenticationPrincipal User user, @PathVariable Integer roadmapId){
        sharedRoadmapService.confirmRoadmap(user.getId(), roadmapId);
        return ResponseEntity.status(200).body(new ApiResponse("roadmap confirmed"));
    }

    @GetMapping("/shared")
    public ResponseEntity<?> getShared(@AuthenticationPrincipal User user, @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
                                       @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size){
        return ResponseEntity.status(200).body(sharedRoadmapService.getShared(user.getId(), date, page, size));
    }

    // ===== find a group: join requests and membership =====

    // a visitor asks to join a shared plan (optional short message)
    @PostMapping("/{roadmapId}/join")
    public ResponseEntity<?> requestJoin(@AuthenticationPrincipal User user, @PathVariable Integer roadmapId, @RequestBody @Valid JoinRequestBody body){
        return ResponseEntity.status(200).body(groupService.requestJoin(user.getId(), roadmapId, body));
    }

    // the requester cancels his own pending request
    @DeleteMapping("/join/{requestId}")
    public ResponseEntity<?> withdrawJoin(@AuthenticationPrincipal User user, @PathVariable Integer requestId){
        groupService.withdraw(user.getId(), requestId);
        return ResponseEntity.status(200).body(new ApiResponse("request withdrawn"));
    }

    // the requester's own outgoing requests and their status
    @GetMapping("/myJoinRequests")
    public ResponseEntity<?> myJoinRequests(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(groupService.myRequests(user.getId()));
    }

    // a member leaves a group he joined
    @DeleteMapping("/{roadmapId}/leave")
    public ResponseEntity<?> leaveGroup(@AuthenticationPrincipal User user, @PathVariable Integer roadmapId){
        groupService.leave(user.getId(), roadmapId);
        return ResponseEntity.status(200).body(new ApiResponse("you left the group"));
    }

    // the founder sees the join requests for his plan
    @GetMapping("/{roadmapId}/requests")
    public ResponseEntity<?> joinRequests(@AuthenticationPrincipal User user, @PathVariable Integer roadmapId){
        return ResponseEntity.status(200).body(groupService.requestsForRoadmap(user.getId(), roadmapId));
    }

    // the founder accepts a request (creates the member's locked copy)
    @PutMapping("/requests/{requestId}/accept")
    public ResponseEntity<?> acceptJoin(@AuthenticationPrincipal User user, @PathVariable Integer requestId){
        groupService.accept(user.getId(), requestId);
        return ResponseEntity.status(200).body(new ApiResponse("request accepted"));
    }

    // the founder rejects a request
    @PutMapping("/requests/{requestId}/reject")
    public ResponseEntity<?> rejectJoin(@AuthenticationPrincipal User user, @PathVariable Integer requestId){
        groupService.reject(user.getId(), requestId);
        return ResponseEntity.status(200).body(new ApiResponse("request rejected"));
    }

    // the group view for a founder or an accepted member (read-only plan, members, contact)
    @GetMapping("/{roadmapId}/group")
    public ResponseEntity<?> group(@AuthenticationPrincipal User user, @PathVariable Integer roadmapId){
        return ResponseEntity.status(200).body(groupService.getGroup(user.getId(), roadmapId));
    }

    @PostMapping("/sendPdf/{roadmapId}")
    public ResponseEntity<?> sendPdfToWhatsApp(@AuthenticationPrincipal User user, @PathVariable Integer roadmapId){
        roadmapService.sendPdfToWhatsApp(user.getId(), roadmapId);
        return ResponseEntity.status(200).body(new ApiResponse("the PDF was sent to your WhatsApp"));
    } // sends the same PDF to the WhatsApp number of the logged in visitor, only when they ask for it
}

package com.example.expo.Controller;

import com.example.expo.Api.ApiResponse;
import com.example.expo.Model.Entrance;
import com.example.expo.Service.EntranceService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/entrance")
@RequiredArgsConstructor
public class EntranceController {
    private final EntranceService entranceService;

    @GetMapping("/getAll")
    public ResponseEntity<?> getAllEntrances(){
        return ResponseEntity.status(200).body(entranceService.getAllEntrances());
    }

    @PostMapping("/createEntrance/{locationId}")
    public ResponseEntity<?> createEntrance(@PathVariable Integer locationId, @RequestBody @Valid Entrance entrance){
        entranceService.addEntrance(locationId, entrance);
        return ResponseEntity.status(200).body(new ApiResponse("entrance added"));
    }

    @PutMapping("/updateEntrance/{id}")
    public ResponseEntity<?> updateEntrance(@PathVariable Integer id, @RequestBody @Valid Entrance entrance){
        entranceService.updateEntrance(id, entrance);
        return ResponseEntity.status(200).body(new ApiResponse("entrance updated"));
    }

    @DeleteMapping("/deleteEntrance/{id}")
    public ResponseEntity<?> deleteEntrance(@PathVariable Integer id){
        entranceService.deleteEntrance(id);
        return ResponseEntity.status(200).body(new ApiResponse("entrance deleted"));
    }
}

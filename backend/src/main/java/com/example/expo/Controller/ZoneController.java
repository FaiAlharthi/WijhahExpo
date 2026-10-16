package com.example.expo.Controller;

import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.expo.Api.ApiResponse;
import com.example.expo.Model.Zone;
import com.example.expo.Service.ZoneService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/zone")
@RequiredArgsConstructor
public class ZoneController {

    private final ZoneService zoneService;

    @GetMapping("/get")
    public ResponseEntity<?> getAllZone() {
        return ResponseEntity.status(200).body(zoneService.getAllZones());
    }

    @PostMapping("/add/{locationId}")
    public ResponseEntity<?> addZone(@PathVariable Integer locationId, @RequestBody @Valid Zone zone) {
        zoneService.addZone(locationId, zone);
        return ResponseEntity.status(200).body(new ApiResponse("Zone added"));
    }

    @PutMapping("/update/{id}")
    public ResponseEntity<?> updateZone(@PathVariable Integer id, @RequestBody @Valid Zone zone) {
        zoneService.updateZone(id, zone);
        return ResponseEntity.status(200).body(new ApiResponse("Zone updated"));
    }

    @DeleteMapping("/delete/{id}")
    public ResponseEntity<?> deleteZone(@PathVariable Integer id) {
        zoneService.deleteZone(id);
        return ResponseEntity.status(200).body(new ApiResponse("Zone deleted"));
    }

}

package com.example.expo.Controller;

import com.example.expo.Api.ApiResponse;
import com.example.expo.Model.Location;
import com.example.expo.Service.LocationService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/location")
@RequiredArgsConstructor
public class LocationController {

    private final LocationService locationService;

    @GetMapping("/get")
    public ResponseEntity<?> getAllLocation() {
        return ResponseEntity.status(200).body(locationService.getAllLocation());
    }

    @PostMapping("/add")
    public ResponseEntity<?> addLocation(@RequestBody @Valid Location location) {
        locationService.addLocation(location);
        return ResponseEntity.status(200).body(new ApiResponse("Location added"));
    }

    @PutMapping("/update/{id}")
    public ResponseEntity<?> updateLocation(@PathVariable Integer id, @RequestBody @Valid Location location) {
        locationService.updateLocation(id, location);
        return ResponseEntity.status(200).body(new ApiResponse("Location updated"));
    }

    @DeleteMapping("/delete/{id}")
    public ResponseEntity<?> deleteLocation(@PathVariable Integer id) {
        locationService.deleteLocation(id);
        return ResponseEntity.status(200).body(new ApiResponse("Location deleted"));
    }
}
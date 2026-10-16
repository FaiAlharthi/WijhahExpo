package com.example.expo.Controller;

import com.example.expo.Api.ApiResponse;
import com.example.expo.Service.DashboardService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/admin")
@RequiredArgsConstructor
public class AdminController {
    private final DashboardService dashboardService;

    @GetMapping("/dashboard")
    public ResponseEntity<?> getDashboard(){
        return ResponseEntity.status(200).body(dashboardService.getDashboard());
    }
}

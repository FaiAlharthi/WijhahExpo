package com.example.expo.Controller;

import com.example.expo.Service.PassportService;
import com.example.expo.Model.User;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/passport")
@RequiredArgsConstructor
public class PassportController {
    private final PassportService passportService;

    @GetMapping("/getAll")
    public ResponseEntity<?> getAllPassports(){
        return ResponseEntity.status(200).body(passportService.getAllPassports());
    }

    @GetMapping("/getMyPassport")
    public ResponseEntity<?> getMyPassport(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(passportService.getVisitorPassport(user.getId()));
    }

    // all stamps of the logged-in visitor with earned true/false, so the app shows collected ones in color and the rest faded
    @GetMapping("/getMyStamps")
    public ResponseEntity<?> getMyStamps(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(passportService.getVisitorStamps(user.getId()));
    }
}

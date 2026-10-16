package com.example.expo.Controller;

import com.example.expo.Api.ApiResponse;
import com.example.expo.Service.UserService;
import jakarta.validation.Valid;
import com.example.expo.Model.User;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/user")
@RequiredArgsConstructor
public class UserController {
    private final UserService userService;

    // visitor: own account only, admin: own account or any visitor
    @GetMapping("/get/{id}")
    public ResponseEntity<?> getUser(@AuthenticationPrincipal User user, @PathVariable Integer id){
        return ResponseEntity.status(200).body(userService.getUser(user, id));
    }

    @PutMapping("/updateUser")
    public ResponseEntity<?> updateUser(@AuthenticationPrincipal User user, @RequestBody @Valid User newUser){
        userService.updateUser(user.getId(), newUser);
        return ResponseEntity.status(200).body(new ApiResponse("user updated"));
    }

    // the visitor deletes his own account
    @DeleteMapping("/deleteUser")
    public ResponseEntity<?> deleteMyUser(@AuthenticationPrincipal User user){
        userService.deleteUser(user.getId());
        return ResponseEntity.status(200).body(new ApiResponse("user deleted"));
    }

    // admin deletes a visitor account
    @DeleteMapping("/deleteUser/{id}")
    public ResponseEntity<?> deleteUser(@PathVariable Integer id){
        userService.deleteVisitorUser(id);
        return ResponseEntity.status(200).body(new ApiResponse("user deleted"));
    }
}

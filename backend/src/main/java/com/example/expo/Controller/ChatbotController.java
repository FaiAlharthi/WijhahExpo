package com.example.expo.Controller;

import com.example.expo.Dto.In.ChatQuestionRequest;
import com.example.expo.Service.ChatbotService;
import jakarta.validation.Valid;
import com.example.expo.Model.User;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/chatbot")
@RequiredArgsConstructor
public class ChatbotController {
    private final ChatbotService chatbotService;

    @GetMapping("/suggestions")
    public ResponseEntity<?> getSuggestions(@AuthenticationPrincipal User user){
        return ResponseEntity.status(200).body(chatbotService.getSuggestions(user.getId()));
    }

    @PostMapping("/ask")
    public ResponseEntity<?> ask(@AuthenticationPrincipal User user, @RequestBody @Valid ChatQuestionRequest request){
        return ResponseEntity.status(200).body(chatbotService.ask(user.getId(), request));
    }
}

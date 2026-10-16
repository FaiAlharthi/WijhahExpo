package com.example.expo.Dto.In;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// one earlier message of the open chat
@Data
@AllArgsConstructor
@NoArgsConstructor
public class ChatMessageRequest {

    @NotEmpty(message = "role cannot be empty")
    @Pattern(regexp = "^(USER|BOT)$", message = "role must be USER or BOT")
    private String role;

    @NotEmpty(message = "text cannot be empty")
    private String text;
}

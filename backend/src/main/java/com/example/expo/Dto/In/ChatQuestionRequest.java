package com.example.expo.Dto.In;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class ChatQuestionRequest {

    @NotEmpty(message = "question cannot be empty")
    @Size(max = 500, message = "question must be less than 500 characters")
    private String question;

    // optional, the last messages of the open chat (not saved in the database)
    private List<@Valid ChatMessageRequest> history;
}

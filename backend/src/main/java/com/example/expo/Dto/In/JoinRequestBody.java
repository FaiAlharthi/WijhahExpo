package com.example.expo.Dto.In;

import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// a visitor asks to join a shared plan, with an optional short message
@Data
@AllArgsConstructor
@NoArgsConstructor
public class JoinRequestBody {
    @Size(max = 140, message = "Message must be 140 letters max")
    private String message;
}

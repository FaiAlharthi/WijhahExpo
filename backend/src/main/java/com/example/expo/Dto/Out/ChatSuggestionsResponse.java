package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

// ready questions shown as buttons when the chat opens
@Data
@AllArgsConstructor
@NoArgsConstructor
public class ChatSuggestionsResponse {
    private List<String> questions;
}

package com.example.expo.Service;

import com.example.expo.Api.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import tools.jackson.databind.ObjectMapper;

import java.util.Map;

// the AI checks review comments before they are saved
@Service
@RequiredArgsConstructor
public class ModerationService {
    private final GeminiService geminiService;

    private final ObjectMapper objectMapper = new ObjectMapper();

    // throws if the comment is racist or very rude, criticism is allowed
    public void checkComment(String comment){
        if(comment == null || comment.isBlank()){
            return;
        }
        boolean allowed;
        try{
            Map<?, ?> answer = objectMapper.readValue(geminiService.ask(buildPrompt(comment)), Map.class);
            allowed = !Boolean.FALSE.equals(answer.get("allowed"));
        }catch(Exception e){
            // AI is not available, the review is accepted
            System.out.println("review check failed: " + e.getMessage());
            return;
        }
        if(!allowed){
            throw new ApiException("your review was not accepted because it contains racist or offensive language");
        }
    }

    private String buildPrompt(String comment){
        return "You check visitor reviews of Expo pavilions. The review can be in Arabic or English.\n"
                + "Reject it only if it has racism, hate against any people, nation, religion or group, insults, swearing or very rude language.\n"
                + "Negative opinions and criticism written politely are allowed, the review does not have to praise.\n\n"
                + "Review: \"\"\"" + comment + "\"\"\"\n\n"
                + "Answer with JSON only: {\"allowed\": true or false}";
    }
}

package com.example.expo.Service;

import com.example.expo.Api.ApiException;
import com.example.expo.Dto.In.ChatMessageRequest;
import com.example.expo.Dto.In.ChatQuestionRequest;
import com.example.expo.Dto.Out.ChatAnswerResponse;
import com.example.expo.Dto.Out.ChatSuggestionsResponse;
import com.example.expo.Model.Visitor;
import com.example.expo.Repository.VisitorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

// answers visitor questions about the expo from the knowledge file (RAG)
@Service
@RequiredArgsConstructor
public class ChatbotService {
    private final VisitorRepository visitorRepository;
    private final RagService ragService;
    private final GeminiService geminiService;

    // how many knowledge chunks and old messages are sent with the question
    private static final int CHUNKS_LIMIT = 5;
    private static final int HISTORY_LIMIT = 6;

    public ChatAnswerResponse ask(Integer visitorId, ChatQuestionRequest request){
        Visitor visitor = visitorRepository.findVisitorById(visitorId);
        if(visitor == null){
            throw new ApiException("visitor not found");
        }
        // ready questions are answered at once without the AI
        String readyAnswer = ragService.findFaqAnswer(request.getQuestion());
        if(readyAnswer != null){
            return new ChatAnswerResponse(readyAnswer);
        }

        List<ChatMessageRequest> history = request.getHistory() == null ? List.of() : request.getHistory();
        if(history.size() > HISTORY_LIMIT){
            history = history.subList(history.size() - HISTORY_LIMIT, history.size());
        }

        // a follow up question needs the last message to be searched well
        String searchText = request.getQuestion();
        if(!history.isEmpty()){
            searchText = history.get(history.size() - 1).getText() + "\n" + searchText;
        }
        List<String> knowledge = ragService.search(searchText, CHUNKS_LIMIT);

        try{
            return new ChatAnswerResponse(geminiService.askText(buildPrompt(visitor, knowledge, history, request.getQuestion())).trim());
        }catch(Exception e){
            System.out.println("chatbot failed: " + e.getMessage());
            // AI is not available, use a close ready answer if there is one
            String similarAnswer = ragService.findSimilarFaqAnswer(request.getQuestion());
            if(similarAnswer != null){
                return new ChatAnswerResponse(similarAnswer);
            }
            throw new ApiException("the chatbot is not available now, try again later");
        }
    }

    public ChatSuggestionsResponse getSuggestions(Integer visitorId){
        Visitor visitor = visitorRepository.findVisitorById(visitorId);
        if(visitor == null){
            throw new ApiException("visitor not found");
        }
        return new ChatSuggestionsResponse(ragService.getFaqQuestions(visitor.getPreferredLanguage()));
    }

    private String buildPrompt(Visitor visitor, List<String> knowledge, List<ChatMessageRequest> history, String question){
        StringBuilder prompt = new StringBuilder();
        prompt.append("You are the friendly assistant of the Expo 2030 Riyadh visitor app.\n\n");

        prompt.append("RULES\n");
        prompt.append("- Answer only about Expo 2030 Riyadh, its pavilions, zones, entrances, the app and World Expos.\n");
        prompt.append("- Use only the KNOWLEDGE below. If the answer is not there, say you do not have this information. Never invent facts.\n");
        prompt.append("- If the question is not about the expo, politely say you can only help with the expo.\n");
        // mirror the visitor's language, whatever it is (Arabic, English, or any other language)
        prompt.append("- Reply in the SAME language the visitor used in their latest question");
        prompt.append(" (Arabic, English, or any other language). Match it exactly and never switch to a different language.");
        prompt.append(" If the question has no words (only numbers or symbols), reply in ")
                .append("AR".equals(visitor.getPreferredLanguage()) ? "Arabic" : "English").append(".\n");
        prompt.append("- Keep the answer short and clear, in your own friendly words (do not copy the knowledge text), plain text without markdown.\n\n");

        prompt.append("KNOWLEDGE\n");
        for(String chunk : knowledge){
            prompt.append(chunk).append("\n---\n");
        }

        if(!history.isEmpty()){
            prompt.append("\nCHAT SO FAR\n");
            for(ChatMessageRequest message : history){
                prompt.append("USER".equals(message.getRole()) ? "Visitor: " : "Assistant: ").append(message.getText()).append("\n");
            }
        }

        prompt.append("\nVisitor question: ").append(question).append("\nAnswer:");
        return prompt.toString();
    }
}

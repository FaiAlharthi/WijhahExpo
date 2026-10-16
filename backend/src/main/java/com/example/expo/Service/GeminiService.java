package com.example.expo.Service;

import com.example.expo.Api.ApiException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;
import tools.jackson.databind.ObjectMapper;

import java.net.http.HttpClient;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Service
public class GeminiService {

    @Value("${ai.api.key:}")
    private String apiKey;

    @Value("${ai.api.url:}")
    private String apiUrl;

    @Value("${ai.model:}")
    private String model;

    // used when the main model is busy or fails
    @Value("${ai.fallback.model:}")
    private String fallbackModel;

    @Value("${ai.embedding.model:gemini-embedding-001}")
    private String embeddingModel;

    private final RestClient restClient;

    private final ObjectMapper objectMapper = new ObjectMapper();

    public GeminiService(){
        // java HttpClient is more stable with Google servers
        HttpClient httpClient = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
        JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(httpClient);
        factory.setReadTimeout(Duration.ofSeconds(60));
        this.restClient = RestClient.builder().requestFactory(factory).build();
    }

    // sends the prompt and returns the answer text (json)
    public String ask(String prompt){
        return generate(prompt, true);
    }

    // sends the prompt and returns a normal text answer, used by the chatbot
    public String askText(String prompt){
        return generate(prompt, false);
    }

    private String generate(String prompt, boolean json){
        checkKey();
        Map<String, Object> body = json
                ? Map.of("contents", List.of(Map.of("parts", List.of(Map.of("text", prompt)))),
                        "generationConfig", Map.of("responseMimeType", "application/json"))
                : Map.of("contents", List.of(Map.of("parts", List.of(Map.of("text", prompt)))));
        try{
            return readText(postWithRetry(apiUrl + "/" + model + ":generateContent", body));
        }catch(ApiException e){
            if(fallbackModel == null || fallbackModel.isBlank() || fallbackModel.equals(model)){
                throw e;
            }
            System.out.println("main AI model failed, trying " + fallbackModel);
            return readText(postWithRetry(apiUrl + "/" + fallbackModel + ":generateContent", body));
        }
    }

    // turns texts into vectors, taskType is RETRIEVAL_DOCUMENT or RETRIEVAL_QUERY
    public List<double[]> embed(List<String> texts, String taskType){
        checkKey();
        List<Map<String, Object>> requests = new ArrayList<>();
        for(String text : texts){
            requests.add(Map.of(
                    "model", "models/" + embeddingModel,
                    "content", Map.of("parts", List.of(Map.of("text", text))),
                    "taskType", taskType));
        }
        Map<?, ?> response = postWithRetry(apiUrl + "/" + embeddingModel + ":batchEmbedContents", Map.of("requests", requests));
        if(response == null || !(response.get("embeddings") instanceof List<?> embeddings) || embeddings.size() != texts.size()){
            throw new ApiException("AI returned no embeddings");
        }
        List<double[]> vectors = new ArrayList<>();
        for(Object item : embeddings){
            List<?> values = (List<?>) ((Map<?, ?>) item).get("values");
            double[] vector = new double[values.size()];
            for(int i = 0; i < values.size(); i++){
                vector[i] = ((Number) values.get(i)).doubleValue();
            }
            vectors.add(vector);
        }
        return vectors;
    }

    // tries again 2 times (after 1 and 2 seconds) when Gemini is busy (503) or gets too many requests (429)
    private Map<?, ?> postWithRetry(String url, Object body){
        for(int attempt = 1; ; attempt++){
            try{
                return post(url, body);
            }catch(BusyException e){
                if(attempt == 3){
                    throw new ApiException("AI is busy now");
                }
                try{
                    Thread.sleep(1000L * attempt);
                }catch(InterruptedException ie){
                    Thread.currentThread().interrupt();
                    throw new ApiException("AI is busy now");
                }
            }
        }
    }

    // reads the answer as text first, so it works whatever content type Gemini sends
    private Map<?, ?> post(String url, Object body){
        ResponseEntity<String> response;
        try{
            response = restClient.post()
                    .uri(url)
                    .header("x-goog-api-key", apiKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .accept(MediaType.APPLICATION_JSON)
                    .body(body)
                    .retrieve()
                    .toEntity(String.class);
        }catch(RestClientResponseException e){
            // Gemini sent an error, print it to know the reason
            System.out.println("Gemini error " + e.getStatusCode() + ": " + e.getResponseBodyAsString());
            int status = e.getStatusCode().value();
            if(status == 503 || status == 429){
                throw new BusyException();
            }
            throw new ApiException("AI request failed");
        }catch(RestClientException e){
            // connection or reading problem, the request can be sent again
            System.out.println("Gemini connection problem: " + e.getMessage() + (e.getCause() == null ? "" : " / cause: " + e.getCause()));
            throw new BusyException();
        }
        String text = response.getBody();
        if(text == null || text.isBlank()){
            System.out.println("Gemini empty answer, status " + response.getStatusCode() + ", type " + response.getHeaders().getContentType());
            throw new ApiException("AI returned no answer");
        }
        try{
            return objectMapper.readValue(text, Map.class);
        }catch(Exception e){
            System.out.println("Gemini answer is not json: " + text);
            throw new ApiException("AI returned a wrong answer");
        }
    }

    private void checkKey(){
        if(apiKey == null || apiKey.isBlank()){
            throw new ApiException("AI key is missing");
        }
    }

    // answer is in candidates[0].content.parts[].text
    private String readText(Map<?, ?> response){
        if(response == null || !(response.get("candidates") instanceof List<?> candidates) || candidates.isEmpty()){
            throw new ApiException("AI returned no answer");
        }
        Map<?, ?> content = (Map<?, ?>) ((Map<?, ?>) candidates.get(0)).get("content");
        if(content == null || !(content.get("parts") instanceof List<?> parts)){
            throw new ApiException("AI returned no answer");
        }
        StringBuilder text = new StringBuilder();
        for(Object part : parts){
            Map<?, ?> p = (Map<?, ?>) part;
            if(p.get("text") != null && !Boolean.TRUE.equals(p.get("thought"))){
                text.append(p.get("text"));
            }
        }
        if(text.isEmpty()){
            throw new ApiException("AI returned no answer");
        }
        return text.toString();
    }

    // Gemini is busy, the request can be sent again
    private static class BusyException extends RuntimeException {
    }
}

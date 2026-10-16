package com.example.expo.Service;

import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;
import tools.jackson.databind.ObjectMapper;

import java.io.InputStream;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

// reads the knowledge file and finds the parts closest to a question
@Service
public class RagService {
    private final GeminiService geminiService;

    // one chunk per pavilion and per general topic
    private final List<String> chunks = new ArrayList<>();

    // ready questions and answers, each item has question and answer maps (ar, en)
    private final List<Map<?, ?>> faq = new ArrayList<>();

    // vectors of the chunks, filled once on the first question
    private List<double[]> vectors;

    // the file is read once when the app starts
    public RagService(GeminiService geminiService){
        this.geminiService = geminiService;
        loadKnowledge();
    }

    private void loadKnowledge(){
        try(InputStream file = new ClassPathResource("data/rag-knowledge.json").getInputStream()){
            Map<?, ?> data = new ObjectMapper().readValue(file, Map.class);
            if(data.get("faq") instanceof List<?> items){
                for(Object item : items){
                    faq.add((Map<?, ?>) item);
                }
            }
            for(Object item : (List<?>) data.get("general")){
                Map<?, ?> topic = (Map<?, ?>) item;
                chunks.add("TOPIC: " + text(topic.get("title"), "en") + " / " + text(topic.get("title"), "ar") + "\n"
                        + text(topic.get("content"), "en") + "\n" + text(topic.get("content"), "ar"));
            }
            for(Object item : (List<?>) data.get("pavilions")){
                chunks.add(pavilionChunk((Map<?, ?>) item));
            }
            System.out.println("RAG knowledge loaded: " + chunks.size() + " chunks");
        }catch(Exception e){
            System.out.println("RAG knowledge failed to load: " + e.getMessage());
        }
    }

    // ready questions in the visitor language (AR or EN)
    public List<String> getFaqQuestions(String language){
        String key = "AR".equals(language) ? "ar" : "en";
        List<String> questions = new ArrayList<>();
        for(Map<?, ?> item : faq){
            questions.add(text(item.get("question"), key));
        }
        return questions;
    }

    // ready answer if the question is one of the ready questions, otherwise null
    public String findFaqAnswer(String question){
        String asked = normalize(question);
        for(Map<?, ?> item : faq){
            for(String key : List.of("ar", "en")){
                if(normalize(text(item.get("question"), key)).equals(asked)){
                    return text(item.get("answer"), key);
                }
            }
        }
        return null;
    }

    // closest ready answer by shared words, used only when the AI is not available
    public String findSimilarFaqAnswer(String question){
        List<String> askedWords = List.of(normalize(question).split(" "));
        String best = null;
        double bestScore = 0;
        for(Map<?, ?> item : faq){
            for(String key : List.of("ar", "en")){
                List<String> words = List.of(normalize(text(item.get("question"), key)).split(" "));
                int shared = 0;
                for(String word : words){
                    if(word.length() >= 3 && askedWords.contains(word)){
                        shared++;
                    }
                }
                double score = (double) shared / words.size();
                if(shared >= 2 && score > bestScore){
                    bestScore = score;
                    best = text(item.get("answer"), key);
                }
            }
        }
        return bestScore >= 0.5 ? best : null;
    }

    // lower case, no punctuation, one space between words
    private String normalize(String text){
        return text.toLowerCase().replaceAll("[^\\p{L}\\p{N}]+", " ").trim();
    }

    // returns the closest chunks to the question
    public List<String> search(String question, int limit){
        try{
            if(vectors == null){
                loadVectors();
            }
            double[] questionVector = geminiService.embed(List.of(question), "RETRIEVAL_QUERY").get(0);
            List<Integer> order = new ArrayList<>();
            double[] scores = new double[chunks.size()];
            for(int i = 0; i < chunks.size(); i++){
                scores[i] = cosine(questionVector, vectors.get(i));
                order.add(i);
            }
            order.sort(Comparator.comparingDouble((Integer i) -> scores[i]).reversed());
            List<String> result = new ArrayList<>();
            for(int i = 0; i < Math.min(limit, order.size()); i++){
                result.add(chunks.get(order.get(i)));
            }
            return result;
        }catch(Exception e){
            // embeddings failed, search by words instead
            System.out.println("RAG embeddings failed: " + e.getMessage());
            return searchByWords(question, limit);
        }
    }

    private synchronized void loadVectors(){
        if(vectors == null){
            vectors = geminiService.embed(chunks, "RETRIEVAL_DOCUMENT");
        }
    }

    // counts the question words that appear in each chunk
    private List<String> searchByWords(String question, int limit){
        String[] words = question.toLowerCase().split("[^\\p{L}\\p{N}]+");
        List<Integer> order = new ArrayList<>();
        int[] scores = new int[chunks.size()];
        for(int i = 0; i < chunks.size(); i++){
            String chunk = chunks.get(i).toLowerCase();
            for(String word : words){
                if(word.length() >= 3 && chunk.contains(word)){
                    scores[i]++;
                }
            }
            order.add(i);
        }
        order.sort(Comparator.comparingInt((Integer i) -> scores[i]).reversed());
        List<String> result = new ArrayList<>();
        for(int i = 0; i < Math.min(limit, order.size()); i++){
            if(scores[order.get(i)] > 0){
                result.add(chunks.get(order.get(i)));
            }
        }
        // nothing matched, give the general information
        if(result.isEmpty()){
            result.addAll(chunks.subList(0, Math.min(limit, chunks.size())));
        }
        return result;
    }

    private double cosine(double[] a, double[] b){
        double dot = 0, normA = 0, normB = 0;
        for(int i = 0; i < a.length; i++){
            dot += a[i] * b[i];
            normA += a[i] * a[i];
            normB += b[i] * b[i];
        }
        return dot / (Math.sqrt(normA) * Math.sqrt(normB));
    }

    // english and arabic text together so both languages can match
    private String pavilionChunk(Map<?, ?> pavilion){
        StringBuilder chunk = new StringBuilder();
        chunk.append("PAVILION: ").append(pavilion.get("name"))
                .append(" | country: ").append(pavilion.get("country"))
                .append(" | zone: ").append(pavilion.get("zone"))
                .append(" | experience: ").append(pavilion.get("experienceTypes")).append("\n");
        chunk.append(text(pavilion.get("overview"), "en")).append("\n");
        chunk.append("Highlights: ").append(list(pavilion.get("highlights"), "en")).append("\n");
        if(pavilion.get("expoHistory") != null){
            chunk.append("Expo history: ").append(text(pavilion.get("expoHistory"), "en")).append("\n");
        }
        chunk.append("Good for: ").append(list(pavilion.get("goodFor"), "en")).append("\n");
        chunk.append(text(pavilion.get("overview"), "ar")).append("\n");
        chunk.append("أبرز التجارب: ").append(list(pavilion.get("highlights"), "ar")).append("\n");
        if(pavilion.get("expoHistory") != null){
            chunk.append("تاريخه في الإكسبو: ").append(text(pavilion.get("expoHistory"), "ar")).append("\n");
        }
        chunk.append("يناسب: ").append(list(pavilion.get("goodFor"), "ar"));
        return chunk.toString();
    }

    private String text(Object value, String language){
        return value instanceof Map<?, ?> map && map.get(language) != null ? map.get(language).toString() : "";
    }

    private String list(Object value, String language){
        if(value instanceof Map<?, ?> map && map.get(language) instanceof List<?> items){
            return String.join(", ", items.stream().map(Object::toString).toList());
        }
        return "";
    }
}

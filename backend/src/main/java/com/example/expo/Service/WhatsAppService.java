package com.example.expo.Service;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;
import tools.jackson.databind.ObjectMapper;

import java.net.http.HttpClient;
import java.time.Duration;
import java.util.Base64;
import java.util.Map;

// sends WhatsApp messages through UltraMsg (https://docs.ultramsg.com)
// keys are in application.properties: ultramsg.instance-id and ultramsg.token (env ULTRAMSG_INSTANCE_ID / ULTRAMSG_TOKEN)
@Service
@RequiredArgsConstructor
public class WhatsAppService {

    private final JourneyPdfService journeyPdfService;

    @Value("${ultramsg.instance-id:}")
    private String instanceId;
    @Value("${ultramsg.token:}")
    private String token;
    @Value("${ultramsg.api-url:https://api.ultramsg.com}")
    private String apiUrl;

    private final RestClient restClient = createClient();
    private final ObjectMapper objectMapper = new ObjectMapper();

    private static RestClient createClient(){
        HttpClient httpClient = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
        JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(httpClient);
        factory.setReadTimeout(Duration.ofSeconds(30));
        return RestClient.builder().requestFactory(factory).build();
    }

    // sends the roadmap PDF to the visitor, in the background so generating the roadmap is not slowed down.
    // a failed message never breaks the roadmap, it is only printed.
    @Async
    public void sendRoadmapPdf(String phone, Integer visitorId, Integer roadmapId, boolean group){
        if(!isConfigured()){
            System.out.println("WhatsApp is not set (ULTRAMSG_INSTANCE_ID / ULTRAMSG_TOKEN), roadmap PDF not sent");
            return;
        }
        try{
            byte[] pdf = journeyPdfService.getRoadmapPdf(visitorId, roadmapId);
            String caption = group
                    ? "رحلتكم في إكسبو الرياض جاهزة! شاركوا الملف مع أحبابكم."
                    : "رحلتك في إكسبو الرياض جاهزة! تقدر تشاركها مع أحبابك.";
            sendDocument(phone, "wijha-roadmap.pdf", pdf, caption);
            sendRoadmapPdfNow(phone, visitorId, roadmapId, group);
        }catch(Exception e){
            System.out.println("WhatsApp roadmap PDF failed: " + e.getMessage());
        }
    }

    // same as above but the caller waits and learns if it was sent (used by the "send to my WhatsApp" button)
    public boolean sendRoadmapPdfNow(String phone, Integer visitorId, Integer roadmapId, boolean group){
        if(!isConfigured()){
            System.out.println("WhatsApp is not set (ULTRAMSG_INSTANCE_ID / ULTRAMSG_TOKEN), roadmap PDF not sent");
            return false;
        }
        byte[] pdf = journeyPdfService.getRoadmapPdf(visitorId, roadmapId);
        String caption = group
                ? "رحلتكم في إكسبو الرياض جاهزة! شاركوا الملف مع أحبابكم."
                : "رحلتك في إكسبو الرياض جاهزة! تقدر تشاركها مع أحبابك.";
        return sendDocument(phone, "wijha-roadmap.pdf", pdf, caption);
    }

    // POST {api-url}/{instance}/messages/document, the file is sent as base64
    // phone is the international format from the user, e.g. +966501234567
    public boolean sendDocument(String phone, String fileName, byte[] file, String caption){
        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("token", token);
        form.add("to", phone);
        form.add("filename", fileName);
        form.add("document", Base64.getEncoder().encodeToString(file));
        form.add("caption", caption);

        String answer;
        try{
            answer = restClient.post()
                    .uri(apiUrl + "/" + instanceId + "/messages/document")
                    .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                    .accept(MediaType.APPLICATION_JSON)
                    .body(form)
                    .retrieve()
                    .body(String.class);
        }catch(RestClientResponseException e){
            System.out.println("UltraMsg error " + e.getStatusCode() + ": " + e.getResponseBodyAsString());
            return false;
        }catch(RestClientException e){
            System.out.println("UltraMsg connection problem: " + e.getMessage());
            return false;
        }

        // success looks like {"sent":"true","message":"ok","id":1}, a problem looks like {"error":"..."}
        try{
            Map<?, ?> result = objectMapper.readValue(answer, Map.class);
            if("true".equals(String.valueOf(result.get("sent")))){
                return true;
            }
            System.out.println("UltraMsg did not send the document: " + answer);
        }catch(Exception e){
            System.out.println("UltraMsg answer not understood: " + answer);
        }
        return false;
    }

    // POST {api-url}/{instance}/messages/chat, a plain text message (used for the crowd alerts)
    public boolean sendText(String phone, String text){
        if(!isConfigured()){
            System.out.println("WhatsApp is not set (ULTRAMSG_INSTANCE_ID / ULTRAMSG_TOKEN), text not sent");
            return false;
        }
        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("token", token);
        form.add("to", phone);
        form.add("body", text);

        String answer;
        try{
            answer = restClient.post()
                    .uri(apiUrl + "/" + instanceId + "/messages/chat")
                    .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                    .accept(MediaType.APPLICATION_JSON)
                    .body(form)
                    .retrieve()
                    .body(String.class);
        }catch(RestClientResponseException e){
            System.out.println("UltraMsg error " + e.getStatusCode() + ": " + e.getResponseBodyAsString());
            return false;
        }catch(RestClientException e){
            System.out.println("UltraMsg connection problem: " + e.getMessage());
            return false;
        }
        try{
            Map<?, ?> result = objectMapper.readValue(answer, Map.class);
            if("true".equals(String.valueOf(result.get("sent")))){
                return true;
            }
            System.out.println("UltraMsg did not send the text: " + answer);
        }catch(Exception e){
            System.out.println("UltraMsg answer not understood: " + answer);
        }
        return false;
    }

    private boolean isConfigured(){
        return instanceId != null && !instanceId.isBlank() && token != null && !token.isBlank();
    }
}

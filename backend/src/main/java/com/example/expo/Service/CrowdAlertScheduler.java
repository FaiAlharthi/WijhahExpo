package com.example.expo.Service;

import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

// checks the crowd every 5 minutes and sends the WhatsApp alerts
@Component
@RequiredArgsConstructor
public class CrowdAlertScheduler {
    private final CrowdService crowdService;

    @Scheduled(initialDelay = 60000, fixedRate = 300000)
    public void checkCrowd(){
        try{
            int sent = crowdService.checkAlerts();
            if(sent > 0){
                System.out.println("Crowd alerts sent: " + sent);
            }
        }catch(Exception e){
            System.out.println("Crowd check failed: " + e.getMessage());
        }
    }
}

package com.example.expo.Service;

import com.example.expo.Api.ApiException;
import com.example.expo.Dto.Out.PassportResponse;
import com.example.expo.Dto.Out.PassportStampDTO;
import com.example.expo.Dto.Out.PassportVisitResponse;
import com.example.expo.Model.*;
import com.example.expo.Repository.PassportRepository;
import com.example.expo.Repository.StampRepository;
import com.example.expo.Repository.VisitRepository;
import com.example.expo.Repository.VisitorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.*;

@Service
@RequiredArgsConstructor
public class PassportService {
    private final PassportRepository passportRepository;
    private final VisitorRepository visitorRepository;
    private final VisitRepository visitRepository;
    private final StampRepository stampRepository;

    public List<Passport> getAllPassports(){
        return passportRepository.findAll();
    }

    // The visitor passport with real visits only
    public PassportResponse getVisitorPassport(Integer visitorId){
        Visitor visitor = visitorRepository.findVisitorById(visitorId);
        if(visitor == null){
            throw new ApiException("Visitor not found");
        }
        Passport passport = visitor.getPassport();
        if(passport == null){
            throw new ApiException("Passport not found");
        }
        List<Visit> visits = visitRepository.findVisitsByPassportAndIsVisitedTrue(passport);
        visits.sort(Comparator.comparing(Visit::getVisitedAt, Comparator.nullsLast(Comparator.reverseOrder())));
        List<PassportVisitResponse> stamps = new ArrayList<>();
        for(Visit visit : visits){
            Pavilion pavilion = visit.getPavilion();
            stamps.add(new PassportVisitResponse(visit.getId(), pavilion.getId(), pavilion.getName(), pavilion.getCountry(),
                    pavilion.getZone() == null ? null : pavilion.getZone().getName(), pavilion.getImageUrl(), visit.getVisitedAt()));
        }
        return new PassportResponse(passport.getId(), passport.getPassportNumber(), stamps.size(), stamps);
    }


    // Every stamp in the expo for this visitor, earned ones carry the first check-in time, the rest are faded in the app
    // the passport comes from the logged-in visitor, so nobody can read another visitor's stamps
    public List<PassportStampDTO> getVisitorStamps(Integer visitorId){
        Visitor visitor = visitorRepository.findVisitorById(visitorId);
        if(visitor == null){
            throw new ApiException("Visitor not found");
        }
        Passport passport = visitor.getPassport();
        if(passport == null){
            throw new ApiException("Passport not found");
        }
        // pavilionId -> first time this passport checked in there
        Map<Integer, LocalDateTime> firstVisit = new HashMap<>();
        for(Visit visit : visitRepository.findVisitsByPassportAndIsVisitedTrue(passport)){
            if(visit.getPavilion() == null){
                continue;
            }
            firstVisit.merge(visit.getPavilion().getId(), visit.getVisitedAt(),
                    (oldTime, newTime) -> newTime.isBefore(oldTime) ? newTime : oldTime);
        }

        List<PassportStampDTO> stamps = new ArrayList<>();
        for(Stamp stamp : stampRepository.findAll()){
            Integer pavilionId = stamp.getPavilionId();
            boolean earned = pavilionId != null && firstVisit.containsKey(pavilionId);
            stamps.add(new PassportStampDTO(stamp.getId(), stamp.getTitle(), stamp.getImageUrl(),
                    pavilionId, stamp.getPavilionName(), earned, earned ? firstVisit.get(pavilionId) : null));
        }
        return stamps;
    }

}

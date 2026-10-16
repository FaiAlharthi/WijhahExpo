package com.example.expo.Service;

import com.example.expo.Api.ApiException;
import com.example.expo.Dto.Out.PavilionDetailsResponse;
import com.example.expo.Dto.Out.PavilionReviewResponse;
import com.example.expo.Model.*;
import com.example.expo.Repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class PavilionService {

    private final PavilionRepository pavilionRepository;
    private final ZoneRepository zoneRepository;
    private final LocationRepository locationRepository;
    private final VisitorRepository visitorRepository;
    private final ReviewRepository reviewRepository;
    private final StampRepository stampRepository;
    private final AccessibilityService accessibilityService;

    // pavilion page with the reviews of the visitors
    public PavilionDetailsResponse getPavilionDetails(Integer pavilionId){
        Pavilion pavilion = pavilionRepository.findPavilionById(pavilionId);
        if(pavilion == null){
            throw new ApiException("Pavilion not found");
        }
        List<PavilionReviewResponse> reviews = new ArrayList<>();
        for(Review review : reviewRepository.findReviewsByPavilionOrderByCreatedAtDesc(pavilion)){
            String visitorName = review.getVisitor() == null || review.getVisitor().getUser() == null
                    ? null : review.getVisitor().getUser().getFullName();
            reviews.add(new PavilionReviewResponse(review.getId(), visitorName, review.getRating(), review.getComment(), review.getCreatedAt()));
        }
        Zone zone = pavilion.getZone();
        Location location = pavilion.getLocation();
        return new PavilionDetailsResponse(pavilion.getId(), pavilion.getName(), pavilion.getCountry(), pavilion.getDescription(),
                pavilion.getImageUrl(), zone == null ? null : zone.getId(), zone == null ? null : zone.getName(),
                location == null ? null : location.getX(), location == null ? null : location.getY(), reviews,
                accessibilityService.pavilionAccessibility(pavilion));
    }

    public List<Pavilion>getAllPavilion(){
        return pavilionRepository.findAll();
    }

    public void addPavilion(Integer zoneId, Integer locationId,Pavilion pavilion){
        Zone zone=zoneRepository.findZoneById(zoneId);
        if(zone==null){
            throw new ApiException("Zone not found");
        }
        Location location=locationRepository.findLocationById(locationId);
        if(location==null){
            throw new ApiException("Location not found");
        }
        if(location.getZone()!=null||location.getPavilion()!= null){
            throw new ApiException("Location is already used");
        }
        if(pavilionRepository.findPavilionByName(pavilion.getName())!=null){
            throw new ApiException("Pavilion already exists");
        }
        pavilion.setZone(zone);
        pavilion.setLocation(location);
        Pavilion savedPavilion = pavilionRepository.save(pavilion);

        // every pavilion gets its own stamp, the design (imageUrl) can be added later
        Stamp stamp = new Stamp();
        stamp.setTitle(savedPavilion.getName() + " Stamp");
        stamp.setPavilion(savedPavilion);
        stamp.setImageUrl(Stamp.imageUrlFor(savedPavilion));
        stampRepository.save(stamp);
    }

    public void updatePavilion(Integer id, Pavilion pavilion){
        Pavilion oldPavilion = pavilionRepository.findPavilionById(id);
        if(oldPavilion==null){
            throw new ApiException("Pavilion not found");
        }
        Pavilion samePavilion = pavilionRepository.findPavilionByName(pavilion.getName());
        if(samePavilion!=null&&!samePavilion.getId().equals(id)){
            throw new ApiException("Pavilion already exists");
        }
        oldPavilion.setName(pavilion.getName());
        oldPavilion.setCountry(pavilion.getCountry());
        oldPavilion.setDescription(pavilion.getDescription());

        oldPavilion.setImageUrl(pavilion.getImageUrl());
        // crowd data is optional in the request, kept when it is not sent
        if(pavilion.getCapacity() != null){
            oldPavilion.setCapacity(pavilion.getCapacity());
        }
        if(pavilion.getAvgVisitMinutes() != null){
            oldPavilion.setAvgVisitMinutes(pavilion.getAvgVisitMinutes());
        }
        pavilionRepository.save(oldPavilion);
        // the stamp design follows the country
        Stamp stamp = stampRepository.findStampByPavilion(oldPavilion);
        if(stamp!=null){
            stamp.setImageUrl(Stamp.imageUrlFor(oldPavilion));
            stampRepository.save(stamp);
        }
    }

    public void deletePavilion(Integer id){
        Pavilion pavilion= pavilionRepository.findPavilionById(id);
        if(pavilion ==null){
            throw new ApiException("Pavilion not found");
        }
        if(pavilion.getVisits()!=null&&!pavilion.getVisits().isEmpty()){
            throw new ApiException("Pavilion has visits");
        }
        pavilionRepository.delete(pavilion);
    }

     //endpoint أجنحة زون معينة
    public List<Pavilion>getPavilionsByZone(Integer zone_id){
        Zone zone=zoneRepository.findZoneById(zone_id);
        if(zone == null){
            throw new ApiException("Zone not found");
        }
        return pavilionRepository.findPavilionByZone(zone);
    }

    //endpoint ابحث بالاسم عن جناح
    public List<Pavilion>searchPavilion(String name){
        List<Pavilion>pavilions=pavilionRepository.findPavilionsByNameContaining(name);
        if(pavilions.isEmpty()){
            throw new ApiException("No pavilions found");
        }
        return pavilions;
    }

    //3) الأجنحة مرتبة حسب التقييم
    public List<Pavilion> getTopRatedPavilions(){
        List<Pavilion> pavilions = pavilionRepository.findTopRatedPavilions();
        if(pavilions.isEmpty()){
            throw new ApiException("No rated pavilions yet");
        }
        return pavilions;
    }

    // 4) الأجنحة اللي ما زارها الزائر
    public List<Pavilion> getUnvisitedPavilions(Integer visitorId){
        Visitor visitor = visitorRepository.findVisitorById(visitorId);
        if(visitor == null){
            throw new ApiException("Visitor not found");
        }
        List<Pavilion> unvisited = new ArrayList<>();
        for(Pavilion pavilion : pavilionRepository.findAll()){
            boolean visited=false;
            if(visitor.getPassport() != null && visitor.getPassport().getVisits() != null){
                for(Visit visit : visitor.getPassport().getVisits()){
                    if(visit.getIsVisited() && visit.getPavilion().getId().equals(pavilion.getId())){
                        visited = true;
                    }
                }
            }
            if(!visited){
                unvisited.add(pavilion);
            }
        }
        return unvisited;
    }






}

package com.example.expo.Config;

import com.example.expo.Model.*;
import com.example.expo.Repository.*;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;
import tools.jackson.databind.ObjectMapper;

import java.io.InputStream;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

// fills the database from data/expo-data.json on startup
// zones, entrances and pavilions only if they are empty, paths only if there are no paths
@Component
@RequiredArgsConstructor
public class DataSeeder implements CommandLineRunner {
    private final LocationRepository locationRepository;
    private final ZoneRepository zoneRepository;
    private final EntranceRepository entranceRepository;
    private final PavilionRepository pavilionRepository;
    private final PathRepository pathRepository;
    private final VisitorRepository visitorRepository;
    private final PassportRepository passportRepository;
    private final InterestRepository interestRepository;
    private final StampRepository stampRepository;
    private final PavilionAccessibilityRepository pavilionAccessibilityRepository;

    @Override
    public void run(String... args) throws Exception {
        InputStream file = new ClassPathResource("data/expo-data.json").getInputStream();
        SeedData data = new ObjectMapper().readValue(file, SeedData.class);

        if(zoneRepository.count() == 0 && entranceRepository.count() == 0 && pavilionRepository.count() == 0){
            seedPlaces(data);
        }
        if(pathRepository.count() == 0 && data.getPaths() != null){
            seedPaths(data);
        }
        if(data.getInterests() != null){
            seedInterests(data);
        }
        addMissingPassports();
        addMissingStamps();
        addMissingAccessibility(data);
        addMissingCrowdData(data);
    }

    // capacity and visit minutes for pavilions created before the crowd estimate
    private void addMissingCrowdData(SeedData data){
        if(data.getPavilions() == null){
            return;
        }
        for(SeedPavilion seedPavilion : data.getPavilions()){
            Pavilion pavilion = pavilionRepository.findPavilionByName(seedPavilion.getName());
            if(pavilion == null || (pavilion.getCapacity() != null && pavilion.getAvgVisitMinutes() != null)){
                continue;
            }
            if(pavilion.getCapacity() == null){
                pavilion.setCapacity(seedPavilion.getCapacity());
            }
            if(pavilion.getAvgVisitMinutes() == null){
                pavilion.setAvgVisitMinutes(seedPavilion.getAvgVisitMinutes());
            }
            pavilionRepository.save(pavilion);
        }
    }

    // fills the accessibility of the pavilions (by name) and of the paths that have none yet
    private void addMissingAccessibility(SeedData data){
        if(data.getPavilions() != null){
            for(SeedPavilion seedPavilion : data.getPavilions()){
                if(seedPavilion.getAccessibility() == null){
                    continue;
                }
                Pavilion pavilion = pavilionRepository.findPavilionByName(seedPavilion.getName());
                if(pavilion == null){
                    continue;
                }
                for(Map.Entry<String, SeedAccessibility> entry : seedPavilion.getAccessibility().entrySet()){
                    if(pavilionAccessibilityRepository.findPavilionAccessibilityByPavilionAndNeedType(pavilion, entry.getKey()) != null){
                        continue;
                    }
                    PavilionAccessibility row = new PavilionAccessibility();
                    row.setPavilion(pavilion);
                    row.setNeedType(entry.getKey());
                    row.setStatus(entry.getValue().getStatus());
                    row.setNote(entry.getValue().getNote());
                    row.setNoteAr(entry.getValue().getNoteAr());
                    pavilionAccessibilityRepository.save(row);
                }
            }
        }
        if(data.getPaths() == null){
            return;
        }
        Map<String, Location> points = pointsByName();
        for(SeedPath seedPath : data.getPaths()){
            Location from = points.get(seedPath.getFrom());
            Location to = points.get(seedPath.getTo());
            if(from == null || to == null){
                continue;
            }
            Path path = pathRepository.findPathByFromLocationAndToLocation(from, to);
            if(path == null){
                path = pathRepository.findPathByFromLocationAndToLocation(to, from);
            }
            if(path == null || (path.getStepFree() != null && path.getShaded() != null)){
                continue;
            }
            path.setStepFree(seedPath.getStepFree() == null || seedPath.getStepFree());
            path.setShaded(seedPath.getShaded() != null && seedPath.getShaded());
            pathRepository.save(path);
        }
    }

    private Map<String, Location> pointsByName(){
        Map<String, Location> points = new HashMap<>();
        for(Zone zone : zoneRepository.findAll()){
            points.put("ZONE:" + zone.getName(), zone.getLocation());
        }
        for(Entrance entrance : entranceRepository.findAll()){
            points.put("ENTRANCE:" + entrance.getName(), entrance.getLocation());
        }
        for(Pavilion pavilion : pavilionRepository.findAll()){
            points.put("PAVILION:" + pavilion.getName(), pavilion.getLocation());
        }
        return points;
    }

    // every pavilion has one stamp, covers seeded pavilions and ones created before stamps existed
    private void addMissingStamps() {
        for (Pavilion pavilion : pavilionRepository.findAll()) {
            Stamp stamp = stampRepository.findStampByPavilion(pavilion);
            if (stamp == null) {
                stamp = new Stamp();
                stamp.setTitle(pavilion.getName() + " Stamp");
                stamp.setPavilion(pavilion);
            }
            // fills the design for new stamps and for old ones that had none
            if (stamp.getImageUrl() == null || stamp.getImageUrl().isBlank()) {
                stamp.setImageUrl(Stamp.imageUrlFor(pavilion));
                stampRepository.save(stamp);
            }
        }
    }

    // adds the fixed interests that are missing, and fills the arabic name of old ones
    private void seedInterests(SeedData data){
        for(SeedInterest seedInterest : data.getInterests()){
            Interest interest = interestRepository.findInterestByName(seedInterest.getName());
            if(interest == null){
                interest = new Interest();
                interest.setName(seedInterest.getName());
            }else if(interest.getNameAr() != null && !interest.getNameAr().isBlank()){
                continue;
            }
            interest.setNameAr(seedInterest.getNameAr());
            interestRepository.save(interest);
        }
    }

    // visitors registered before passports were automatic
    private void addMissingPassports(){
        for(Visitor visitor : visitorRepository.findAll()){
            if(visitor.getPassport() == null){
                Passport passport = new Passport();
                passport.setPassportNumber(String.format("EXPO30-%06d", visitor.getId()));
                passport.setVisitor(visitor);
                passportRepository.save(passport);
            }
        }
    }

    private void seedPlaces(SeedData data){
        Map<String, Zone> zones = new HashMap<>();
        for(SeedZone seedZone : data.getZones()){
            Zone zone = new Zone();
            zone.setName(seedZone.getName());
            zone.setDescription(seedZone.getDescription());
            zone.setLocation(saveLocation(seedZone.getLocation()));
            zoneRepository.save(zone);
            zones.put(zone.getName(), zone);
        }

        for(SeedEntrance seedEntrance : data.getEntrances()){
            Entrance entrance = new Entrance();
            entrance.setName(seedEntrance.getName());
            entrance.setLocation(saveLocation(seedEntrance.getLocation()));
            entranceRepository.save(entrance);
        }

        for(SeedPavilion seedPavilion : data.getPavilions()){
            Pavilion pavilion = new Pavilion();
            pavilion.setName(seedPavilion.getName());
            pavilion.setCountry(seedPavilion.getCountry());
            pavilion.setDescription(seedPavilion.getDescription());
            pavilion.setImageUrl(seedPavilion.getImageUrl());
            pavilion.setCapacity(seedPavilion.getCapacity());
            pavilion.setAvgVisitMinutes(seedPavilion.getAvgVisitMinutes());

            pavilion.setZone(zones.get(seedPavilion.getZone()));
            pavilion.setLocation(saveLocation(seedPavilion.getLocation()));
            pavilionRepository.save(pavilion);
        }
    }

    // finds the points by type and name, distance is calculated from x and y
    private void seedPaths(SeedData data){
        Map<String, Location> points = new HashMap<>();
        for(Zone zone : zoneRepository.findAll()){
            points.put("ZONE:" + zone.getName(), zone.getLocation());
        }
        for(Entrance entrance : entranceRepository.findAll()){
            points.put("ENTRANCE:" + entrance.getName(), entrance.getLocation());
        }
        for(Pavilion pavilion : pavilionRepository.findAll()){
            points.put("PAVILION:" + pavilion.getName(), pavilion.getLocation());
        }

        for(SeedPath seedPath : data.getPaths()){
            Location from = points.get(seedPath.getFrom());
            Location to = points.get(seedPath.getTo());
            if(from == null || to == null){
                continue;
            }
            Path path = new Path();
            path.setFromLocation(from);
            path.setToLocation(to);
            path.setDistance(Math.sqrt(Math.pow(to.getX() - from.getX(), 2) + Math.pow(to.getY() - from.getY(), 2)));
            path.setStepFree(seedPath.getStepFree() == null || seedPath.getStepFree());
            path.setShaded(seedPath.getShaded() != null && seedPath.getShaded());
            pathRepository.save(path);
        }
    }

    private Location saveLocation(SeedLocation seedLocation){
        Location location = new Location();
        location.setX(seedLocation.getX());
        location.setY(seedLocation.getY());
        return locationRepository.save(location);
    }

    // shapes of the json file
    @Data
    @NoArgsConstructor
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class SeedData {
        private List<SeedZone> zones;
        private List<SeedEntrance> entrances;
        private List<SeedPavilion> pavilions;
        private List<SeedPath> paths;
        private List<SeedInterest> interests;
    }

    @Data
    @NoArgsConstructor
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class SeedInterest {
        private String name;
        private String nameAr;
    }

    @Data
    @NoArgsConstructor
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class SeedPath {
        private String from;
        private String to;
        private Boolean stepFree;
        private Boolean shaded;
    }

    @Data
    @NoArgsConstructor
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class SeedAccessibility {
        private String status;
        private String note;
        private String noteAr;
    }

    @Data
    @NoArgsConstructor
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class SeedLocation {
        private Double x;
        private Double y;
    }

    @Data
    @NoArgsConstructor
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class SeedZone {
        private String name;
        private String description;
        private SeedLocation location;
    }

    @Data
    @NoArgsConstructor
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class SeedEntrance {
        private String name;
        private SeedLocation location;
    }

    @Data
    @NoArgsConstructor
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class SeedPavilion {
        private String name;
        private String country;
        private String description;
        private String imageUrl;
        private String zone;
        private SeedLocation location;
        private Map<String, SeedAccessibility> accessibility;
        private Integer capacity;
        private Integer avgVisitMinutes;
    }
}

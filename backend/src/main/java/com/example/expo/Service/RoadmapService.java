package com.example.expo.Service;

import com.example.expo.Api.ApiException;
import com.example.expo.Dto.In.GenerateRoadmapRequest;
import com.example.expo.Dto.In.ReorderStopsRequest;
import com.example.expo.Dto.Out.RoadmapBreakResponse;
import com.example.expo.Dto.Out.RoadmapResponse;
import com.example.expo.Dto.Out.RoadmapStopResponse;
import com.example.expo.Model.CrowdAlert;
import com.example.expo.Model.Entrance;
import com.example.expo.Model.Location;
import com.example.expo.Model.Interest;
import com.example.expo.Model.Passport;
import com.example.expo.Model.Pavilion;
import com.example.expo.Model.Review;
import com.example.expo.Model.Roadmap;
import com.example.expo.Model.Visit;
import com.example.expo.Model.Visitor;
import com.example.expo.Model.Zone;
import com.example.expo.Repository.CrowdAlertRepository;
import com.example.expo.Repository.EntranceRepository;
import com.example.expo.Repository.InterestRepository;
import com.example.expo.Repository.PavilionRepository;
import com.example.expo.Repository.ReviewRepository;
import com.example.expo.Repository.RoadmapRepository;
import com.example.expo.Repository.VisitRepository;
import com.example.expo.Repository.VisitorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import tools.jackson.databind.ObjectMapper;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class RoadmapService {
    private final RoadmapRepository roadmapRepository;
    private final VisitorRepository visitorRepository;
    private final VisitRepository visitRepository;
    private final EntranceRepository entranceRepository;
    private final PavilionRepository pavilionRepository;
    private final PathService pathService;
    private final GeminiService geminiService;
    private final ReviewRepository reviewRepository;
    private final InterestRepository interestRepository;
    private final WhatsAppService whatsAppService;
    private final AccessibilityService accessibilityService;
    private final CrowdService crowdService;
    private final CrowdAlertRepository crowdAlertRepository;

    private final ObjectMapper objectMapper = new ObjectMapper();

    // average minutes per pavilion, temporary until the AI is added
    private static final int MINUTES_PER_PAVILION = 30;
    // a trip with a mobility need moves slower
    private static final int MINUTES_PER_PAVILION_MOBILITY = 40;
    // one minute in a queue counts like one minute of walking (75 m = 37.5 map units)
    private static final double UNITS_PER_QUEUE_MINUTE = 37.5;

    // day and time used to look at the expected queue while ordering, null = queue is not used
    private record PlanClock(LocalDate date, LocalTime time){}

    public List<Roadmap> getAllRoadmaps(){
        return roadmapRepository.findAll();
    }

    // creates the day roadmap, or replaces it if it already exists
    // the entrance is chosen by the system (shortest walk), the visitor can change it later
    public RoadmapResponse generateRoadmap(Integer visitorId, GenerateRoadmapRequest request){
        Visitor visitor = visitorRepository.findVisitorById(visitorId);
        if(visitor == null){
            throw new ApiException("visitor not found");
        }
        if(visitor.getInterests() == null || visitor.getInterests().size() < 3){
            throw new ApiException("add at least 3 interests first");
        }
        Set<Interest> extraInterests = new HashSet<>();
        if(request.getExtraInterestIds() != null){
            for(Integer interestId : request.getExtraInterestIds()){
                Interest interest = interestRepository.findInterestById(interestId);
                if(interest == null){
                    throw new ApiException("interest not found");
                }
                extraInterests.add(interest);
            }
        }
        Roadmap answers = toRoadmap(request);
        checkDateAndTime(answers);
        if(answers.getVisitDate().isBefore(LocalDate.now())){
            throw new ApiException("cannot generate a roadmap for a past day");
        }

        Roadmap roadmap = roadmapRepository.findRoadmapByVisitorAndVisitDate(visitor, answers.getVisitDate());
        if(roadmap == null){
            roadmap = answers;
            roadmap.setVisitor(visitor);
            roadmap.setCreatedAt(LocalDateTime.now());
        }else{
            checkNotLocked(roadmap);
            copyAnswers(answers, roadmap);
            // only the latest version counts, visited stops stay
            visitRepository.deleteAll(visitRepository.findVisitsByRoadmapAndIsVisitedFalse(roadmap));
        }
        roadmap.setExtraInterests(extraInterests);
        roadmapRepository.save(roadmap);

        int lastOrder = 0;
        boolean started = false;
        for(Visit stop : visitRepository.findVisitsByRoadmapOrderByStopOrderAsc(roadmap)){
            if(stop.getStopOrder() != null && stop.getStopOrder() > lastOrder){
                lastOrder = stop.getStopOrder();
            }
            if(stop.getIsVisited()){
                started = true;
            }
        }
        // after the first visit the entrance stays the same
        Entrance lockedEntrance = started ? roadmap.getEntrance() : null;

        Set<String> needs = roadmap.getAccessibilityNeeds();
        Set<Integer> visitedToday = new HashSet<>();
        List<Pavilion> candidates = selectPavilions(visitor, roadmap, visitedToday);

        long minutes = Duration.between(roadmap.getArrivalTime(), roadmap.getDepartureTime()).toMinutes();
        int minutesPerPavilion = AccessibilityService.needsStepFree(needs) ? MINUTES_PER_PAVILION_MOBILITY : MINUTES_PER_PAVILION;
        int maxStops = (int) (minutes / minutesPerPavilion) - visitedToday.size();
        if(maxStops <= 0){
            throw new ApiException("not enough time for more pavilions today");
        }

        // AI chooses the pavilions, Dijkstra orders them and avoids the expected queues
        crowdService.invalidate();
        PlanClock clock = new PlanClock(roadmap.getVisitDate(), roadmap.getArrivalTime());
        List<Pavilion> ordered;
        boolean aiUsed = false;
        roadmap.setAiBreaks(null);
        roadmap.setAiSummary(null);
        try{
            Map<?, ?> aiAnswer = objectMapper.readValue(geminiService.ask(buildPrompt(visitor, roadmap, candidates)), Map.class);
            List<Pavilion> selected = readSelectedPavilions(aiAnswer, candidates);
            if(selected.isEmpty()){
                throw new ApiException("AI selected no pavilions");
            }
            Entrance entrance = lockedEntrance != null ? lockedEntrance : bestEntrance(selected, selected.size(), needs, clock);
            roadmap.setEntrance(entrance);
            ordered = orderPavilions(entrance.getLocation(), selected, selected.size(), needs, clock);
            roadmap.setAiBreaks(aiAnswer.get("breaks") == null ? null : objectMapper.writeValueAsString(aiAnswer.get("breaks")));
            roadmap.setAiSummary(aiAnswer.get("summary") == null ? null : aiAnswer.get("summary").toString());
            aiUsed = true;
        }catch(Exception e){
            // AI failed, use the nearest pavilions
            System.out.println("AI roadmap failed: " + e.getMessage());
            List<Pavilion> preferred = preferFullyAccessible(candidates, needs, maxStops);
            Entrance entrance = lockedEntrance != null ? lockedEntrance : bestEntrance(preferred, maxStops, needs, clock);
            roadmap.setEntrance(entrance);
            ordered = orderPavilions(entrance.getLocation(), preferred, maxStops, needs, clock);
        }
        roadmapRepository.save(roadmap);

        saveStops(roadmap, ordered, lastOrder);
        crowdService.invalidate();
        RoadmapResponse result = toRoadmapResponse(roadmap);
        result.setAiUsed(aiUsed);
        // the visitor gets the roadmap PDF on WhatsApp (background, never fails the roadmap)
        //whatsAppService.sendRoadmapPdf(visitor.getUser().getPhone(), visitorId, roadmap.getId(), "GROUP".equals(roadmap.getPartyType()));
        return result;
    }

    // the visitor asks for the roadmap PDF on the WhatsApp number of their account
    public void sendPdfToWhatsApp(Integer visitorId, Integer roadmapId){
        Roadmap roadmap = getVisitorRoadmap(visitorId, roadmapId);
        String phone = roadmap.getVisitor().getUser().getPhone();
        if(phone == null || phone.isBlank()){
            throw new ApiException("no phone number in your account");
        }
        if(!whatsAppService.sendRoadmapPdfNow(phone, visitorId, roadmapId, "GROUP".equals(roadmap.getPartyType()))){
            throw new ApiException("could not send the PDF on WhatsApp, try again later");
        }
    }

    public RoadmapResponse getStops(Integer visitorId, Integer roadmapId){
        Roadmap roadmap = getVisitorRoadmap(visitorId, roadmapId);
        return toRoadmapResponse(roadmap);
    }

    private RoadmapResponse toRoadmapResponse(Roadmap roadmap){
        List<RoadmapBreakResponse> breaks = new ArrayList<>();
        if(roadmap.getAiBreaks() != null){
            try{
                for(Object item : objectMapper.readValue(roadmap.getAiBreaks(), List.class)){
                    Map<?, ?> b = (Map<?, ?>) item;
                    breaks.add(new RoadmapBreakResponse(
                            b.get("type") == null ? null : b.get("type").toString(),
                            b.get("time") == null ? null : b.get("time").toString(),
                            b.get("minutes") instanceof Number n ? n.intValue() : null,
                            b.get("note") == null ? null : b.get("note").toString()));
                }
            }catch(Exception e){
                breaks = new ArrayList<>();
            }
        }
        List<RoadmapStopResponse> stops = new ArrayList<>();
        // expected time and queue of every stop
        Map<Integer, CrowdService.Stay> stays = new HashMap<>();
        for(CrowdService.Stay stay : crowdService.timeline(roadmap)){
            stays.put(stay.visitId(), stay);
        }
        for(Visit visit : visitRepository.findVisitsByRoadmapOrderByStopOrderAsc(roadmap)){
            Pavilion pavilion = visit.getPavilion();
            CrowdService.Stay stay = stays.get(visit.getId());
            String plannedTime = stay == null ? null : stay.start().toString();
            Integer expectedWait = stay == null || visit.getIsVisited() ? null : crowdService.waitMinutes(pavilion, roadmap.getVisitDate(), stay.start());
            stops.add(new RoadmapStopResponse(visit.getId(), visit.getStopOrder(), pavilion.getId(), pavilion.getName(),
                    pavilion.getCountry(), pavilion.getZone() == null ? null : pavilion.getZone().getName(),
                    pavilion.getImageUrl(), visit.getIsVisited(), visit.getVisitedAt(),
                    accessibilityService.warnings(pavilion, roadmap.getAccessibilityNeeds()), plannedTime, expectedWait));
        }
        // a summary means the AI made this roadmap
        Entrance entrance = roadmap.getEntrance();
        return new RoadmapResponse(roadmap.getId(), roadmap.getVisitDate(),
                entrance == null ? null : entrance.getId(), entrance == null ? null : entrance.getName(), roadmap.getAiSummary(),
                roadmap.getAiSummary() != null, breaks, stops,
                roadmap.getAccessibilityNeeds() == null ? new HashSet<>() : new HashSet<>(roadmap.getAccessibilityNeeds()),
                Boolean.TRUE.equals(roadmap.getWhatsappAlerts()));
    }

    private Roadmap toRoadmap(GenerateRoadmapRequest request){
        Roadmap roadmap = new Roadmap();
        roadmap.setVisitDate(request.getVisitDate());
        roadmap.setPartyType(request.getPartyType());
        roadmap.setPartySize(request.getPartySize());
        roadmap.setArrivalTime(request.getArrivalTime());
        roadmap.setDepartureTime(request.getDepartureTime());
        roadmap.setExperienceTypes(request.getExperienceTypes());
        roadmap.setVisitPace(request.getVisitPace());
        roadmap.setIncludePrayerBreaks(request.getIncludePrayerBreaks() != null && request.getIncludePrayerBreaks());
        roadmap.setIncludeMealBreaks(request.getIncludeMealBreaks() != null && request.getIncludeMealBreaks());
        roadmap.setIncludeChildRestBreaks(request.getIncludeChildRestBreaks() != null && request.getIncludeChildRestBreaks());
        roadmap.setAllowRevisits(request.getAllowRevisits());
        roadmap.setAccessibilityNeeds(request.getAccessibilityNeeds() == null ? new HashSet<>() : new HashSet<>(request.getAccessibilityNeeds()));
        roadmap.setWhatsappAlerts(Boolean.TRUE.equals(request.getWhatsappAlerts()));
        return roadmap;
    }

    // everything the AI needs to choose the pavilions
    private String buildPrompt(Visitor visitor, Roadmap roadmap, List<Pavilion> candidates){
        StringBuilder prompt = new StringBuilder();
        prompt.append("You are the visit planner of Expo 2030 Riyadh. Choose the best pavilions for this visitor for one day.\n\n");

        prompt.append("VISITOR\n");
        prompt.append("age: ").append(visitor.getAge()).append(", gender: ").append(visitor.getGender())
                .append(", nationality: ").append(visitor.getNationality())
                .append(", language: ").append(visitor.getPreferredLanguage()).append("\n");
        List<String> interests = new ArrayList<>();
        if(visitor.getInterests() != null){
            for(Interest interest : visitor.getInterests()){
                interests.add(interest.getName());
            }
        }
        prompt.append("interests: ").append(interests).append("\n");
        List<String> extra = new ArrayList<>();
        if(roadmap.getExtraInterests() != null){
            for(Interest interest : roadmap.getExtraInterests()){
                extra.add(interest.getName());
            }
        }
        prompt.append("extra interests for today: ").append(extra.isEmpty() ? "none" : extra).append("\n\n");

        prompt.append("TODAY\n");
        prompt.append("date: ").append(roadmap.getVisitDate())
                .append(", arrival: ").append(roadmap.getArrivalTime())
                .append(", departure: ").append(roadmap.getDepartureTime()).append("\n");
        prompt.append("party: ").append(roadmap.getPartyType()).append(", size: ").append(roadmap.getPartySize()).append("\n");
        prompt.append("mood: ").append(roadmap.getExperienceTypes()).append(", pace: ").append(roadmap.getVisitPace()).append("\n");
        prompt.append("breaks wanted: prayer=").append(roadmap.getIncludePrayerBreaks())
                .append(", meal=").append(roadmap.getIncludeMealBreaks())
                .append(", child rest=").append(roadmap.getIncludeChildRestBreaks()).append("\n");
        prompt.append(accessibilityLine(roadmap));
        prompt.append("\n");

        prompt.append("PREVIOUS REVIEWS (rating 1-5)\n");
        boolean hasReviews = false;
        for(Review review : reviewRepository.findReviewsByVisitor(visitor)){
            if(review.getCreatedAt() != null && review.getCreatedAt().toLocalDate().isBefore(roadmap.getVisitDate())){
                prompt.append("- ").append(review.getPavilion().getName()).append(": ").append(review.getRating());
                if(review.getComment() != null){
                    prompt.append(" \"").append(review.getComment()).append("\"");
                }
                prompt.append("\n");
                hasReviews = true;
            }
        }
        if(!hasReviews){
            prompt.append("none\n");
        }

        appendPavilions(prompt, candidates, roadmap);

        prompt.append("\nRULES\n");
        prompt.append("- Choose only ids from the list above.\n");
        prompt.append(accessibilityRules(roadmap));
        prompt.append("- Match the interests, the mood, the party (solo or group) and the previous reviews (like what was rated high, avoid what was rated low).\n");
        prompt.append("- Estimate a realistic time for each pavilion and the walking between them. All chosen pavilions and the breaks must fit between arrival and departure. If time is short, choose the most important ones. RELAXED pace means fewer pavilions.\n");
        prompt.append("- Add only the breaks that are wanted. Prayer breaks use the prayer times in Riyadh for that date.\n");
        prompt.append("- Do not order the pavilions by distance, the system does that.\n");
        prompt.append("- Write the summary in Arabic if language is AR, otherwise in English.\n\n");

        prompt.append("Answer with JSON only in this shape:\n");
        prompt.append("{\"pavilionIds\": [1, 2], \"breaks\": [{\"type\": \"PRAYER|MEAL|CHILD_REST\", \"time\": \"HH:mm\", \"minutes\": 20, \"note\": \"short note\"}], \"summary\": \"one or two sentences about the plan\"}");
        return prompt.toString();
    }

    // keeps only valid ids from the AI answer, without duplicates
    private List<Pavilion> readSelectedPavilions(Map<?, ?> aiAnswer, List<Pavilion> candidates){
        Map<Integer, Pavilion> available = new HashMap<>();
        for(Pavilion pavilion : candidates){
            available.put(pavilion.getId(), pavilion);
        }
        List<Pavilion> selected = new ArrayList<>();
        if(aiAnswer.get("pavilionIds") instanceof List<?> ids){
            for(Object id : ids){
                if(id instanceof Number number){
                    Pavilion pavilion = available.remove(number.intValue());
                    if(pavilion != null){
                        selected.add(pavilion);
                    }
                }
            }
        }
        return selected;
    }

    // all roadmaps of the visitor, newest day first
    public List<RoadmapResponse> getVisitorRoadmaps(Integer visitorId){
        Visitor visitor = visitorRepository.findVisitorById(visitorId);
        if(visitor == null){
            throw new ApiException("visitor not found");
        }
        List<RoadmapResponse> roadmaps = new ArrayList<>();
        for(Roadmap roadmap : roadmapRepository.findRoadmapsByVisitorOrderByVisitDateDesc(visitor)){
            roadmaps.add(toRoadmapResponse(roadmap));
        }
        return roadmaps;
    }

    // adds a pavilion in the chosen position, only after the visited stops
    public RoadmapResponse addStop(Integer visitorId, Integer roadmapId, Integer pavilionId, Integer position){
        Roadmap roadmap = getVisitorRoadmap(visitorId, roadmapId);
        checkNotPast(roadmap);
        checkNotLocked(roadmap);
        Pavilion pavilion = pavilionRepository.findPavilionById(pavilionId);
        if(pavilion == null){
            throw new ApiException("pavilion not found");
        }
        List<Visit> stops = visitRepository.findVisitsByRoadmapOrderByStopOrderAsc(roadmap);
        int lastVisitedIndex = -1;
        for(int i = 0; i < stops.size(); i++){
            if(stops.get(i).getPavilion().getId().equals(pavilionId)){
                throw new ApiException("pavilion is already in this roadmap");
            }
            if(stops.get(i).getIsVisited()){
                lastVisitedIndex = i;
            }
        }
        int minPosition = lastVisitedIndex + 2;
        int maxPosition = stops.size() + 1;
        if(position == null || position < minPosition || position > maxPosition){
            throw new ApiException("position must be between " + minPosition + " and " + maxPosition);
        }
        // visited today outside the plan: the same visit joins the roadmap as visited
        Visit stop = null;
        Passport passport = roadmap.getVisitor().getPassport();
        if(passport != null){
            stop = visitRepository.findVisitByPassportAndPavilionAndRoadmapIsNullAndVisitedAtBetween(passport, pavilion,
                    roadmap.getVisitDate().atStartOfDay(), roadmap.getVisitDate().atTime(LocalTime.MAX));
        }
        if(stop == null){
            stop = new Visit();
            stop.setPavilion(pavilion);
            stop.setIsVisited(false);
        }
        stop.setRoadmap(roadmap);
        stops.add(position - 1, stop);
        renumberStops(stops);
        return toRoadmapResponse(roadmap);
    }

    // only unvisited stops can be removed
    public RoadmapResponse removeStop(Integer visitorId, Integer roadmapId, Integer visitId){
        Roadmap roadmap = getVisitorRoadmap(visitorId, roadmapId);
        checkNotPast(roadmap);
        checkNotLocked(roadmap);
        Visit stop = visitRepository.findVisitById(visitId);
        if(stop == null || stop.getRoadmap() == null || !stop.getRoadmap().getId().equals(roadmapId)){
            throw new ApiException("stop not found in this roadmap");
        }
        if(stop.getIsVisited()){
            throw new ApiException("you cannot remove a visited pavilion");
        }
        visitRepository.delete(stop);
        renumberStops(visitRepository.findVisitsByRoadmapOrderByStopOrderAsc(roadmap));
        return toRoadmapResponse(roadmap);
    }

    // visited stops keep their place, unvisited stops take the new order
    public RoadmapResponse reorderStops(Integer visitorId, Integer roadmapId, ReorderStopsRequest request){
        Roadmap roadmap = getVisitorRoadmap(visitorId, roadmapId);
        checkNotPast(roadmap);
        checkNotLocked(roadmap);
        List<Visit> stops = visitRepository.findVisitsByRoadmapOrderByStopOrderAsc(roadmap);
        Map<Integer, Visit> unvisited = new HashMap<>();
        for(Visit stop : stops){
            if(!stop.getIsVisited()){
                unvisited.put(stop.getId(), stop);
            }
        }
        if(request.getVisitIds().size() != unvisited.size() || !unvisited.keySet().containsAll(request.getVisitIds())
                || new HashSet<>(request.getVisitIds()).size() != request.getVisitIds().size()){
            throw new ApiException("send every unvisited stop of this roadmap once");
        }
        List<Visit> reordered = new ArrayList<>();
        int next = 0;
        for(Visit stop : stops){
            if(stop.getIsVisited()){
                reordered.add(stop);
            }else{
                reordered.add(unvisited.get(request.getVisitIds().get(next++)));
            }
        }
        renumberStops(reordered);
        crowdService.invalidate();
        return toRoadmapResponse(roadmap);
    }

    // regenerates the stops not visited yet based on the reviews of the visited ones, can be used again any time
    public RoadmapResponse makeDynamic(Integer visitorId, Integer roadmapId){
        Roadmap roadmap = getVisitorRoadmap(visitorId, roadmapId);
        checkNotPast(roadmap);
        checkNotLocked(roadmap);
        Visitor visitor = roadmap.getVisitor();
        List<Visit> stops = visitRepository.findVisitsByRoadmapOrderByStopOrderAsc(roadmap);
        List<Visit> visitedStops = new ArrayList<>();
        List<Visit> plannedStops = new ArrayList<>();
        for(Visit stop : stops){
            if(stop.getIsVisited()){
                visitedStops.add(stop);
            }else{
                plannedStops.add(stop);
            }
        }
        if(plannedStops.isEmpty()){
            throw new ApiException("there are no remaining stops to change");
        }
        List<Review> todayReviews = new ArrayList<>();
        for(Visit stop : visitedStops){
            Review review = reviewRepository.findReviewByVisitorAndPavilion(visitor, stop.getPavilion());
            if(review != null){
                todayReviews.add(review);
            }
        }
        if(todayReviews.isEmpty()){
            throw new ApiException("you have not visited and reviewed any of today's suggested pavilions yet!");
        }

        int stopsCount = plannedStops.size();
        Set<String> needs = roadmap.getAccessibilityNeeds();
        Set<Integer> visitedToday = new HashSet<>();
        List<Pavilion> candidates = selectPavilions(visitor, roadmap, visitedToday);
        Set<Integer> visitedIds = new HashSet<>();
        for(Visit stop : visitedStops){
            visitedIds.add(stop.getPavilion().getId());
        }
        candidates.removeIf(pavilion -> visitedIds.contains(pavilion.getId()));
        if(candidates.isEmpty()){
            throw new ApiException("no other pavilions are available today");
        }
        // start from the last visited pavilion
        Location start = visitedStops.get(visitedStops.size() - 1).getPavilion().getLocation();
        if(start == null){
            start = roadmap.getEntrance().getLocation();
        }

        List<Pavilion> selected;
        boolean aiUsed = false;
        try{
            Map<?, ?> aiAnswer = objectMapper.readValue(geminiService.ask(buildDynamicPrompt(visitor, roadmap, todayReviews, candidates, stopsCount)), Map.class);
            selected = readSelectedPavilions(aiAnswer, candidates);
            if(selected.isEmpty()){
                throw new ApiException("AI selected no pavilions");
            }
            if(aiAnswer.get("summary") != null){
                roadmap.setAiSummary(aiAnswer.get("summary").toString());
            }
            aiUsed = true;
        }catch(Exception e){
            // AI failed, use the zones the visitor liked
            System.out.println("AI dynamic roadmap failed: " + e.getMessage());
            selected = new ArrayList<>();
        }
        if(selected.size() > stopsCount){
            selected = new ArrayList<>(selected.subList(0, stopsCount));
        }
        if(selected.size() < stopsCount){
            Set<Integer> selectedIds = new HashSet<>();
            for(Pavilion pavilion : selected){
                selectedIds.add(pavilion.getId());
            }
            for(Pavilion pavilion : rankByReviews(start, candidates, todayReviews, needs)){
                if(selected.size() == stopsCount){
                    break;
                }
                if(selectedIds.add(pavilion.getId())){
                    selected.add(pavilion);
                }
            }
        }
        // from now on today (or from the arrival for a later day), avoiding the expected queues
        LocalTime from = roadmap.getVisitDate().equals(LocalDate.now()) && LocalTime.now().isAfter(roadmap.getArrivalTime())
                ? LocalTime.now() : roadmap.getArrivalTime();
        List<Pavilion> ordered = orderPavilions(start, selected, selected.size(), needs, new PlanClock(roadmap.getVisitDate(), from));

        visitRepository.deleteAll(plannedStops);
        renumberStops(visitedStops);
        saveStops(roadmap, ordered, visitedStops.size());
        roadmapRepository.save(roadmap);
        crowdService.invalidate();

        RoadmapResponse result = toRoadmapResponse(roadmap);
        result.setAiUsed(aiUsed);
        return result;
    }

    // zones with high ratings first, low ratings last, then the nearest
    private List<Pavilion> rankByReviews(Location start, List<Pavilion> candidates, List<Review> reviews, Set<String> needs){
        Map<Integer, Double> ratingSum = new HashMap<>();
        Map<Integer, Integer> ratingCount = new HashMap<>();
        for(Review review : reviews){
            Integer zoneId = review.getPavilion().getZone().getId();
            ratingSum.put(zoneId, ratingSum.getOrDefault(zoneId, 0.0) + review.getRating());
            ratingCount.put(zoneId, ratingCount.getOrDefault(zoneId, 0) + 1);
        }
        Map<Integer, Double> score = new HashMap<>();
        Map<Integer, Double> distance = new HashMap<>();
        for(Pavilion pavilion : candidates){
            Integer zoneId = pavilion.getZone().getId();
            // a zone without reviews counts as neutral (3)
            score.put(pavilion.getId(), ratingCount.containsKey(zoneId) ? ratingSum.get(zoneId) / ratingCount.get(zoneId) : 3.0);
            distance.put(pavilion.getId(), getDistance(start, pavilion.getLocation(), needs));
        }
        List<Pavilion> ranked = new ArrayList<>(candidates);
        ranked.sort((a, b) -> {
            int byScore = Double.compare(score.get(b.getId()), score.get(a.getId()));
            return byScore != 0 ? byScore : Double.compare(distance.get(a.getId()), distance.get(b.getId()));
        });
        return ranked;
    }

    // what the AI needs to replace the remaining stops
    private String buildDynamicPrompt(Visitor visitor, Roadmap roadmap, List<Review> reviews, List<Pavilion> candidates, int stopsCount){
        StringBuilder prompt = new StringBuilder();
        prompt.append("You are the visit planner of Expo 2030 Riyadh. The visitor is at the expo now and reviewed the pavilions visited today. ");
        prompt.append("Choose exactly ").append(stopsCount).append(" pavilions for the rest of the day.\n\n");

        prompt.append("VISITOR\n");
        prompt.append("age: ").append(visitor.getAge()).append(", gender: ").append(visitor.getGender())
                .append(", language: ").append(visitor.getPreferredLanguage()).append("\n");
        List<String> interests = new ArrayList<>();
        if(visitor.getInterests() != null){
            for(Interest interest : visitor.getInterests()){
                interests.add(interest.getName());
            }
        }
        if(roadmap.getExtraInterests() != null){
            for(Interest interest : roadmap.getExtraInterests()){
                interests.add(interest.getName());
            }
        }
        prompt.append("interests: ").append(interests).append("\n");
        prompt.append("party: ").append(roadmap.getPartyType()).append(", size: ").append(roadmap.getPartySize())
                .append(", mood: ").append(roadmap.getExperienceTypes()).append(", pace: ").append(roadmap.getVisitPace()).append("\n");
        prompt.append(accessibilityLine(roadmap)).append("\n");

        prompt.append("TODAY REVIEWS (rating 1-5)\n");
        for(Review review : reviews){
            prompt.append("- ").append(review.getPavilion().getName()).append(" (").append(review.getPavilion().getZone().getName())
                    .append("): ").append(review.getRating());
            if(review.getComment() != null){
                prompt.append(" \"").append(review.getComment()).append("\"");
            }
            prompt.append("\n");
        }

        appendPavilions(prompt, candidates, roadmap);

        prompt.append("\nRULES\n");
        prompt.append("- Choose only ids from the list above.\n");
        prompt.append(accessibilityRules(roadmap));
        prompt.append("- Choose more of what was rated high today and avoid what is similar to what was rated low.\n");
        prompt.append("- Do not order the pavilions by distance, the system does that.\n");
        prompt.append("- Write the summary in Arabic if language is AR, otherwise in English, and mention why the plan changed.\n\n");

        prompt.append("Answer with JSON only in this shape:\n");
        prompt.append("{\"pavilionIds\": [1, 2], \"summary\": \"one or two sentences about the new plan\"}");
        return prompt.toString();
    }

    // saves the stops with order 1, 2, 3...
    private void renumberStops(List<Visit> stops){
        int order = 0;
        for(Visit stop : stops){
            stop.setStopOrder(++order);
            visitRepository.save(stop);
        }
    }

    /*
    public void updateRoadmap(Integer id, Roadmap roadmap){
        Roadmap oldRoadmap = roadmapRepository.findRoadmapById(id);
        if(oldRoadmap == null){
            throw new ApiException("roadmap not found");
        }
        checkDateAndTime(roadmap);
        Roadmap sameDayRoadmap = roadmapRepository.findRoadmapByVisitorAndVisitDate(oldRoadmap.getVisitor(), roadmap.getVisitDate());
        if(sameDayRoadmap != null && !sameDayRoadmap.getId().equals(id)){
            throw new ApiException("you already have a roadmap for this day");
        }
        copyAnswers(roadmap, oldRoadmap);
        roadmapRepository.save(oldRoadmap);
    }
    */

    public void deleteRoadmap(Integer visitorId, Integer id){
        Roadmap roadmap = getVisitorRoadmap(visitorId, id);
        // planned stops are deleted, visited ones stay in the passport without the roadmap
        for(Visit visit : visitRepository.findVisitsByRoadmapOrderByStopOrderAsc(roadmap)){
            if(visit.getIsVisited()){
                visit.setRoadmap(null);
                visit.setStopOrder(null);
                visitRepository.save(visit);
            }else{
                visitRepository.delete(visit);
            }
        }
        roadmap.setVisits(null);
        roadmapRepository.delete(roadmap);
    }

    // removes pavilions visited today, and visited before if revisits are not allowed
    private List<Pavilion> selectPavilions(Visitor visitor, Roadmap roadmap, Set<Integer> visitedToday){
        Set<Integer> excluded = new HashSet<>();
        if(visitor.getPassport() != null){
            for(Visit visit : visitRepository.findVisitsByPassportAndIsVisitedTrue(visitor.getPassport())){
                Integer pavilionId = visit.getPavilion().getId();
                boolean today = visit.getVisitedAt() != null && visit.getVisitedAt().toLocalDate().equals(roadmap.getVisitDate());
                if(today){
                    visitedToday.add(pavilionId);
                    excluded.add(pavilionId);
                }else if(!roadmap.getAllowRevisits()){
                    excluded.add(pavilionId);
                }
            }
        }
        // the trip needs: no pavilion that cannot serve them, and with a mobility need only pavilions reachable without stairs
        Set<String> needs = roadmap.getAccessibilityNeeds();
        Set<Integer> stepFreeReachable = AccessibilityService.needsStepFree(needs) ? pathService.getStepFreeReachableLocations() : null;
        List<Pavilion> candidates = new ArrayList<>();
        for(Pavilion pavilion : pavilionRepository.findAll()){
            if(excluded.contains(pavilion.getId()) || pavilion.getLocation() == null || pavilion.getZone() == null){
                continue;
            }
            if(!accessibilityService.isSuitable(pavilion, needs)){
                continue;
            }
            if(stepFreeReachable != null && !stepFreeReachable.contains(pavilion.getLocation().getId())){
                continue;
            }
            candidates.add(pavilion);
        }
        if(candidates.isEmpty() && needs != null && !needs.isEmpty()){
            throw new ApiException("no pavilions fit the accessibility needs of this trip today");
        }
        return candidates;
    }

    // starts from the nearest zone, finishes it, then moves to the nearest next zone
    // the clock follows the walk and the visits, so each pavilion is checked at the time the visitor gets there
    private List<Pavilion> orderPavilions(Location start, List<Pavilion> candidates, int maxStops, Set<String> needs, PlanClock clock){
        List<Pavilion> ordered = new ArrayList<>();
        List<Pavilion> remaining = new ArrayList<>(candidates);
        Location current = start;
        Zone currentZone = null;
        boolean mobility = AccessibilityService.needsStepFree(needs);

        while(ordered.size() < maxStops && !remaining.isEmpty()){
            List<Pavilion> options = pavilionsInZone(remaining, currentZone);
            if(options.isEmpty()){
                currentZone = nearestZone(current, remaining, needs);
                options = pavilionsInZone(remaining, currentZone);
            }
            Pavilion next = nearestPavilion(current, options, needs, clock);
            if(clock != null){
                int walk = CrowdService.walkMinutesFor(getDistance(current, next.getLocation(), needs));
                int queue = crowdService.waitMinutes(next, clock.date(), addMinutes(clock.time(), walk));
                clock = new PlanClock(clock.date(), addMinutes(clock.time(), walk + queue + CrowdService.visitMinutes(next, mobility)));
            }
            ordered.add(next);
            remaining.remove(next);
            current = next.getLocation();
        }
        return ordered;
    }

    // after midnight stays at 23:59
    private LocalTime addMinutes(LocalTime time, int minutes){
        LocalTime result = time.plusMinutes(minutes);
        return result.isBefore(time) ? LocalTime.of(23, 59) : result;
    }

    private List<Pavilion> pavilionsInZone(List<Pavilion> pavilions, Zone zone){
        List<Pavilion> result = new ArrayList<>();
        if(zone == null){
            return result;
        }
        for(Pavilion pavilion : pavilions){
            if(pavilion.getZone().getId().equals(zone.getId())){
                result.add(pavilion);
            }
        }
        return result;
    }

    // zone distance is measured to its center, or to its first pavilion if it has no location
    private Zone nearestZone(Location from, List<Pavilion> pavilions, Set<String> needs){
        Zone nearest = null;
        double best = Double.MAX_VALUE;
        Set<Integer> checked = new HashSet<>();
        for(Pavilion pavilion : pavilions){
            Zone zone = pavilion.getZone();
            if(!checked.add(zone.getId())){
                continue;
            }
            Location target = zone.getLocation() != null ? zone.getLocation() : pavilion.getLocation();
            double distance = getDistance(from, target, needs);
            if(distance < best){
                best = distance;
                nearest = zone;
            }
        }
        return nearest;
    }

    // walk + expected queue when the visitor gets there (a queue minute counts like a walking minute)
    private Pavilion nearestPavilion(Location from, List<Pavilion> pavilions, Set<String> needs, PlanClock clock){
        Pavilion nearest = null;
        double best = Double.MAX_VALUE;
        for(Pavilion pavilion : pavilions){
            double distance = getDistance(from, pavilion.getLocation(), needs);
            if(clock != null){
                LocalTime arrival = addMinutes(clock.time(), CrowdService.walkMinutesFor(distance));
                distance = distance + crowdService.waitMinutes(pavilion, clock.date(), arrival) * UNITS_PER_QUEUE_MINUTE;
            }
            if(distance < best){
                best = distance;
                nearest = pavilion;
            }
        }
        return nearest;
    }

    // walking distance from Dijkstra, straight line if there is no path yet
    private double getDistance(Location from, Location to, Set<String> needs){
        try{
            return pathService.getShortestPath(from.getId(), to.getId(), needs).getTotalDistance();
        }catch(ApiException e){
            // no step free way: the normal path counts 50% longer so it comes last
            if(AccessibilityService.needsStepFree(needs)){
                try{
                    return pathService.getShortestPath(from.getId(), to.getId()).getTotalDistance() * 1.5;
                }catch(ApiException noPath){
                    // straight line below
                }
            }
            return Math.sqrt(Math.pow(to.getX() - from.getX(), 2) + Math.pow(to.getY() - from.getY(), 2));
        }
    }

    private void saveStops(Roadmap roadmap, List<Pavilion> pavilions, int lastOrder){
        int order = lastOrder;
        for(Pavilion pavilion : pavilions){
            Visit stop = new Visit();
            stop.setRoadmap(roadmap);
            stop.setPavilion(pavilion);
            stop.setStopOrder(++order);
            stop.setIsVisited(false);
            visitRepository.save(stop);
        }
    }

    private void copyAnswers(Roadmap from, Roadmap to){
        to.setVisitDate(from.getVisitDate());
        to.setPartyType(from.getPartyType());
        to.setPartySize(from.getPartySize());
        to.setArrivalTime(from.getArrivalTime());
        to.setDepartureTime(from.getDepartureTime());
        to.setExperienceTypes(from.getExperienceTypes());
        to.setVisitPace(from.getVisitPace());
        to.setIncludePrayerBreaks(from.getIncludePrayerBreaks());
        to.setIncludeMealBreaks(from.getIncludeMealBreaks());
        to.setIncludeChildRestBreaks(from.getIncludeChildRestBreaks());
        to.setAllowRevisits(from.getAllowRevisits());
        to.setAccessibilityNeeds(from.getAccessibilityNeeds());
        to.setWhatsappAlerts(from.getWhatsappAlerts());
    }

    // tries every entrance and keeps the one with the shortest walk through the pavilions
    private Entrance bestEntrance(List<Pavilion> pavilions, int maxStops, Set<String> needs, PlanClock clock){
        Entrance best = null;
        double bestDistance = Double.MAX_VALUE;
        for(Entrance entrance : entranceRepository.findAll()){
            if(entrance.getLocation() == null){
                continue;
            }
            List<Pavilion> ordered = orderPavilions(entrance.getLocation(), pavilions, maxStops, needs, clock);
            double distance = 0;
            Location current = entrance.getLocation();
            for(Pavilion pavilion : ordered){
                distance += getDistance(current, pavilion.getLocation(), needs);
                current = pavilion.getLocation();
            }
            if(distance < bestDistance){
                bestDistance = distance;
                best = entrance;
            }
        }
        if(best == null){
            throw new ApiException("no entrance found");
        }
        return best;
    }

    // the visitor changes the entrance before starting the roadmap, the stops are ordered again from it
    public RoadmapResponse changeEntrance(Integer visitorId, Integer roadmapId, Integer entranceId){
        Roadmap roadmap = getVisitorRoadmap(visitorId, roadmapId);
        checkNotPast(roadmap);
        checkNotLocked(roadmap);
        Entrance entrance = entranceRepository.findEntranceById(entranceId);
        if(entrance == null || entrance.getLocation() == null){
            throw new ApiException("entrance not found");
        }
        List<Visit> stops = visitRepository.findVisitsByRoadmapOrderByStopOrderAsc(roadmap);
        Map<Integer, Visit> stopByPavilion = new HashMap<>();
        List<Pavilion> pavilions = new ArrayList<>();
        for(Visit stop : stops){
            if(stop.getIsVisited()){
                throw new ApiException("you cannot change the entrance after starting the roadmap");
            }
            stopByPavilion.put(stop.getPavilion().getId(), stop);
            pavilions.add(stop.getPavilion());
        }
        // a trip with a mobility need must reach every stop from this entrance without stairs
        Set<String> needs = roadmap.getAccessibilityNeeds();
        if(AccessibilityService.needsStepFree(needs)){
            for(Pavilion pavilion : pavilions){
                try{
                    pathService.getAccessibleShortestPath(entrance.getLocation().getId(), pavilion.getLocation().getId());
                }catch(ApiException e){
                    throw new ApiException("this entrance has no step free path to " + pavilion.getName());
                }
            }
        }
        roadmap.setEntrance(entrance);
        roadmapRepository.save(roadmap);
        List<Visit> reordered = new ArrayList<>();
        for(Pavilion pavilion : orderPavilions(entrance.getLocation(), pavilions, pavilions.size(), needs,
                new PlanClock(roadmap.getVisitDate(), roadmap.getArrivalTime()))){
            reordered.add(stopByPavilion.get(pavilion.getId()));
        }
        renumberStops(reordered);
        return toRoadmapResponse(roadmap);
    }

    // AI failed: fully accessible pavilions first, partly accessible ones only if there are not enough
    private List<Pavilion> preferFullyAccessible(List<Pavilion> candidates, Set<String> needs, int maxStops){
        if(needs == null || needs.isEmpty()){
            return candidates;
        }
        List<Pavilion> full = new ArrayList<>();
        for(Pavilion pavilion : candidates){
            if(accessibilityService.isFullyAccessible(pavilion, needs)){
                full.add(pavilion);
            }
        }
        return full.size() >= maxStops ? full : candidates;
    }

    // the needs of the trip in the prompt
    private String accessibilityLine(Roadmap roadmap){
        Set<String> needs = roadmap.getAccessibilityNeeds();
        if(needs == null || needs.isEmpty()){
            return "accessibility needs in the party: none\n";
        }
        return "accessibility needs in the party: " + needs + "\n";
    }

    private String accessibilityRules(Roadmap roadmap){
        Set<String> needs = roadmap.getAccessibilityNeeds();
        if(needs == null || needs.isEmpty()){
            return "";
        }
        StringBuilder rules = new StringBuilder();
        rules.append("- Someone in the party has these needs: ").append(needs).append(". Prefer pavilions that are ACCESSIBLE for all of them, use PARTIAL ones only when they match the interests much better.\n");
        if(needs.contains("LIMITED_MOBILITY") || needs.contains("STROLLER_ELDERLY") || needs.contains("WHEELCHAIR")){
            rules.append("- The party moves slowly: choose fewer pavilions and add a short rest break every 90 minutes (type MEAL or CHILD_REST is fine, explain it in the note).\n");
        }
        if(needs.contains("SENSORY")){
            rules.append("- Avoid putting loud or crowded pavilions one after another.\n");
        }
        rules.append("- Mention the accessibility in the summary in one short sentence.\n");
        return rules.toString();
    }

    // pavilion lines for the prompt, with the accessibility for the trip needs
    private void appendPavilions(StringBuilder prompt, List<Pavilion> candidates, Roadmap roadmap){
        Set<String> needs = roadmap.getAccessibilityNeeds();
        boolean withNeeds = needs != null && !needs.isEmpty();
        prompt.append("\nAVAILABLE PAVILIONS (id | name | country | zone | ").append(withNeeds ? "accessibility | " : "").append("description)\n");
        for(Pavilion pavilion : candidates){
            String description = pavilion.getDescription() == null ? "" : pavilion.getDescription();
            if(description.length() > 200){
                description = description.substring(0, 200);
            }
            prompt.append(pavilion.getId()).append(" | ").append(pavilion.getName()).append(" | ")
                    .append(pavilion.getCountry()).append(" | ").append(pavilion.getZone().getName()).append(" | ");
            if(withNeeds){
                prompt.append(accessibilityService.describe(pavilion, needs)).append(" | ");
            }
            prompt.append(description).append("\n");
        }
    }

    // the visitor accepted a crowd alert: the pavilion becomes the next stop, right after the visited ones
    public RoadmapResponse acceptCrowdAlert(Integer visitorId, Integer alertId){
        CrowdAlert alert = crowdAlertRepository.findCrowdAlertById(alertId);
        if(alert == null || !alert.getVisitorId().equals(visitorId)){
            throw new ApiException("alert not found");
        }
        if(Boolean.TRUE.equals(alert.getAccepted())){
            throw new ApiException("this alert is already accepted");
        }
        Roadmap roadmap = getVisitorRoadmap(visitorId, alert.getRoadmapId());
        checkNotLocked(roadmap);
        if(!roadmap.getVisitDate().equals(LocalDate.now())){
            throw new ApiException("this alert is not for today");
        }
        List<Visit> stops = visitRepository.findVisitsByRoadmapOrderByStopOrderAsc(roadmap);
        Visit target = null;
        for(Visit stop : stops){
            if(stop.getPavilion().getId().equals(alert.getPavilionId())){
                target = stop;
            }
        }
        if(target == null){
            throw new ApiException("the pavilion is not in this roadmap anymore");
        }
        if(target.getIsVisited()){
            throw new ApiException("you already visited this pavilion");
        }
        stops.remove(target);
        int lastVisitedIndex = -1;
        for(int i = 0; i < stops.size(); i++){
            if(stops.get(i).getIsVisited()){
                lastVisitedIndex = i;
            }
        }
        stops.add(lastVisitedIndex + 1, target);
        renumberStops(stops);

        alert.setAccepted(true);
        alert.setAcceptedAt(LocalDateTime.now());
        crowdAlertRepository.save(alert);
        crowdService.invalidate();
        return toRoadmapResponse(roadmap);
    }

    // the roadmap must belong to the logged in visitor
    private Roadmap getVisitorRoadmap(Integer visitorId, Integer roadmapId){
        Roadmap roadmap = roadmapRepository.findRoadmapById(roadmapId);
        if(roadmap == null || !roadmap.getVisitor().getId().equals(visitorId)){
            throw new ApiException("roadmap not found");
        }
        return roadmap;
    }

    // a roadmap of a past day cannot be edited
    private void checkNotPast(Roadmap roadmap){
        if(roadmap.getVisitDate().isBefore(LocalDate.now())){
            throw new ApiException("you cannot edit a roadmap of a past day");
        }
    }

    // a confirmed roadmap is fixed, its stops and entrance cannot change (sharing, deleting and check-in still work)
    private void checkNotLocked(Roadmap roadmap){
        if(roadmap.getLockedAt() != null){
            throw new ApiException("this roadmap is confirmed and cannot be edited");
        }
    }

    // date must be in expo period, departure after arrival
    private void checkDateAndTime(Roadmap roadmap){
        // test period with the same days as the real expo (2030-10-01 to 2031-03-31)
        if(roadmap.getVisitDate().isBefore(LocalDate.of(2026, 10, 1)) || roadmap.getVisitDate().isAfter(LocalDate.of(2027, 3, 31))){
            throw new ApiException("visit date must be between 2026-10-01 and 2027-03-31");
        }
        if(!roadmap.getDepartureTime().isAfter(roadmap.getArrivalTime())){
            throw new ApiException("departure time must be after arrival time");
        }
    }
}

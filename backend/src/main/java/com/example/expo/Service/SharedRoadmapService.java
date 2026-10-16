package com.example.expo.Service;

import com.example.expo.Api.ApiException;
import com.example.expo.Dto.In.ShareRoadmapRequest;
import com.example.expo.Dto.Out.InterestResponse;
import com.example.expo.Dto.Out.RoadmapResponse;
import com.example.expo.Dto.Out.SharedRoadmapResponse;
import com.example.expo.Dto.Out.SharedStopResponse;
import com.example.expo.Model.Interest;
import com.example.expo.Model.Pavilion;
import com.example.expo.Model.Roadmap;
import com.example.expo.Model.User;
import com.example.expo.Model.Visit;
import com.example.expo.Model.Visitor;
import com.example.expo.Repository.RoadmapRepository;
import com.example.expo.Repository.VisitRepository;
import com.example.expo.Repository.VisitorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class SharedRoadmapService {
    private final RoadmapRepository roadmapRepository;
    private final VisitorRepository visitorRepository;
    private final VisitRepository visitRepository;
    private final CrowdService crowdService;
    private final RoadmapService roadmapService;

    // the newest shared roadmaps of one day that are sorted by common interests, the page is cut after sorting
    private static final int FETCH_LIMIT = 200;
    private static final int MAX_PAGE_SIZE = 50;

    private record Scored(Roadmap roadmap, int common){}

    // publishes the roadmap, or updates the share settings if it is already published
    public void shareRoadmap(Integer visitorId, Integer roadmapId, ShareRoadmapRequest request){
        Roadmap roadmap = getOwnRoadmap(visitorId, roadmapId);
        if(roadmap.getVisitDate().isBefore(LocalDate.now())){
            throw new ApiException("you cannot share a roadmap of a past day");
        }
        if(visitRepository.findVisitsByRoadmapOrderByStopOrderAsc(roadmap).isEmpty()){
            throw new ApiException("you cannot share a roadmap without stops");
        }
        if(visitRepository.existsByRoadmapAndIsVisitedTrue(roadmap)){
            throw new ApiException("you cannot share a roadmap that already started");
        }
        String phone = roadmap.getVisitor().getUser().getPhone();
        if(request.getShowContact() && (phone == null || phone.isBlank())){
            throw new ApiException("no phone number in your account");
        }
        String note = request.getShareNote() == null ? null : request.getShareNote().trim();
        roadmap.setShareNote(note == null || note.isEmpty() ? null : note);
        roadmap.setShowContact(request.getShowContact());
        roadmap.setShareAudience(request.getAudience());
        if(!Boolean.TRUE.equals(roadmap.getIsShared())){
            roadmap.setIsShared(true);
            roadmap.setSharedAt(LocalDateTime.now());
        }
        roadmapRepository.save(roadmap);
    }

    // always allowed, even for a confirmed or a past roadmap, the owner can stop sharing any time
    public void unshareRoadmap(Integer visitorId, Integer roadmapId){
        Roadmap roadmap = getOwnRoadmap(visitorId, roadmapId);
        roadmap.setIsShared(false);
        roadmap.setShowContact(false);
        roadmap.setSharedAt(null);
        roadmapRepository.save(roadmap);
    }

    // the owner confirms the roadmap: from now on its stops are fixed (every edit is refused in RoadmapService)
    public void confirmRoadmap(Integer visitorId, Integer roadmapId){
        Roadmap roadmap = getOwnRoadmap(visitorId, roadmapId);
        if(roadmap.getVisitDate().isBefore(LocalDate.now())){
            throw new ApiException("you cannot confirm a roadmap of a past day");
        }
        if(roadmap.getLockedAt() != null){
            throw new ApiException("this roadmap is already confirmed");
        }
        roadmap.setLockedAt(LocalDateTime.now());
        roadmapRepository.save(roadmap);
    }

    // shared roadmaps of one day for this viewer, the most common interests first
    public List<SharedRoadmapResponse> getShared(Integer visitorId, LocalDate date, int page, int size){
        Visitor viewer = visitorRepository.findVisitorById(visitorId);
        if(viewer == null){
            throw new ApiException("visitor not found");
        }
        int pageNumber = Math.max(page, 0);
        int pageSize = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);

        Set<Integer> viewerInterests = new HashSet<>();
        if(viewer.getInterests() != null){
            for(Interest interest : viewer.getInterests()){
                viewerInterests.add(interest.getId());
            }
        }
        List<Scored> scored = new ArrayList<>();
        for(Roadmap roadmap : roadmapRepository.findSharedForViewer(date, visitorId, viewer.getGender(), PageRequest.of(0, FETCH_LIMIT))){
            int common = 0;
            if(roadmap.getVisitor().getInterests() != null){
                for(Interest interest : roadmap.getVisitor().getInterests()){
                    if(viewerInterests.contains(interest.getId())){
                        common++;
                    }
                }
            }
            scored.add(new Scored(roadmap, common));
        }
        // common interests, then the most copied, then the newest
        scored.sort((a, b) -> {
            if(a.common() != b.common()){
                return Integer.compare(b.common(), a.common());
            }
            int copiesA = a.roadmap().getCopyCount() == null ? 0 : a.roadmap().getCopyCount();
            int copiesB = b.roadmap().getCopyCount() == null ? 0 : b.roadmap().getCopyCount();
            if(copiesA != copiesB){
                return Integer.compare(copiesB, copiesA);
            }
            LocalDateTime sharedA = a.roadmap().getSharedAt();
            LocalDateTime sharedB = b.roadmap().getSharedAt();
            if(sharedA == null || sharedB == null){
                return sharedA == null ? (sharedB == null ? 0 : 1) : -1;
            }
            return sharedB.compareTo(sharedA);
        });

        List<SharedRoadmapResponse> result = new ArrayList<>();
        int from = pageNumber * pageSize;
        for(int i = from; i < Math.min(from + pageSize, scored.size()); i++){
            result.add(toSharedResponse(scored.get(i).roadmap(), scored.get(i).common()));
        }
        return result;
    }

    // copies a shared plan's stops into a NEW roadmap for the viewer and returns the saved entity.
    // used when a join request is accepted (locked = true, only the founder edits the original).
    @Transactional
    public Roadmap copyInto(Visitor viewer, Roadmap source, boolean locked){
        // one roadmap per visitor per day
        if(roadmapRepository.findRoadmapByVisitorAndVisitDate(viewer, source.getVisitDate()) != null){
            throw new ApiException("you already have a plan for this day, delete it first to join this group");
        }
        Roadmap copy = new Roadmap();
        copy.setVisitDate(source.getVisitDate());
        copy.setPartyType(source.getPartyType());
        copy.setPartySize(source.getPartySize());
        copy.setArrivalTime(source.getArrivalTime());
        copy.setDepartureTime(source.getDepartureTime());
        copy.setExperienceTypes(source.getExperienceTypes() == null ? new HashSet<>() : new HashSet<>(source.getExperienceTypes()));
        copy.setVisitPace(source.getVisitPace());
        copy.setIncludePrayerBreaks(source.getIncludePrayerBreaks());
        copy.setIncludeMealBreaks(source.getIncludeMealBreaks());
        copy.setIncludeChildRestBreaks(source.getIncludeChildRestBreaks());
        copy.setAllowRevisits(source.getAllowRevisits());
        copy.setExtraInterests(source.getExtraInterests() == null ? new HashSet<>() : new HashSet<>(source.getExtraInterests()));
        copy.setEntrance(source.getEntrance());
        // the needs and the WhatsApp alerts of the owner are not the needs of the one who joins
        copy.setAccessibilityNeeds(new HashSet<>());
        copy.setWhatsappAlerts(false);
        copy.setVisitor(viewer);
        copy.setCreatedAt(LocalDateTime.now());
        copy.setCopiedFromId(source.getId());
        // a member's copy is locked: only the founder edits the original plan
        if(locked){
            copy.setLockedAt(LocalDateTime.now());
        }
        roadmapRepository.save(copy);

        int order = 0;
        for(Visit stop : visitRepository.findVisitsByRoadmapOrderByStopOrderAsc(source)){
            Visit newStop = new Visit();
            newStop.setRoadmap(copy);
            newStop.setPavilion(stop.getPavilion());
            newStop.setStopOrder(++order);
            newStop.setIsVisited(false);
            visitRepository.save(newStop);
        }
        roadmapRepository.increaseCopyCount(source.getId());
        crowdService.invalidate();
        return copy;
    }

    private SharedRoadmapResponse toSharedResponse(Roadmap roadmap, int common){ // only what the owner agreed to show, the phone only when he turned it on
        Visitor owner = roadmap.getVisitor();
        User user = owner.getUser();
        String firstName = user.getFullName().trim().split("\\s+")[0];

        List<InterestResponse> interests = new ArrayList<>();
        if(owner.getInterests() != null){
            for(Interest interest : owner.getInterests()){
                interests.add(new InterestResponse(interest.getId(), interest.getName(), interest.getNameAr()));
            }
        }
        List<SharedStopResponse> stops = new ArrayList<>();
        for(Visit visit : visitRepository.findVisitsByRoadmapOrderByStopOrderAsc(roadmap)){
            Pavilion pavilion = visit.getPavilion();
            stops.add(new SharedStopResponse(visit.getStopOrder(), pavilion.getId(), pavilion.getName(),
                    pavilion.getZone() == null ? null : pavilion.getZone().getName(), pavilion.getImageUrl()));
        }
        String phone = Boolean.TRUE.equals(roadmap.getShowContact()) ? user.getPhone() : null;
        return new SharedRoadmapResponse(roadmap.getId(), roadmap.getVisitDate(), roadmap.getArrivalTime(), roadmap.getDepartureTime(),
                roadmap.getVisitPace(), firstName, owner.getNationality(), interests, common, roadmap.getShareNote(),
                roadmap.getEntrance() == null ? null : roadmap.getEntrance().getName(), stops,
                roadmap.getCopyCount() == null ? 0 : roadmap.getCopyCount(), roadmap.getLockedAt() != null, phone);
    }

    // the roadmap must belong to the logged in visitor
    private Roadmap getOwnRoadmap(Integer visitorId, Integer roadmapId){
        Roadmap roadmap = roadmapRepository.findRoadmapById(roadmapId);
        if(roadmap == null || !roadmap.getVisitor().getId().equals(visitorId)){
            throw new ApiException("roadmap not found");
        }
        return roadmap;
    }
}

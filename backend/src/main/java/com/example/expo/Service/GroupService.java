package com.example.expo.Service;

import com.example.expo.Api.ApiException;
import com.example.expo.Dto.In.JoinRequestBody;
import com.example.expo.Dto.Out.GroupMemberResponse;
import com.example.expo.Dto.Out.GroupResponse;
import com.example.expo.Dto.Out.InterestResponse;
import com.example.expo.Dto.Out.JoinRequestResponse;
import com.example.expo.Dto.Out.MyJoinRequestResponse;
import com.example.expo.Dto.Out.SharedStopResponse;
import com.example.expo.Model.Interest;
import com.example.expo.Model.JoinRequest;
import com.example.expo.Model.Pavilion;
import com.example.expo.Model.Roadmap;
import com.example.expo.Model.User;
import com.example.expo.Model.Visit;
import com.example.expo.Model.Visitor;
import com.example.expo.Repository.JoinRequestRepository;
import com.example.expo.Repository.RoadmapRepository;
import com.example.expo.Repository.VisitRepository;
import com.example.expo.Repository.VisitorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

// "Find a group" membership: a visitor requests to join a shared plan, the founder accepts or rejects,
// and on accept the member gets a locked copy of the plan. Max group size (founder + members) is 5.
@Service
@RequiredArgsConstructor
public class GroupService {
    private final JoinRequestRepository joinRequestRepository;
    private final RoadmapRepository roadmapRepository;
    private final VisitorRepository visitorRepository;
    private final VisitRepository visitRepository;
    private final SharedRoadmapService sharedRoadmapService;
    private final RoadmapService roadmapService;

    private static final int CAPACITY = 5;                 // founder + accepted members
    private static final int MAX_MEMBERS = CAPACITY - 1;   // accepted members (the founder is the 5th seat)
    private static final List<String> ACTIVE = List.of("PENDING", "ACCEPTED");

    // ===== requester side =====

    // sends a join request to a shared plan
    public MyJoinRequestResponse requestJoin(Integer visitorId, Integer roadmapId, JoinRequestBody body){
        Visitor requester = visitorRepository.findVisitorById(visitorId);
        if(requester == null){
            throw new ApiException("visitor not found");
        }
        Roadmap source = roadmapRepository.findRoadmapById(roadmapId);
        // not shared, or SAME_GENDER and a different gender: the same answer, the plan is simply not visible
        if(source == null || !Boolean.TRUE.equals(source.getIsShared())
                || ("SAME_GENDER".equals(source.getShareAudience()) && !source.getVisitor().getGender().equals(requester.getGender()))){
            throw new ApiException("shared plan not found");
        }
        if(source.getVisitor().getId().equals(visitorId)){
            throw new ApiException("you cannot join your own plan");
        }
        if(source.getVisitDate().isBefore(LocalDate.now())){
            throw new ApiException("you cannot join a plan of a past day");
        }
        if(visitRepository.existsByRoadmapAndIsVisitedTrue(source)){
            throw new ApiException("this plan has already started");
        }
        if(joinRequestRepository.countByRoadmapAndStatus(source, "ACCEPTED") >= MAX_MEMBERS){
            throw new ApiException("this group is full");
        }
        if(joinRequestRepository.existsByRoadmapAndRequesterAndStatusIn(source, requester, ACTIVE)){
            throw new ApiException("you already have a request for this plan");
        }
        if(roadmapRepository.findRoadmapByVisitorAndVisitDate(requester, source.getVisitDate()) != null){
            throw new ApiException("you already have a plan for this day, delete it first to join this group");
        }

        JoinRequest request = new JoinRequest();
        request.setRoadmap(source);
        request.setRequester(requester);
        request.setStatus("PENDING");
        request.setMessage(body == null || body.getMessage() == null || body.getMessage().isBlank() ? null : body.getMessage().trim());
        request.setCreatedAt(LocalDateTime.now());
        joinRequestRepository.save(request);
        return toMyRequest(request);
    }

    // the requester cancels his own pending request
    public void withdraw(Integer visitorId, Integer requestId){
        JoinRequest request = joinRequestRepository.findJoinRequestById(requestId);
        if(request == null || !request.getRequester().getId().equals(visitorId)){
            throw new ApiException("request not found");
        }
        if(!"PENDING".equals(request.getStatus())){
            throw new ApiException("only a pending request can be withdrawn");
        }
        request.setStatus("WITHDRAWN");
        request.setDecidedAt(LocalDateTime.now());
        joinRequestRepository.save(request);
    }

    // the requester's own outgoing requests and their status
    public List<MyJoinRequestResponse> myRequests(Integer visitorId){
        Visitor requester = visitorRepository.findVisitorById(visitorId);
        if(requester == null){
            throw new ApiException("visitor not found");
        }
        List<MyJoinRequestResponse> result = new ArrayList<>();
        for(JoinRequest request : joinRequestRepository.findByRequesterOrderByCreatedAtDesc(requester)){
            result.add(toMyRequest(request));
        }
        return result;
    }

    // a member leaves a group he joined: his locked copy is removed from his journey
    @Transactional
    public void leave(Integer visitorId, Integer roadmapId){
        Visitor visitor = visitorRepository.findVisitorById(visitorId);
        if(visitor == null){
            throw new ApiException("visitor not found");
        }
        Roadmap source = roadmapRepository.findRoadmapById(roadmapId);
        if(source == null){
            throw new ApiException("group not found");
        }
        JoinRequest membership = joinRequestRepository.findByRoadmapAndRequesterAndStatus(source, visitor, "ACCEPTED");
        if(membership == null){
            throw new ApiException("you are not a member of this group");
        }
        membership.setStatus("WITHDRAWN");
        membership.setDecidedAt(LocalDateTime.now());
        joinRequestRepository.save(membership);
        if(membership.getMemberRoadmapId() != null){
            try{
                roadmapService.deleteRoadmap(visitorId, membership.getMemberRoadmapId());
            }catch(ApiException ignored){
                // the member may have already deleted the copy himself
            }
        }
    }

    // ===== founder side =====

    // the join requests for the founder's plan, newest first
    public List<JoinRequestResponse> requestsForRoadmap(Integer founderId, Integer roadmapId){
        Roadmap roadmap = ownRoadmap(founderId, roadmapId);
        Set<Integer> founderInterests = interestIds(roadmap.getVisitor());
        List<JoinRequestResponse> result = new ArrayList<>();
        for(JoinRequest request : joinRequestRepository.findByRoadmapOrderByCreatedAtDesc(roadmap)){
            result.add(toFounderRequest(request, founderInterests));
        }
        return result;
    }

    // the founder accepts a pending request: a locked copy of the plan is created for the member
    @Transactional
    public void accept(Integer founderId, Integer requestId){
        JoinRequest request = joinRequestRepository.findJoinRequestById(requestId);
        if(request == null || !request.getRoadmap().getVisitor().getId().equals(founderId)){
            throw new ApiException("request not found");
        }
        if(!"PENDING".equals(request.getStatus())){
            throw new ApiException("this request is already decided");
        }
        Roadmap roadmap = request.getRoadmap();
        if(roadmap.getVisitDate().isBefore(LocalDate.now())){
            throw new ApiException("you cannot accept for a past day");
        }
        if(visitRepository.existsByRoadmapAndIsVisitedTrue(roadmap)){
            throw new ApiException("this plan has already started");
        }
        if(joinRequestRepository.countByRoadmapAndStatus(roadmap, "ACCEPTED") >= MAX_MEMBERS){
            throw new ApiException("this group is full");
        }
        // create the member's own locked copy (one plan per day is enforced inside copyInto)
        Roadmap memberCopy = sharedRoadmapService.copyInto(request.getRequester(), roadmap, true);
        request.setStatus("ACCEPTED");
        request.setDecidedAt(LocalDateTime.now());
        request.setMemberRoadmapId(memberCopy.getId());
        joinRequestRepository.save(request);
    }

    // the founder rejects a pending request
    public void reject(Integer founderId, Integer requestId){
        JoinRequest request = joinRequestRepository.findJoinRequestById(requestId);
        if(request == null || !request.getRoadmap().getVisitor().getId().equals(founderId)){
            throw new ApiException("request not found");
        }
        if(!"PENDING".equals(request.getStatus())){
            throw new ApiException("this request is already decided");
        }
        request.setStatus("REJECTED");
        request.setDecidedAt(LocalDateTime.now());
        joinRequestRepository.save(request);
    }

    // ===== group view (founder or an accepted member) =====
    public GroupResponse getGroup(Integer visitorId, Integer roadmapId){
        Visitor viewer = visitorRepository.findVisitorById(visitorId);
        if(viewer == null){
            throw new ApiException("visitor not found");
        }
        Roadmap source = roadmapRepository.findRoadmapById(roadmapId);
        if(source == null){
            throw new ApiException("group not found");
        }
        boolean isFounder = source.getVisitor().getId().equals(visitorId);
        boolean isMember = joinRequestRepository.findByRoadmapAndRequesterAndStatus(source, viewer, "ACCEPTED") != null;
        if(!isFounder && !isMember){
            throw new ApiException("you are not in this group");
        }

        List<GroupMemberResponse> members = new ArrayList<>();
        Visitor founder = source.getVisitor();
        members.add(new GroupMemberResponse(firstName(founder), founder.getNationality(), true));
        for(JoinRequest member : joinRequestRepository.findByRoadmapAndStatus(source, "ACCEPTED")){
            Visitor m = member.getRequester();
            members.add(new GroupMemberResponse(firstName(m), m.getNationality(), false));
        }

        List<SharedStopResponse> stops = new ArrayList<>();
        for(Visit visit : visitRepository.findVisitsByRoadmapOrderByStopOrderAsc(source)){
            Pavilion pavilion = visit.getPavilion();
            stops.add(new SharedStopResponse(visit.getStopOrder(), pavilion.getId(), pavilion.getName(),
                    pavilion.getZone() == null ? null : pavilion.getZone().getName(), pavilion.getImageUrl()));
        }

        int memberCount = members.size();
        String founderPhone = null;
        String phone = founder.getUser().getPhone();
        // the founder always sees their own number; members only when the founder turned contact on
        if(phone != null && !phone.isBlank() && (isFounder || Boolean.TRUE.equals(source.getShowContact()))){
            founderPhone = phone;
        }

        return new GroupResponse(source.getId(), firstName(founder), founder.getNationality(),
                source.getVisitDate(), source.getArrivalTime(), source.getDepartureTime(),
                source.getEntrance() == null ? null : source.getEntrance().getName(),
                source.getLockedAt() != null, stops, members, CAPACITY, memberCount,
                memberCount >= CAPACITY, isFounder, founderPhone);
    }

    // ===== helpers =====

    private Roadmap ownRoadmap(Integer founderId, Integer roadmapId){
        Roadmap roadmap = roadmapRepository.findRoadmapById(roadmapId);
        if(roadmap == null || !roadmap.getVisitor().getId().equals(founderId)){
            throw new ApiException("roadmap not found");
        }
        return roadmap;
    }

    private String firstName(Visitor visitor){
        String full = visitor.getUser().getFullName();
        return full == null ? "" : full.trim().split("\\s+")[0];
    }

    private Set<Integer> interestIds(Visitor visitor){
        Set<Integer> ids = new HashSet<>();
        if(visitor.getInterests() != null){
            for(Interest interest : visitor.getInterests()){
                ids.add(interest.getId());
            }
        }
        return ids;
    }

    private int commonInterests(Visitor a, Set<Integer> otherIds){
        int common = 0;
        if(a.getInterests() != null){
            for(Interest interest : a.getInterests()){
                if(otherIds.contains(interest.getId())){
                    common++;
                }
            }
        }
        return common;
    }

    private List<InterestResponse> interests(Visitor visitor){
        List<InterestResponse> list = new ArrayList<>();
        if(visitor.getInterests() != null){
            for(Interest interest : visitor.getInterests()){
                list.add(new InterestResponse(interest.getId(), interest.getName(), interest.getNameAr()));
            }
        }
        return list;
    }

    private JoinRequestResponse toFounderRequest(JoinRequest request, Set<Integer> founderInterests){
        Visitor requester = request.getRequester();
        return new JoinRequestResponse(request.getId(), request.getStatus(), request.getMessage(), request.getCreatedAt(),
                firstName(requester), requester.getNationality(), interests(requester),
                commonInterests(requester, founderInterests));
    }

    private MyJoinRequestResponse toMyRequest(JoinRequest request){
        Roadmap roadmap = request.getRoadmap();
        Visitor owner = roadmap.getVisitor();
        boolean accepted = "ACCEPTED".equals(request.getStatus());
        String ownerPhone = null;
        if(accepted && Boolean.TRUE.equals(roadmap.getShowContact())){
            String phone = owner.getUser().getPhone();
            if(phone != null && !phone.isBlank()){
                ownerPhone = phone;
            }
        }
        int stopsCount = visitRepository.findVisitsByRoadmapOrderByStopOrderAsc(roadmap).size();
        return new MyJoinRequestResponse(request.getId(), request.getStatus(), request.getMessage(),
                roadmap.getId(), firstName(owner), owner.getNationality(), roadmap.getVisitDate(),
                roadmap.getArrivalTime(), roadmap.getDepartureTime(),
                roadmap.getEntrance() == null ? null : roadmap.getEntrance().getName(), stopsCount,
                accepted ? request.getMemberRoadmapId() : null, ownerPhone);
    }
}

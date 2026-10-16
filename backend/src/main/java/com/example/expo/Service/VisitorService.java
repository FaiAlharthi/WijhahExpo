package com.example.expo.Service;

import com.example.expo.Api.ApiException;
import com.example.expo.Dto.In.VisitorRegisterRequest;
import com.example.expo.Dto.Out.InterestResponse;
import com.example.expo.Dto.Out.VisitorResponse;
import com.example.expo.Model.Interest;
import com.example.expo.Model.Passport;
import com.example.expo.Model.User;
import com.example.expo.Model.Roadmap;
import com.example.expo.Model.Visit;
import com.example.expo.Model.Visitor;
import com.example.expo.Repository.InterestRepository;
import com.example.expo.Repository.PassportRepository;
import com.example.expo.Repository.UserRepository;
import com.example.expo.Repository.VisitRepository;
import com.example.expo.Repository.VisitorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

@Service
@RequiredArgsConstructor
public class VisitorService {
    private final VisitorRepository visitorRepository;
    private final UserRepository userRepository;
    private final InterestRepository interestRepository;
    private final PassportRepository passportRepository;
    private final VisitRepository visitRepository;
    private final PasswordEncoder passwordEncoder;

    public List<VisitorResponse> getAllVisitors(){
        List<VisitorResponse> visitors = new ArrayList<>();
        for(Visitor visitor : visitorRepository.findAll()){
            visitors.add(toVisitorResponse(visitor));
        }
        return visitors;
    }

    public VisitorResponse getVisitor(Integer id){
        Visitor visitor = visitorRepository.findVisitorById(id);
        if(visitor == null){
            throw new ApiException("visitor not found");
        }
        return toVisitorResponse(visitor);
    }

    private VisitorResponse toVisitorResponse(Visitor visitor){
        User user = visitor.getUser();
        List<InterestResponse> interests = new ArrayList<>();
        if(visitor.getInterests() != null){
            for(Interest interest : visitor.getInterests()){
                interests.add(new InterestResponse(interest.getId(), interest.getName(), interest.getNameAr()));
            }
            interests.sort(Comparator.comparing(InterestResponse::getId));
        }
        Passport passport = visitor.getPassport();
        return new VisitorResponse(visitor.getId(), user.getFullName(), user.getUsername(), user.getEmail(),
                user.getPhone(), visitor.getAge(), visitor.getGender(), visitor.getPreferredLanguage(), visitor.getNationality(),
                interests, passport == null ? null : passport.getPassportNumber(),
                user.getCreatedAt());
    }

    // creates the user (role VISITOR), the visitor and the passport together
    @Transactional
    public void registerVisitor(VisitorRegisterRequest request){
        if(userRepository.findUserByUsername(request.getUsername()) != null){
            throw new ApiException("username already exists");
        }
        if(userRepository.findUserByEmail(request.getEmail()) != null){
            throw new ApiException("email already exists");
        }
        User user = new User();
        user.setFullName(request.getFullName());
        user.setUsername(request.getUsername());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setEmail(request.getEmail());
        user.setPhone(request.getPhone());
        user.setRole("VISITOR");
        user.setCreatedAt(LocalDateTime.now());
        userRepository.save(user);

        Visitor visitor = new Visitor();
        visitor.setAge(request.getAge());
        visitor.setGender(request.getGender());
        visitor.setPreferredLanguage(request.getPreferredLanguage());
        visitor.setNationality(request.getNationality());
        visitor.setUser(user);
        Visitor savedVisitor = visitorRepository.save(visitor);

        // every new visitor gets a passport
        Passport passport = new Passport();
        passport.setPassportNumber(String.format("EXPO30-%06d", savedVisitor.getId()));
        passport.setVisitor(savedVisitor);
        passportRepository.save(passport);
    }

    public void updateVisitor(Integer id, Visitor visitor){
        Visitor oldVisitor = visitorRepository.findVisitorById(id);
        if(oldVisitor == null){
            throw new ApiException("visitor not found");
        }
        oldVisitor.setAge(visitor.getAge());
        oldVisitor.setGender(visitor.getGender());
        oldVisitor.setPreferredLanguage(visitor.getPreferredLanguage());
        oldVisitor.setNationality(visitor.getNationality());
        visitorRepository.save(oldVisitor);
    }

    public void deleteVisitor(Integer id){
        Visitor visitor = visitorRepository.findVisitorById(id);
        if(visitor == null){
            throw new ApiException("visitor not found");
        }
        clearRoadmapStops(visitor);
        visitor.getUser().setVisitor(null);
        visitorRepository.delete(visitor);
    }

    // before deleting a visitor: planned stops are deleted, visited ones are unlinked
    // from the roadmap so they are deleted with the passport
    public void clearRoadmapStops(Visitor visitor){
        if(visitor.getRoadmaps() == null){
            return;
        }
        for(Roadmap roadmap : visitor.getRoadmaps()){
            for(Visit visit : visitRepository.findVisitsByRoadmapOrderByStopOrderAsc(roadmap)){
                if(visit.getIsVisited()){
                    visit.setRoadmap(null);
                    visitRepository.save(visit);
                }else{
                    visitRepository.delete(visit);
                }
            }
            roadmap.setVisits(null);
        }
    }

    public void removeInterestFromVisitor(Integer visitorId, Integer interestId){
        Visitor visitor = visitorRepository.findVisitorById(visitorId);
        if(visitor == null){
            throw new ApiException("visitor not found");
        }
        Interest interest = interestRepository.findInterestById(interestId);
        if(interest == null){
            throw new ApiException("interest not found");
        }
        if(!visitor.getInterests().removeIf(i -> i.getId().equals(interestId))){
            throw new ApiException("visitor does not have this interest");
        }
        visitorRepository.save(visitor);
    }

    public void addInterestToVisitor(Integer visitorId, Integer interestId){
        Visitor visitor = visitorRepository.findVisitorById(visitorId);
        if(visitor == null){
            throw new ApiException("visitor not found");
        }
        Interest interest = interestRepository.findInterestById(interestId);
        if(interest == null){
            throw new ApiException("interest not found");
        }
        visitor.getInterests().add(interest);
        visitorRepository.save(visitor);
    }
}

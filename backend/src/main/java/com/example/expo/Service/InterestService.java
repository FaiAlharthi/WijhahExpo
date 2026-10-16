package com.example.expo.Service;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;


import com.example.expo.Api.ApiException;
import com.example.expo.Model.Interest;
import com.example.expo.Model.Visitor;
import com.example.expo.Repository.InterestRepository;
import com.example.expo.Repository.VisitorRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class InterestService {

    private final InterestRepository interestRepository;
    private final VisitorRepository visitorRepository;

    public List<Interest> getAllInterest(){
        return interestRepository.findAll();
    }

    public void addInterest(Interest interest){
        if(interestRepository.findInterestByName(interest.getName())!=null){
            throw new ApiException("Interest already exists");
        }
        interestRepository.save(interest);
    }

    public void updateInterest(Integer id, Interest interest){
        Interest oldInterest = interestRepository.findInterestById(id);
        if(oldInterest==null){
            throw new ApiException("Interest not found");
        }
        Interest sameInterest = interestRepository.findInterestByName(interest.getName());
        if(sameInterest!=null&&!sameInterest.getId().equals(id)){
            throw new ApiException("Interest already exists");
        }
        oldInterest.setName(interest.getName());
        oldInterest.setNameAr(interest.getNameAr());
        interestRepository.save(oldInterest);
    }

    public void deleteInterest(Integer id){
        Interest interest = interestRepository.findInterestById(id);
        if(interest==null){
            throw new ApiException("Interest not found");
        }
        if(interest.getVisitors()!=null){
            for(Visitor visitor : interest.getVisitors()){
                visitor.getInterests().remove(interest);
                visitorRepository.save(visitor);
            }
        }
        interestRepository.delete(interest);
    }

}
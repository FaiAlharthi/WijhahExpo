package com.example.expo.Service;

import com.example.expo.Api.ApiException;
import com.example.expo.Model.Entrance;
import com.example.expo.Model.Location;
import com.example.expo.Repository.EntranceRepository;
import com.example.expo.Repository.LocationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class EntranceService {
    private final EntranceRepository entranceRepository;
    private final LocationRepository locationRepository;

    public List<Entrance> getAllEntrances(){
        return entranceRepository.findAll();
    }

    public void addEntrance(Integer locationId, Entrance entrance){
        Location location = locationRepository.findLocationById(locationId);
        if(location == null){
            throw new ApiException("location not found");
        }
        if(entranceRepository.findEntranceByName(entrance.getName()) != null){
            throw new ApiException("entrance already exists");
        }
        entrance.setLocation(location);
        entranceRepository.save(entrance);
    }

    public void updateEntrance(Integer id, Entrance entrance){
        Entrance oldEntrance = entranceRepository.findEntranceById(id);
        if(oldEntrance == null){
            throw new ApiException("entrance not found");
        }
        Entrance sameName = entranceRepository.findEntranceByName(entrance.getName());
        if(sameName != null && !sameName.getId().equals(id)){
            throw new ApiException("entrance already exists");
        }
        oldEntrance.setName(entrance.getName());
        entranceRepository.save(oldEntrance);
    }

    public void deleteEntrance(Integer id){
        Entrance entrance = entranceRepository.findEntranceById(id);
        if(entrance == null){
            throw new ApiException("entrance not found");
        }
        // roadmaps are kept as history
        if(entrance.getRoadmaps() != null && !entrance.getRoadmaps().isEmpty()){
            throw new ApiException("entrance is used in roadmaps");
        }
        entranceRepository.delete(entrance);
    }
}

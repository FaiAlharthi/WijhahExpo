package com.example.expo.Service;

import com.example.expo.Api.ApiException;
import com.example.expo.Model.Location;
import com.example.expo.Model.Pavilion;
import com.example.expo.Repository.LocationRepository;
import com.example.expo.Repository.PathRepository;
import com.example.expo.Repository.PavilionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class LocationService {
    private final LocationRepository locationRepository;
    private final PathRepository pathRepository;


    public List<Location>getAllLocation(){
        return locationRepository.findAll();
    }

    public void addLocation(Location location){
        if(locationRepository.findLocationByXAndY(location.getX(),location.getY())!=null){
          throw new ApiException("Location already exists");
        }
        locationRepository.save(location);
    }

    public void updateLocation(Integer id, Location location){
        Location oldLocation=locationRepository.findLocationById(id);
        if(oldLocation==null){
            throw new ApiException("Location not found");
        }
        Location sameLocation = locationRepository.findLocationByXAndY(location.getX(), location.getY());
        if (sameLocation != null&&!sameLocation.getId().equals(id)) {
            throw new ApiException("Location already exists");
        }
        oldLocation.setX(location.getX());
        oldLocation.setY(location.getY());
        locationRepository.save(oldLocation);
    }


    public void deleteLocation(Integer id){
       Location location= locationRepository.findLocationById(id);
       if(location==null){
           throw new ApiException("Location not found");
       }
       if(location.getZone()!=null||location.getPavilion()!=null){
           throw new ApiException("Location is linked to a pavilion or zone delete it first");
       }
        if(pathRepository.existsByFromLocationOrToLocation(location, location)){
            throw new ApiException("Location has paths, delete them first");
        }
       locationRepository.delete(location);
    }




}

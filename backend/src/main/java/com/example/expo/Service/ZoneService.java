package com.example.expo.Service;

import com.example.expo.Api.ApiException;
import com.example.expo.Model.Location;
import com.example.expo.Model.Zone;
import com.example.expo.Repository.LocationRepository;
import com.example.expo.Repository.ZoneRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ZoneService {
    private final ZoneRepository zoneRepository;
    private final LocationRepository locationRepository;

  public List<Zone>getAllZones(){
      return zoneRepository.findAll();
  }

  public void addZone(Integer locationId,Zone zone) {
      Location location = locationRepository.findLocationById(locationId);
      if (location == null) {
          throw new ApiException("Location not found");
      }
      if (location.getZone() != null || location.getPavilion() != null) {
          throw new ApiException("Location is already used");
      }
      if (zoneRepository.findZoneByName(zone.getName()) != null) {
          throw new ApiException("Zone already exists");
      }
      zone.setLocation(location);
      zoneRepository.save(zone);
  }
    public void updateZone(Integer id, Zone zone){
        Zone oldZone = zoneRepository.findZoneById(id);
        if(oldZone == null){
            throw new ApiException("Zone not found");
        }
        Zone sameZone = zoneRepository.findZoneByName(zone.getName());
        if(sameZone != null && !sameZone.getId().equals(id)){
            throw new ApiException("Zone already exists");
        }
        oldZone.setName(zone.getName());
        oldZone.setDescription(zone.getDescription());
        zoneRepository.save(oldZone);
    }

    public void deleteZone(Integer id){
        Zone zone = zoneRepository.findZoneById(id);
        if(zone==null){
            throw new ApiException("Zone not found");
        }
        if(zone.getPavilions()!= null&&!zone.getPavilions().isEmpty()){
            throw new ApiException("Zone has pavilions delete them first");
        }
        zoneRepository.delete(zone);
    }








}

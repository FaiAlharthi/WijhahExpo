package com.example.expo.Repository;

import com.example.expo.Model.Location;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface LocationRepository extends JpaRepository<Location, Integer> {
    Location findLocationById(Integer id);
    Location findLocationByXAndY(Double x, Double y);
}

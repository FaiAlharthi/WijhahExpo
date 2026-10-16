package com.example.expo.Repository;

import com.example.expo.Model.Location;
import com.example.expo.Model.Path;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PathRepository extends JpaRepository<Path, Integer> {
    Path findPathById(Integer id);
    Path findPathByFromLocationAndToLocation(Location from, Location to);
    Boolean existsByFromLocationOrToLocation(Location from, Location to);
}
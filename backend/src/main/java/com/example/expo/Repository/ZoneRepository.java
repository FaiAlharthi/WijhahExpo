package com.example.expo.Repository;

import com.example.expo.Model.Zone;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ZoneRepository extends JpaRepository<Zone, Integer> {
    Zone findZoneById(Integer id);
    Zone findZoneByName(String name);
}

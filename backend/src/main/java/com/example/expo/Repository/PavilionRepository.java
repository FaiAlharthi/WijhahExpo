package com.example.expo.Repository;

import com.example.expo.Model.Pavilion;
import com.example.expo.Model.Zone;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PavilionRepository extends JpaRepository<Pavilion, Integer> {
    Pavilion findPavilionById(Integer id);
    Pavilion findPavilionByName(String name);
    List<Pavilion>findPavilionByZone(Zone zone);
    List<Pavilion> findPavilionsByNameContaining(String name);
    @Query("select r.pavilion from Review r group by r.pavilion order by avg(r.rating) desc")
    List<Pavilion> findTopRatedPavilions();
}

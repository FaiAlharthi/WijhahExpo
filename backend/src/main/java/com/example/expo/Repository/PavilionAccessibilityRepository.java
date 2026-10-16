package com.example.expo.Repository;

import com.example.expo.Model.Pavilion;
import com.example.expo.Model.PavilionAccessibility;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PavilionAccessibilityRepository extends JpaRepository<PavilionAccessibility, Integer> {
    PavilionAccessibility findPavilionAccessibilityByPavilionAndNeedType(Pavilion pavilion, String needType);
    List<PavilionAccessibility> findPavilionAccessibilitiesByPavilion(Pavilion pavilion);
}

package com.example.expo.Repository;

import com.example.expo.Model.Interest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface InterestRepository extends JpaRepository<Interest, Integer> {
    Interest findInterestById(Integer id);
    Interest findInterestByName(String name);
}

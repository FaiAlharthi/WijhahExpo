package com.example.expo.Repository;

import com.example.expo.Model.Entrance;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface EntranceRepository extends JpaRepository<Entrance, Integer> {
    Entrance findEntranceById(Integer id);
    Entrance findEntranceByName(String name);
}

package com.example.expo.Repository;

import com.example.expo.Model.Pavilion;
import com.example.expo.Model.Stamp;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface StampRepository extends JpaRepository<Stamp, Integer> {

    Stamp findStampById(Integer id);
    Stamp findStampByPavilion(Pavilion pavilion);

}
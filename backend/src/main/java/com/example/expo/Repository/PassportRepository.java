package com.example.expo.Repository;

import com.example.expo.Model.Passport;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PassportRepository extends JpaRepository<Passport, Integer> {
    Passport findPassportById(Integer id);
}

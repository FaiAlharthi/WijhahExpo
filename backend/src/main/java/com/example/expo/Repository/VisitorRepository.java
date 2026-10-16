package com.example.expo.Repository;

import com.example.expo.Model.Visitor;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface VisitorRepository extends JpaRepository<Visitor, Integer> {
    Visitor findVisitorById(Integer id);
}

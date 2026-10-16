package com.example.expo.Repository;

import com.example.expo.Model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface UserRepository extends JpaRepository<User, Integer> {
    User findUserById(Integer id);
    User findUserByUsername(String username);
    User findUserByEmail(String email);
}

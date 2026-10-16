package com.example.expo.Service;

import com.example.expo.Api.ApiException;
import com.example.expo.Dto.Out.UserResponse;
import com.example.expo.Model.User;
import com.example.expo.Repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class UserService {
    private final UserRepository userRepository;
    private final VisitorService visitorService;
    private final PasswordEncoder passwordEncoder;

    // visitor: own account only, admin: own account or any visitor, not another admin
    public UserResponse getUser(User currentUser, Integer id){
        User user = userRepository.findUserById(id);
        if(user == null){
            throw new ApiException("user not found");
        }
        boolean ownAccount = user.getId().equals(currentUser.getId());
        if("VISITOR".equals(currentUser.getRole()) && !ownAccount){
            throw new ApiException("you can only view your own account");
        }
        if("ADMIN".equals(currentUser.getRole()) && "ADMIN".equals(user.getRole()) && !ownAccount){
            throw new ApiException("you cannot view another admin account");
        }
        return toUserResponse(user);
    }

    private UserResponse toUserResponse(User user){
        return new UserResponse(user.getId(), user.getFullName(), user.getUsername(), user.getEmail(),
                user.getPhone(), user.getRole(), user.getCreatedAt());
    }

    public void updateUser(Integer id, User user){
        User oldUser = userRepository.findUserById(id);
        if(oldUser == null){
            throw new ApiException("user not found");
        }
        User usernameOwner = userRepository.findUserByUsername(user.getUsername());
        if(usernameOwner != null && !usernameOwner.getId().equals(id)){
            throw new ApiException("username already exists");
        }
        User emailOwner = userRepository.findUserByEmail(user.getEmail());
        if(emailOwner != null && !emailOwner.getId().equals(id)){
            throw new ApiException("email already exists");
        }
        oldUser.setFullName(user.getFullName());
        oldUser.setUsername(user.getUsername());
        oldUser.setPassword(passwordEncoder.encode(user.getPassword()));
        oldUser.setEmail(user.getEmail());
        oldUser.setPhone(user.getPhone());
        userRepository.save(oldUser);
    }

    public void deleteUser(Integer id){
        User user = userRepository.findUserById(id);
        if(user == null){
            throw new ApiException("user not found");
        }
        if(user.getVisitor() != null){
            visitorService.clearRoadmapStops(user.getVisitor());
        }
        userRepository.delete(user);
    }

    // admin deletes visitor accounts only
    public void deleteVisitorUser(Integer id){
        User user = userRepository.findUserById(id);
        if(user == null){
            throw new ApiException("user not found");
        }
        if("ADMIN".equals(user.getRole())){
            throw new ApiException("you cannot delete an admin account");
        }
        deleteUser(id);
    }
}

package com.example.expo.Dto.Out;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

// visitor with user info, interests and passport summary
@Data
@AllArgsConstructor
@NoArgsConstructor
public class VisitorResponse {
    private Integer id;
    private String fullName;
    private String username;
    private String email;
    private String phone;
    private Integer age;
    private String gender;
    private String preferredLanguage;
    private String nationality;
    private List<InterestResponse> interests;
    private String passportNumber;
    private LocalDateTime createdAt;
}

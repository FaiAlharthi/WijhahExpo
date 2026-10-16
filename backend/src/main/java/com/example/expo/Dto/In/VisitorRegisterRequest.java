package com.example.expo.Dto.In;

import jakarta.validation.constraints.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// one request creates the user, the visitor and the passport
@Data
@AllArgsConstructor
@NoArgsConstructor
public class VisitorRegisterRequest {

    @NotEmpty(message = "Full name cannot be empty")
    @Size(max = 50, message = "Full name should be 50 letters max")
    private String fullName;

    @NotEmpty(message = "Username cannot be empty")
    @Size(min = 4, max = 20, message = "Username must be between 4 and 20 characters")
    private String username;

    @NotEmpty(message = "Password cannot be empty")
    @Size(min = 8, message = "Password must be at least 8 characters")
    private String password;

    @NotEmpty(message = "Email cannot be empty")
    @Email(message = "Email must be in a valid form")
    private String email;

    @NotEmpty(message = "Phone cannot be empty")
    @Pattern(regexp = "^\\+[1-9]\\d{7,14}$", message = "Phone must be in international format, e.g. +966501234567")
    private String phone;

    @NotNull(message = "Age cannot be empty!")
    @Min(value = 1, message = "Age must be at least 1")
    @Max(value = 120, message = "Age must be at most 120")
    private Integer age;

    @NotEmpty(message = "Gender cannot be empty!")
    @Pattern(regexp = "^(MALE|FEMALE)$", message = "Gender must be MALE or FEMALE.")
    private String gender;

    @NotEmpty(message = "Preferred language cannot be empty!")
    @Pattern(regexp = "^(AR|EN)$", message = "Preferred language must be AR or EN.")
    private String preferredLanguage;

    @NotEmpty(message = "Nationality cannot be empty!")
    @Size(max = 50, message = "Nationality cannot be longer that 50 letters.")
    private String nationality;
}

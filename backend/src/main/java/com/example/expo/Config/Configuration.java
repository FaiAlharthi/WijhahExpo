package com.example.expo.Config;

import org.springframework.context.annotation.Bean;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

@org.springframework.context.annotation.Configuration
@EnableWebSecurity
public class Configuration {

    @Bean
    public PasswordEncoder passwordEncoder(){
        return new BCryptPasswordEncoder();
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception{
        return http
                .csrf(csrf -> csrf.disable())
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED)
                )
                .authorizeHttpRequests(auth -> auth
                        //anyone,no login needed
                        .requestMatchers("/api/v1/visitor/register",
                                "/api/v1/zone/get", "/api/v1/entrance/getAll", "/api/v1/location/get", "/api/v1/interest/get",
                                "/api/v1/pavilion/get", "/api/v1/pavilion/details/*", "/api/v1/pavilion/zone/*", "/api/v1/pavilion/search/*", "/api/v1/pavilion/top-rated",
                                "/api/v1/path/get", "/api/v1/path/shortest/*/*", "/api/v1/crowd/now", "/api/v1/crowd/pavilion/*", "/api/v1/path/shortest-accessible/*/*", "/api/v1/pavilion/accessible/*",
                                "/api/v1/review/pavilion/*/average", "/api/v1/review/pavilion/*/latest", "/stamps/**").permitAll()

                        //admin only
                        .requestMatchers("/api/v1/admin/dashboard",
                                "/api/v1/visitor/getAll", "/api/v1/visitor/get/*", "/api/v1/visitor/deleteVisitor/*", "/api/v1/user/deleteUser/*",
                                "/api/v1/zone/add/*", "/api/v1/zone/update/*", "/api/v1/zone/delete/*",
                                "/api/v1/entrance/createEntrance/*", "/api/v1/entrance/updateEntrance/*", "/api/v1/entrance/deleteEntrance/*",
                                "/api/v1/location/add", "/api/v1/location/update/*", "/api/v1/location/delete/*",
                                "/api/v1/interest/add", "/api/v1/interest/update/*", "/api/v1/interest/delete/*",
                                "/api/v1/pavilion/add/*/*", "/api/v1/pavilion/update/*", "/api/v1/pavilion/delete/*", "/api/v1/pavilion/accessibility/*/*",
                                "/api/v1/path/add/*/*", "/api/v1/path/delete/*", "/api/v1/path/generate",
                                "/api/v1/crowd/factor/*", "/api/v1/crowd/override/**", "/api/v1/crowd/check", "/api/v1/path/accessibility/*",
                                "/api/v1/roadmap/getAll", "/api/v1/visit/getAll", "/api/v1/passport/getAll", "/api/v1/review/get").hasAuthority("ADMIN")

                        //visitor, his own data only
                        .requestMatchers("/api/v1/visitor/getMyInfo", "/api/v1/visitor/updateVisitor", "/api/v1/visitor/deleteVisitor",
                                "/api/v1/visitor/addInterest/*", "/api/v1/visitor/removeInterest/*",
                                "/api/v1/user/updateUser", "/api/v1/user/deleteUser",
                                "/api/v1/roadmap/getMyRoadmaps", "/api/v1/roadmap/generate", "/api/v1/roadmap/changeEntrance/*/*",
                                "/api/v1/roadmap/getStops/*", "/api/v1/roadmap/addStop/*/*/*", "/api/v1/roadmap/removeStop/*/*",
                                "/api/v1/roadmap/reorder/*", "/api/v1/roadmap/makeDynamic/*", "/api/v1/roadmap/deleteRoadmap/*", "/api/v1/roadmap/pdf/*",
                                "/api/v1/roadmap/share/*", "/api/v1/roadmap/unshare/*", "/api/v1/roadmap/confirm/*",
                                "/api/v1/roadmap/shared", "/api/v1/roadmap/copy/*",
                                "/api/v1/path/roadmap/*", "/api/v1/path/roadmap/*/*",
                                "/api/v1/visit/checkIn/*", "/api/v1/passport/getMyPassport", "/api/v1/passport/getMyStamps", "/api/v1/pavilion/unvisited",
                                "/api/v1/review/add/*", "/api/v1/review/update/*", "/api/v1/review/getPending", "/api/v1/review/getMyReviews",
                                "/api/v1/chatbot/suggestions", "/api/v1/chatbot/ask",
                                "/api/v1/crowd/alerts/my", "/api/v1/crowd/alerts/*/accept").hasAuthority("VISITOR")

                        //visitor his own review or account, admin any review or visitor account (checked in the service)
                        .requestMatchers("/api/v1/review/delete/*", "/api/v1/user/get/*").hasAnyAuthority("ADMIN", "VISITOR")
                        // صفحات الخريطة (ملفات static)
                        .requestMatchers("/", "/route3d.html", "/mapart.js", "/expo-map.png", "/seed.html", "/favicon.ico", "/error").permitAll()
                        .anyRequest().authenticated()
                )
                .logout(logout -> logout
                        .logoutUrl("/api/v1/user/auth/logout")
                        .invalidateHttpSession(true)
                )
                .httpBasic(basic -> {})
                .build();
    }
}

package com.banking.userservice.auth;

import com.banking.userservice.security.JwtUtil;
import com.banking.userservice.user.User;
import com.banking.userservice.user.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthenticationManager authenticationManager;
    private final JwtUtil jwtUtil;
    private final UserService userService;

    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(@Valid @RequestBody LoginRequest request) {
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.getEmail(), request.getPassword())
        );

        User user = (User) userService.loadUserByUsername(request.getEmail());
        String token = jwtUtil.generateToken(user);

        return ResponseEntity.ok(new LoginResponse(token, user.getEmail(), user.getRole().name()));
    }
}

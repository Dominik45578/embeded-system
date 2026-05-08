package com.example.backend.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
class TestController {

    @GetMapping
    public String test() {
        return "test"; // This is here only to test FireBase auth
    }

}

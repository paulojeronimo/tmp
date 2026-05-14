package com.example.echo.controller;

import org.springframework.web.bind.annotation.*;
import java.net.InetAddress;
import java.time.ZonedDateTime;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class EchoController {

    @GetMapping("/echo")
    public Map<String, Object> echo(@RequestParam String msg) throws Exception {
        var serverIp = InetAddress.getLocalHost().getHostAddress();
        var timestamp = ZonedDateTime.now().toString();

        return Map.of(
                "message", msg,
                "serverIp", serverIp,
                "timestamp", timestamp
        );
    }
}


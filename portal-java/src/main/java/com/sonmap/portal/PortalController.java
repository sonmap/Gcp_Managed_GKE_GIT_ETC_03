package com.sonmap.portal;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.util.StreamUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestClient;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

@RestController
@RequestMapping("/api")
public class PortalController {

    private final RestClient restClient;
    private final String adapterUrl;

    public PortalController(RestClient.Builder builder,
                            @Value("${adapter.url}") String adapterUrl) {
        this.restClient = builder.build();
        this.adapterUrl = adapterUrl.replaceAll("/$", "");
    }

    /**
     * The request body is deliberately forwarded as raw JSON.
     * This preserves the legacy Java portal JSON contract and keeps
     * GCP/Terraform mapping logic inside the Cloud Run adapter.
     */
    @PostMapping(value = "/tasks", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<String> createTask(HttpServletRequest request) throws IOException {
        String rawJson = StreamUtils.copyToString(request.getInputStream(), StandardCharsets.UTF_8);

        return restClient.post()
                .uri(adapterUrl + "/deploy")
                .header(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                .body(rawJson)
                .exchange((req, response) -> {
                    String body = new String(response.getBody().readAllBytes(), StandardCharsets.UTF_8);
                    return ResponseEntity.status(response.getStatusCode())
                            .contentType(MediaType.APPLICATION_JSON)
                            .body(body);
                });
    }

    @GetMapping("/infra/status")
    public ResponseEntity<String> getStatus(@RequestParam String operation) {
        return restClient.get()
                .uri(adapterUrl + "/status?operation={operation}", operation)
                .exchange((req, response) -> {
                    String body = new String(response.getBody().readAllBytes(), StandardCharsets.UTF_8);
                    return ResponseEntity.status(response.getStatusCode())
                            .contentType(MediaType.APPLICATION_JSON)
                            .body(body);
                });
    }
}

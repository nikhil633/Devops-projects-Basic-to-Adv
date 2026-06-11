package com.yourorg.inventory.controller;

import com.yourorg.inventory.model.Product;
import com.yourorg.inventory.service.ProductService;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/products")
public class ProductController {

    private final ProductService service;
    private final Counter productCreatedCounter;

    public ProductController(ProductService service, MeterRegistry registry) {
        this.service = service;
        this.productCreatedCounter = Counter.builder("inventory_products_created_total")
            .description("Total products created").register(registry);
    }

    @GetMapping
    public List<Product> list() { return service.findAll(); }

    @GetMapping("/{id}")
    public ResponseEntity<Product> get(@PathVariable Long id) {
        return service.findById(id).map(ResponseEntity::ok).orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<Product> create(@Valid @RequestBody Product product) {
        productCreatedCounter.increment();
        return ResponseEntity.status(HttpStatus.CREATED).body(service.save(product));
    }

    @PutMapping("/{id}")
    public ResponseEntity<Product> update(@PathVariable Long id, @Valid @RequestBody Product product) {
        return service.update(id, product).map(ResponseEntity::ok).orElse(ResponseEntity.notFound().build());
    }

    @PatchMapping("/{id}/stock")
    public ResponseEntity<?> adjustStock(@PathVariable Long id, @RequestBody Map<String, Integer> body) {
        int delta = body.getOrDefault("delta", 0);
        boolean ok = service.adjustStock(id, delta);
        if (!ok) return ResponseEntity.badRequest().body(Map.of("error", "insufficient stock or product not found"));
        return ResponseEntity.ok(Map.of("message", "stock updated"));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        service.delete(id);
        return ResponseEntity.noContent().build();
    }
}

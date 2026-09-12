package com.example.inventory.controller;

import com.example.inventory.model.Item;
import com.example.inventory.service.ItemService;
import jakarta.validation.Valid;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/items")
public class ItemController {
    private final ItemService service;
    public ItemController(ItemService service) { this.service = service; }

    @GetMapping
    public List<Item> getAll(@RequestParam(required = false) String category) {
        return category != null ? service.findByCategory(category) : service.findAll();
    }

    @GetMapping("/{id}")
    public Item getById(@PathVariable Long id) { return service.findById(id); }

    @PostMapping
    public ResponseEntity<Item> create(@Valid @RequestBody Item item) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(item));
    }

    @PutMapping("/{id}")
    public Item update(@PathVariable Long id, @Valid @RequestBody Item item) {
        return service.update(id, item);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        service.delete(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/low-stock")
    public List<Item> lowStock(@RequestParam(defaultValue = "10") Integer threshold) {
        return service.findLowStock(threshold);
    }
}

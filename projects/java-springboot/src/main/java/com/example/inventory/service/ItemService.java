package com.example.inventory.service;

import com.example.inventory.model.Item;
import com.example.inventory.repository.ItemRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Service
@Transactional
public class ItemService {
    private final ItemRepository repo;
    public ItemService(ItemRepository repo) { this.repo = repo; }

    public List<Item> findAll() { return repo.findAll(); }

    public Item findById(Long id) {
        return repo.findById(id).orElseThrow(() -> new RuntimeException("Item not found: " + id));
    }

    public Item create(Item item) {
        if (repo.findBySku(item.getSku()).isPresent())
            throw new RuntimeException("SKU already exists: " + item.getSku());
        return repo.save(item);
    }

    public Item update(Long id, Item updated) {
        Item existing = findById(id);
        existing.setName(updated.getName());
        existing.setDescription(updated.getDescription());
        existing.setPrice(updated.getPrice());
        existing.setQuantity(updated.getQuantity());
        existing.setCategory(updated.getCategory());
        return repo.save(existing);
    }

    public void delete(Long id) { findById(id); repo.deleteById(id); }
    public List<Item> findByCategory(String cat) { return repo.findByCategory(cat); }
    public List<Item> findLowStock(Integer threshold) { return repo.findByQuantityLessThan(threshold); }
}

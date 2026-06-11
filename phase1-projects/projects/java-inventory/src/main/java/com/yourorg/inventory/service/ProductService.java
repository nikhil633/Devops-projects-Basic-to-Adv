package com.yourorg.inventory.service;

import com.yourorg.inventory.model.Product;
import com.yourorg.inventory.repository.ProductRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import java.util.Optional;

@Service
@Transactional
public class ProductService {

    private final ProductRepository repo;

    public ProductService(ProductRepository repo) { this.repo = repo; }

    public List<Product> findAll() { return repo.findAll(); }

    public Optional<Product> findById(Long id) { return repo.findById(id); }

    public Product save(Product product) { return repo.save(product); }

    public Optional<Product> update(Long id, Product updated) {
        return repo.findById(id).map(existing -> {
            existing.setName(updated.getName());
            existing.setDescription(updated.getDescription());
            existing.setPrice(updated.getPrice());
            existing.setStock(updated.getStock());
            return repo.save(existing);
        });
    }

    public boolean adjustStock(Long id, int delta) {
        return repo.findById(id).map(p -> {
            int newStock = p.getStock() + delta;
            if (newStock < 0) return false;
            p.setStock(newStock);
            repo.save(p);
            return true;
        }).orElse(false);
    }

    public void delete(Long id) { repo.deleteById(id); }
}

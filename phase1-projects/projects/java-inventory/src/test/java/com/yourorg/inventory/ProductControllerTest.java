package com.yourorg.inventory;

import com.yourorg.inventory.model.Product;
import com.yourorg.inventory.service.ProductService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.web.servlet.MockMvc;
import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
class ProductControllerTest {

    @Autowired MockMvc mvc;
    @MockBean ProductService service;

    @Test
    void listProducts() throws Exception {
        Product p = new Product();
        p.setName("Widget"); p.setPrice(BigDecimal.TEN); p.setStock(5);
        when(service.findAll()).thenReturn(List.of(p));
        mvc.perform(get("/api/products"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$[0].name").value("Widget"));
    }

    @Test
    void getProductNotFound() throws Exception {
        when(service.findById(99L)).thenReturn(Optional.empty());
        mvc.perform(get("/api/products/99")).andExpect(status().isNotFound());
    }
}

package com.example.expo.Dto.In;

import jakarta.validation.constraints.NotEmpty;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

// the unvisited stops in the new order, visited stops stay in their place
@Data
@AllArgsConstructor
@NoArgsConstructor
public class ReorderStopsRequest {

    @NotEmpty(message = "visit ids cannot be empty")
    private List<Integer> visitIds;
}

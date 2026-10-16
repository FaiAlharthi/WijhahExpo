package com.example.expo.Dto.Out;

import com.example.expo.Model.Location;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class RoadmapRouteResponse {
    private List<RouteStopResponse> visitOrder;   // كل محطات الخطة بالترتيب، والمزارة isVisited = true
    private Double totalDistance;       // مجموع المشي
    private List<Location> route;       // كل النقاط اللي يمشي عليها
    private String exitEntrance;       // البوابة اللي يطلع منها
    private Boolean accessibleRoute;   // true = the whole walk is step free (only for trips with a mobility need)
}

package com.example.expo.Service;

import com.example.expo.Api.ApiException;
import com.example.expo.Dto.Out.RoadmapRouteResponse;
import com.example.expo.Dto.Out.RouteStopResponse;
import com.example.expo.Dto.Out.ShortestPathResponse;
import com.example.expo.Model.Location;
import com.example.expo.Model.Path;
import com.example.expo.Model.Pavilion;
import com.example.expo.Model.Roadmap;
import com.example.expo.Model.Visit;
import com.example.expo.Repository.LocationRepository;
import com.example.expo.Repository.PathRepository;
import com.example.expo.Repository.RoadmapRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import com.example.expo.Dto.In.PathAccessibilityRequest;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import com.example.expo.Model.Entrance;
import com.example.expo.Repository.EntranceRepository;
import com.example.expo.Model.Zone;
import com.example.expo.Repository.PavilionRepository;
import com.example.expo.Repository.ZoneRepository;


@Service
@RequiredArgsConstructor
public class PathService {
    private final PathRepository pathRepository;
    private final LocationRepository locationRepository;
    private final RoadmapRepository roadmapRepository;
    private final EntranceRepository entranceRepository;
    private final ZoneRepository zoneRepository;
    private final PavilionRepository pavilionRepository;

    // a path in the sun counts 30% longer for trips with a mobility need
    private static final double SUN_WEIGHT = 1.3;

    public List<Path> getAllPaths(){
        return pathRepository.findAll();
    }

    // يضيف ممر بين نقطتين، والمسافة تنحسب تلقائي
    public void addPath(Integer fromId, Integer toId){
        if(fromId.equals(toId)){
            throw new ApiException("Path must connect two different locations");
        }
        Location from = locationRepository.findLocationById(fromId);
        Location to = locationRepository.findLocationById(toId);
        if(from == null || to == null){
            throw new ApiException("Location not found");
        }
        if(pathRepository.findPathByFromLocationAndToLocation(from, to) != null
                || pathRepository.findPathByFromLocationAndToLocation(to, from) != null){
            throw new ApiException("Path already exists");
        }
        double dx = from.getX() - to.getX();
        double dy = from.getY() - to.getY();

        Path path = new Path();
        path.setFromLocation(from);
        path.setToLocation(to);
        path.setDistance(Math.sqrt(dx * dx + dy * dy));
        path.setStepFree(true);
        path.setShaded(false);
        pathRepository.save(path);
    }

    public void deletePath(Integer id){
        Path path = pathRepository.findPathById(id);
        if(path == null){
            throw new ApiException("Path not found");
        }
        pathRepository.delete(path);
    }

    // ===== Dijkstra: أقصر طريق على الممرات بين نقطتين =====
    public ShortestPathResponse getShortestPath(Integer fromId, Integer toId){
        return findShortestPath(fromId, toId, false, false);
    }

    // for wheelchairs, walkers and strollers: no stairs, and the shade is preferred
    public ShortestPathResponse getAccessibleShortestPath(Integer fromId, Integer toId){
        return findShortestPath(fromId, toId, true, true);
    }

    // the walk for the needs of a trip, a normal walk when the trip has no mobility need
    public ShortestPathResponse getShortestPath(Integer fromId, Integer toId, Collection<String> needs){
        boolean mobility = AccessibilityService.needsStepFree(needs);
        return findShortestPath(fromId, toId, mobility, mobility);
    }

    // stepFreeOnly skips paths with stairs, preferShade counts a sunny path 30% longer so the route goes through the shade
    // totalDistance is always the real walking distance
    private ShortestPathResponse findShortestPath(Integer fromId, Integer toId, boolean stepFreeOnly, boolean preferShade){
        Location start = locationRepository.findLocationById(fromId);
        Location end = locationRepository.findLocationById(toId);
        if(start == null || end == null){
            throw new ApiException("Location not found");
        }

        List<Path> paths = new ArrayList<>();
        for(Path path : pathRepository.findAll()){
            if(!stepFreeOnly || isStepFree(path)){
                paths.add(path);
            }
        }
        Map<Integer, Double> distance = new HashMap<>();   // أقصر مسافة معروفة لكل نقطة (مع وزن الظل)
        Map<Integer, Double> walked = new HashMap<>();     // المسافة الحقيقية لنفس الطريق
        Map<Integer, Integer> previous = new HashMap<>();  // جيت لهذي النقطة من وين
        List<Integer> unvisited = new ArrayList<>();

        // 1) كل النقاط بعيدة جداً، إلا البداية = 0
        for(Location location : locationRepository.findAll()){
            distance.put(location.getId(), Double.MAX_VALUE);
            unvisited.add(location.getId());
        }
        distance.put(start.getId(), 0.0);
        walked.put(start.getId(), 0.0);

        while(!unvisited.isEmpty()){
            // 2) خذ أقرب نقطة ما زرناها
            Integer current = null;
            double min = Double.MAX_VALUE;
            for(Integer id : unvisited){
                if(distance.get(id) < min){
                    min = distance.get(id);
                    current = id;
                }
            }
            if(current == null || current.equals(end.getId())){
                break; // وصلنا، أو الباقي ما ينوصل له
            }
            unvisited.remove(current);

            // 3) حدّث جيرانها
            for(Path path : paths){
                Integer neighbor = null;
                if(path.getFromLocation().getId().equals(current)){
                    neighbor = path.getToLocation().getId();
                } else if(path.getToLocation().getId().equals(current)){
                    neighbor = path.getFromLocation().getId();
                }
                if(neighbor == null || !unvisited.contains(neighbor)){
                    continue;
                }
                double weight = path.getDistance();
                if(preferShade && !Boolean.TRUE.equals(path.getShaded())){
                    weight = weight * SUN_WEIGHT;
                }
                double newDistance = distance.get(current) + weight;
                if(newDistance < distance.get(neighbor)){
                    distance.put(neighbor, newDistance);
                    walked.put(neighbor, walked.get(current) + path.getDistance());
                    previous.put(neighbor, current);
                }
            }
        }

        if(distance.get(end.getId()) == Double.MAX_VALUE){
            throw new ApiException(stepFreeOnly ? "No step free path between these locations" : "No path between these locations");
        }

        // 4) نرجع من النهاية للبداية عشان نبني الطريق
        List<Location> route = new ArrayList<>();
        Integer step = end.getId();
        while(step != null){
            route.add(0, locationRepository.findLocationById(step));
            step = previous.get(step);
        }
        return new ShortestPathResponse(walked.get(end.getId()), route);
    }

    // every location that can be reached from an entrance without stairs
    public Set<Integer> getStepFreeReachableLocations(){
        Map<Integer, List<Integer>> neighbors = new HashMap<>();
        for(Path path : pathRepository.findAll()){
            if(!isStepFree(path)){
                continue;
            }
            Integer a = path.getFromLocation().getId();
            Integer b = path.getToLocation().getId();
            neighbors.computeIfAbsent(a, k -> new ArrayList<>()).add(b);
            neighbors.computeIfAbsent(b, k -> new ArrayList<>()).add(a);
        }
        Set<Integer> reached = new HashSet<>();
        List<Integer> toCheck = new ArrayList<>();
        for(Entrance entrance : entranceRepository.findAll()){
            if(entrance.getLocation() != null && reached.add(entrance.getLocation().getId())){
                toCheck.add(entrance.getLocation().getId());
            }
        }
        while(!toCheck.isEmpty()){
            Integer current = toCheck.remove(toCheck.size() - 1);
            for(Integer next : neighbors.getOrDefault(current, new ArrayList<>())){
                if(reached.add(next)){
                    toCheck.add(next);
                }
            }
        }
        return reached;
    }

    // a path without data counts as step free
    private boolean isStepFree(Path path){
        return path.getStepFree() == null || path.getStepFree();
    }

    // admin marks a path as step free and shaded
    public void updatePathAccessibility(Integer id, PathAccessibilityRequest request){
        Path path = pathRepository.findPathById(id);
        if(path == null){
            throw new ApiException("Path not found");
        }
        path.setStepFree(request.getStepFree());
        path.setShaded(request.getShaded());
        pathRepository.save(path);
    }

    // ===== مسار الرحلة من نقطة يحددها الزائر (مثلاً مكانه الحين) =====
    public RoadmapRouteResponse getRoadmapRoute(Integer visitorId, Integer roadmapId, Integer startLocationId){
        Roadmap roadmap = roadmapRepository.findRoadmapById(roadmapId);
        // only the owner of the roadmap can see its route
        if(roadmap == null || !roadmap.getVisitor().getId().equals(visitorId)){
            throw new ApiException("Roadmap not found");
        }
        Location start = locationRepository.findLocationById(startLocationId);
        if(start == null){
            throw new ApiException("Start location not found");
        }
        // from the visitor place: the path goes only to the pavilions not visited yet
        return buildRoute(roadmap, start, false);
    }
    // ===== يولّد الممرات تلقائي من أماكن الزونات والأجنحة والبوابات =====
    public Integer generatePaths(){
        int added = 0;
        List<Zone> zones = zoneRepository.findAll();

        // وسط كل زون
        List<Location> hubs = new ArrayList<>();
        for(Zone zone : zones){
            if(zone.getLocation() != null){
                hubs.add(zone.getLocation());
            }
        }

        // 1) داخل كل زون
        for(Zone zone : zones){
            Location hub = zone.getLocation();
            if(hub == null){
                continue;
            }
            List<Pavilion> pavilions = pavilionRepository.findPavilionByZone(zone);
            for(Pavilion pavilion : pavilions){
                Location here = pavilion.getLocation();
                if(here == null){
                    continue;
                }
                // ممر للداخل: لأقرب نقطة أقرب منه لوسط الزون (الوسط نفسه أو جناح ثاني)
                Location inner = hub;
                double bestInner = distance(here, hub);
                // ممر جانبي: لأقرب جناح جنبه
                Location side = null;
                double bestSide = Double.MAX_VALUE;

                for(Pavilion other : pavilions){
                    Location there = other.getLocation();
                    if(there == null || other.getId().equals(pavilion.getId())){
                        continue;
                    }
                    double d = distance(here, there);
                    if(distance(there, hub) < distance(here, hub) && d < bestInner){
                        bestInner = d;
                        inner = there;
                    }
                    if(d < bestSide){
                        bestSide = d;
                        side = there;
                    }
                }
                added = added + connect(here, inner);
                if(side != null){
                    added = added + connect(here, side);
                }
            }
        }

        // 2) كل زون توصل بأقرب زونين
        for(Location hub : hubs){
            for(Location near : twoNearest(hub, hubs)){
                added = added + connect(hub, near);
            }
        }

        // 3) كل بوابة توصل بأقرب زونين
        for(Entrance entrance : entranceRepository.findAll()){
            if(entrance.getLocation() == null){
                continue;
            }
            for(Location near : twoNearest(entrance.getLocation(), hubs)){
                added = added + connect(entrance.getLocation(), near);
            }
        }
        return added;
    }

    // أقرب نقطتين من القائمة
    private List<Location> twoNearest(Location from, List<Location> options){
        Location first = null;
        Location second = null;
        double firstDistance = Double.MAX_VALUE;
        double secondDistance = Double.MAX_VALUE;
        for(Location option : options){
            if(option.getId().equals(from.getId())){
                continue;
            }
            double d = distance(from, option);
            if(d < firstDistance){
                second = first;
                secondDistance = firstDistance;
                first = option;
                firstDistance = d;
            } else if(d < secondDistance){
                second = option;
                secondDistance = d;
            }
        }
        List<Location> result = new ArrayList<>();
        if(first != null){
            result.add(first);
        }
        if(second != null){
            result.add(second);
        }
        return result;
    }

    // يضيف ممر إذا مو موجود، ويرجع 1 إذا انضاف
    private int connect(Location a, Location b){
        if(a.getId().equals(b.getId())){
            return 0;
        }
        if(pathRepository.findPathByFromLocationAndToLocation(a, b) != null
                || pathRepository.findPathByFromLocationAndToLocation(b, a) != null){
            return 0;
        }
        Path path = new Path();
        path.setFromLocation(a);
        path.setToLocation(b);
        path.setDistance(distance(a, b));
        path.setStepFree(true);
        path.setShaded(false);
        pathRepository.save(path);
        return 1;
    }

    private double distance(Location a, Location b){
        double dx = a.getX() - b.getX();
        double dy = a.getY() - b.getY();
        return Math.sqrt(dx * dx + dy * dy);
    }

    // مسافة المشي بين نقطتين على الممرات (Dijkstra)، وإذا ما فيه ممر نرجع للخط المستقيم
    public Double getWalkingDistance(Location from, Location to){
        try {
            return getShortestPath(from.getId(), to.getId()).getTotalDistance();
        } catch (ApiException e) {
            return distance(from, to);
        }
    }
    // ===== مسار الرحلة من بوابة الدخول اللي اختارها الزائر =====
    public RoadmapRouteResponse getRoadmapRouteFromEntrance(Integer visitorId, Integer roadmapId){
        Roadmap roadmap = roadmapRepository.findRoadmapById(roadmapId);
        // only the owner of the roadmap can see its route
        if(roadmap == null || !roadmap.getVisitor().getId().equals(visitorId)){
            throw new ApiException("Roadmap not found");
        }
        if(roadmap.getEntrance() == null || roadmap.getEntrance().getLocation() == null){
            throw new ApiException("Roadmap entrance has no location");
        }
        // from the entrance: the path goes through all stops, visited ones included
        return buildRoute(roadmap, roadmap.getEntrance().getLocation(), true);
    }

    // follows the roadmap order (stopOrder) and draws the shortest path between each stop and the next
    // visitOrder always has all stops, the path skips visited stops when drawPathToVisited is false
    private RoadmapRouteResponse buildRoute(Roadmap roadmap, Location start, boolean drawPathToVisited){
        List<Visit> allStops = new ArrayList<>();
        if(roadmap.getVisits() != null){
            for(Visit visit : roadmap.getVisits()){
                if(visit.getPavilion() != null && visit.getPavilion().getLocation() != null){
                    allStops.add(visit);
                }
            }
        }
        allStops.sort(Comparator.comparing(Visit::getStopOrder, Comparator.nullsLast(Comparator.naturalOrder())));

        List<RouteStopResponse> visitOrder = new ArrayList<>();
        List<Visit> stops = new ArrayList<>();
        for(Visit visit : allStops){
            visitOrder.add(new RouteStopResponse(visit.getId(), visit.getStopOrder(), visit.getPavilion().getId(),
                    visit.getPavilion().getName(), visit.getIsVisited()));
            if(drawPathToVisited || !visit.getIsVisited()){
                stops.add(visit);
            }
        }
        if(stops.isEmpty()){
            throw new ApiException("Roadmap has no remaining pavilions");
        }

        List<Location> fullRoute = new ArrayList<>();
        double totalDistance = 0;
        // trips with a wheelchair, a walker or a stroller walk on step free paths when they can
        Set<String> needs = roadmap.getAccessibilityNeeds();
        boolean mobility = AccessibilityService.needsStepFree(needs);
        boolean accessibleRoute = true;

        Location current = start;
        fullRoute.add(current);

        for(Visit stop : stops){
            Pavilion nextPavilion = stop.getPavilion();
            ShortestPathResponse bestPath = null;
            if(mobility){
                try {
                    bestPath = getAccessibleShortestPath(current.getId(), nextPavilion.getLocation().getId());
                } catch (ApiException e) {
                    accessibleRoute = false; // no step free way, the normal path is shown
                }
            }
            if(bestPath == null){
                try {
                    bestPath = getShortestPath(current.getId(), nextPavilion.getLocation().getId());
                } catch (ApiException e) {
                    throw new ApiException("Some pavilions are not connected by paths");
                }
            }

            // add its path to the full route (without repeating the start point)
            for(int i = 1; i < bestPath.getLocations().size(); i++){
                fullRoute.add(bestPath.getLocations().get(i));
            }
            totalDistance = totalDistance + bestPath.getTotalDistance();

            // this pavilion becomes the new start point
            current = nextPavilion.getLocation();
        }

        // 4) بعد آخر جناح: نطلع من أقرب بوابة
        String exitEntrance = null;
        ShortestPathResponse exitPath = null;
        for(Entrance entrance : entranceRepository.findAll()){
            if(entrance.getLocation() == null){
                continue;
            }
            ShortestPathResponse path;
            try {
                path = getShortestPath(current.getId(), entrance.getLocation().getId(), needs);
            } catch (ApiException e) {
                try {
                    path = getShortestPath(current.getId(), entrance.getLocation().getId());
                } catch (ApiException noPath) {
                    continue;
                }
            }
            if(exitPath == null || path.getTotalDistance() < exitPath.getTotalDistance()){
                exitPath = path;
                exitEntrance = entrance.getName();
            }
        }
        if(exitPath != null){
            for(int i = 1; i < exitPath.getLocations().size(); i++){
                fullRoute.add(exitPath.getLocations().get(i));
            }
            totalDistance = totalDistance + exitPath.getTotalDistance();
        }

        return new RoadmapRouteResponse(visitOrder, totalDistance, fullRoute, exitEntrance, mobility ? accessibleRoute : null);
    }

}
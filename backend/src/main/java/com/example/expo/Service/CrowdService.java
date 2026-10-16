package com.example.expo.Service;

import com.example.expo.Api.ApiException;
import com.example.expo.Dto.Out.CrowdAlertResponse;
import com.example.expo.Dto.Out.CrowdPavilionResponse;
import com.example.expo.Dto.Out.CrowdSlotResponse;
import com.example.expo.Dto.Out.CrowdStatusResponse;
import com.example.expo.Model.CrowdAlert;
import com.example.expo.Model.Location;
import com.example.expo.Model.Pavilion;
import com.example.expo.Model.Roadmap;
import com.example.expo.Model.Visit;
import com.example.expo.Model.Visitor;
import com.example.expo.Repository.CrowdAlertRepository;
import com.example.expo.Repository.PavilionRepository;
import com.example.expo.Repository.RoadmapRepository;
import com.example.expo.Repository.VisitRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.ObjectMapper;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

// estimates the queue of every pavilion from the roadmaps of the day (no cameras or sensors):
// every roadmap becomes a timeline (walk + visit per stop), the people of each 15 minute slot are counted,
// and the people above the pavilion capacity become waiting minutes
@Service
@RequiredArgsConstructor
public class CrowdService {
    private final RoadmapRepository roadmapRepository;
    private final VisitRepository visitRepository;
    private final PavilionRepository pavilionRepository;
    private final CrowdAlertRepository crowdAlertRepository;
    private final PathService pathService;
    private final WhatsAppService whatsAppService;

    private final ObjectMapper objectMapper = new ObjectMapper();

    public static final int SLOT_MINUTES = 15;
    private static final int SLOTS = 24 * 60 / SLOT_MINUTES;
    public static final int CALM_MAX = 10;        // 10 minutes or less = calm
    public static final int CROWDED_MIN = 20;     // 20 minutes or more = crowded
    private static final int DEFAULT_CAPACITY = 150;
    private static final int DEFAULT_VISIT_MINUTES = 20;
    private static final double METERS_PER_UNIT = 2;     // one map unit = 2 meters
    private static final double METERS_PER_MINUTE = 75;  // normal walking speed
    private static final int MAX_ALERTS_PER_DAY = 3;
    private static final int MINUTES_BETWEEN_ALERTS = 20;
    private static final int ALERT_AHEAD_MINUTES = 15;   // the alert is sent 15 minutes before the pavilion gets calm
    private static final DateTimeFormatter HH_MM = DateTimeFormatter.ofPattern("HH:mm");

    // every visitor with the app stands for this many visitors (not everyone uses the app)
    @Value("${crowd.app-factor:4}")
    private double appFactor;

    private final Map<Integer, ManualWait> manualWaits = new ConcurrentHashMap<>();
    private final Map<String, Integer> walkCache = new ConcurrentHashMap<>();
    private LocalDateTime walkCacheTime = LocalDateTime.now();

    private LocalDate forecastDate;
    private LocalDateTime forecastTime;
    private Map<Integer, double[]> forecastPeople;

    // queue set by the admin for some time (for demos and pavilion staff)
    private record ManualWait(int minutes, LocalDateTime from, LocalDateTime until){}

    // one stop of a roadmap in time
    public record Stay(Integer pavilionId, Integer visitId, LocalTime start, LocalTime end, int people){}

    // ===== timeline of one roadmap =====
    // planned times come from the arrival time, the walk (Dijkstra) and the visit minutes, breaks push the next stops.
    // a check-in moves the rest of the timeline only when it makes sense (on time, on the day, not many at once)
    public List<Stay> timeline(Roadmap roadmap){
        List<Stay> stays = new ArrayList<>();
        if(roadmap.getArrivalTime() == null || roadmap.getDepartureTime() == null){
            return stays;
        }
        Set<String> needs = roadmap.getAccessibilityNeeds();
        boolean mobility = AccessibilityService.needsStepFree(needs);
        int people = roadmap.getPartySize() == null ? 1 : Math.max(1, roadmap.getPartySize());
        List<int[]> breaks = readBreaks(roadmap);
        int nextBreak = 0;
        int clock = minuteOf(roadmap.getArrivalTime());
        int departure = minuteOf(roadmap.getDepartureTime());
        Location current = roadmap.getEntrance() == null ? null : roadmap.getEntrance().getLocation();
        Integer lastCheckIn = null;

        for(Visit stop : visitRepository.findVisitsByRoadmapOrderByStopOrderAsc(roadmap)){
            Pavilion pavilion = stop.getPavilion();
            if(pavilion == null || pavilion.getLocation() == null){
                continue;
            }
            int walk = current == null ? 0 : walkMinutes(current, pavilion.getLocation(), needs);
            int start = clock + walk;
            while(nextBreak < breaks.size() && breaks.get(nextBreak)[0] <= start){
                start = start + breaks.get(nextBreak)[1];
                nextBreak++;
            }
            if(stop.getIsVisited() && stop.getVisitedAt() != null && stop.getVisitedAt().toLocalDate().equals(roadmap.getVisitDate())){
                int checkedIn = minuteOf(stop.getVisitedAt().toLocalTime());
                if(trusted(checkedIn, start, departure, lastCheckIn, walk)){
                    start = checkedIn;
                }
                lastCheckIn = checkedIn;
            }
            int end = start + visitMinutes(pavilion, mobility);
            stays.add(new Stay(pavilion.getId(), stop.getId(), timeOf(start), timeOf(end), people));
            clock = end;
            current = pavilion.getLocation();
        }
        return stays;
    }

    // a check-in corrects the timeline only if it is close to the plan, before leaving,
    // and not right after another check-in (many check-ins at once = logged later, from home)
    private boolean trusted(int checkedIn, int planned, int departure, Integer lastCheckIn, int walk){
        if(checkedIn > departure + 30){
            return false;
        }
        if(Math.abs(checkedIn - planned) > 120){
            return false;
        }
        return lastCheckIn == null || checkedIn - lastCheckIn >= Math.max(1, walk - 2);
    }

    // AI breaks of the roadmap as [start minute, minutes], sorted by time
    private List<int[]> readBreaks(Roadmap roadmap){
        List<int[]> breaks = new ArrayList<>();
        if(roadmap.getAiBreaks() == null){
            return breaks;
        }
        try{
            for(Object item : objectMapper.readValue(roadmap.getAiBreaks(), List.class)){
                Map<?, ?> b = (Map<?, ?>) item;
                if(b.get("time") == null || !(b.get("minutes") instanceof Number n)){
                    continue;
                }
                breaks.add(new int[]{minuteOf(LocalTime.parse(b.get("time").toString())), n.intValue()});
            }
        }catch(Exception e){
            return new ArrayList<>();
        }
        breaks.sort(Comparator.comparingInt(b -> b[0]));
        return breaks;
    }

    // ===== people and queue =====
    // people expected in every pavilion for each 15 minute slot of the day, kept for one minute
    private synchronized Map<Integer, double[]> peopleForecast(LocalDate date){
        if(forecastPeople != null && date.equals(forecastDate) && forecastTime.isAfter(LocalDateTime.now().minusSeconds(60))){
            return forecastPeople;
        }
        Map<Integer, double[]> people = new HashMap<>();
        for(Roadmap roadmap : roadmapRepository.findRoadmapsByVisitDate(date)){
            for(Stay stay : timeline(roadmap)){
                double[] slots = people.computeIfAbsent(stay.pavilionId(), k -> new double[SLOTS]);
                int from = slotOf(stay.start());
                int to = Math.max(from, (minuteOf(stay.end()) - 1) / SLOT_MINUTES);
                for(int slot = from; slot <= to && slot < SLOTS; slot++){
                    slots[slot] += stay.people() * appFactor;
                }
            }
        }
        forecastDate = date;
        forecastTime = LocalDateTime.now();
        forecastPeople = people;
        return people;
    }

    // called after a roadmap changes, the next request counts again
    public synchronized void invalidate(){
        forecastPeople = null;
    }

    public int expectedPeople(Pavilion pavilion, LocalDate date, LocalTime time){
        double[] slots = peopleForecast(date).get(pavilion.getId());
        return slots == null ? 0 : (int) Math.round(slots[slotOf(time)]);
    }

    // queue minutes = people above the capacity / people leaving per minute (capacity / visit minutes)
    public int waitMinutes(Pavilion pavilion, LocalDate date, LocalTime time){
        ManualWait manual = manualWait(pavilion.getId(), LocalDateTime.of(date, time));
        if(manual != null){
            return manual.minutes();
        }
        int capacity = capacityOf(pavilion);
        double extra = expectedPeople(pavilion, date, time) - capacity;
        if(extra <= 0){
            return 0;
        }
        return (int) Math.min(180, Math.round(extra * visitMinutesOf(pavilion) / capacity));
    }

    public static String level(int waitMinutes){
        if(waitMinutes <= CALM_MAX){
            return "CALM";
        }
        return waitMinutes >= CROWDED_MIN ? "CROWDED" : "MODERATE";
    }

    private ManualWait manualWait(Integer pavilionId, LocalDateTime at){
        ManualWait manual = manualWaits.get(pavilionId);
        if(manual == null){
            return null;
        }
        if(manual.until().isBefore(LocalDateTime.now())){
            manualWaits.remove(pavilionId);
            return null;
        }
        return !at.isBefore(manual.from()) && at.isBefore(manual.until()) ? manual : null;
    }

    // ===== endpoints =====
    // every pavilion now, longest queue first
    public List<CrowdStatusResponse> getCrowdNow(){
        LocalDate today = LocalDate.now();
        LocalTime now = LocalTime.now();
        List<CrowdStatusResponse> result = new ArrayList<>();
        for(Pavilion pavilion : pavilionRepository.findAll()){
            int wait = waitMinutes(pavilion, today, now);
            result.add(new CrowdStatusResponse(pavilion.getId(), pavilion.getName(), wait, level(wait),
                    expectedPeople(pavilion, today, now), capacityOf(pavilion), manualWait(pavilion.getId(), LocalDateTime.now()) != null));
        }
        result.sort(Comparator.comparing(CrowdStatusResponse::getWaitMinutes).reversed());
        return result;
    }

    // queue now and every 15 minutes until the end of the day
    public CrowdPavilionResponse getPavilionCrowd(Integer pavilionId){
        Pavilion pavilion = pavilionRepository.findPavilionById(pavilionId);
        if(pavilion == null){
            throw new ApiException("Pavilion not found");
        }
        LocalDate today = LocalDate.now();
        LocalTime now = LocalTime.now();
        int waitNow = waitMinutes(pavilion, today, now);
        String calmAt = null;
        List<CrowdSlotResponse> slots = new ArrayList<>();
        for(int slot = slotOf(now); slot < SLOTS; slot++){
            LocalTime time = timeOf(slot * SLOT_MINUTES);
            int wait = waitMinutes(pavilion, today, time);
            slots.add(new CrowdSlotResponse(time.format(HH_MM), wait, level(wait)));
            if(calmAt == null && waitNow > CALM_MAX && slot > slotOf(now) && wait <= CALM_MAX){
                calmAt = time.format(HH_MM);
            }
        }
        return new CrowdPavilionResponse(pavilion.getId(), pavilion.getName(), waitNow, level(waitNow),
                capacityOf(pavilion), visitMinutesOf(pavilion), calmAt, slots);
    }

    public void setAppFactor(Double value){
        if(value == null || value < 1 || value > 50){
            throw new ApiException("factor must be between 1 and 50");
        }
        appFactor = value;
        invalidate();
    }

    // admin sets the queue of a pavilion from now for some minutes
    public void setManualWait(Integer pavilionId, Integer minutes, Integer duration){
        if(pavilionRepository.findPavilionById(pavilionId) == null){
            throw new ApiException("Pavilion not found");
        }
        if(minutes == null || minutes < 0 || minutes > 180){
            throw new ApiException("minutes must be between 0 and 180");
        }
        if(duration == null || duration < 5 || duration > 240){
            throw new ApiException("duration must be between 5 and 240 minutes");
        }
        LocalDateTime now = LocalDateTime.now();
        manualWaits.put(pavilionId, new ManualWait(minutes, now, now.plusMinutes(duration)));
    }

    public void clearManualWait(Integer pavilionId){
        if(manualWaits.remove(pavilionId) == null){
            throw new ApiException("this pavilion has no manual queue");
        }
    }

    // alerts the visitor got today
    public List<CrowdAlertResponse> getMyAlerts(Integer visitorId){
        LocalDate today = LocalDate.now();
        List<CrowdAlertResponse> result = new ArrayList<>();
        for(CrowdAlert alert : crowdAlertRepository.findCrowdAlertsByVisitorIdAndSentAtBetweenOrderBySentAtDesc(visitorId, today.atStartOfDay(), today.atTime(LocalTime.MAX))){
            Pavilion pavilion = pavilionRepository.findPavilionById(alert.getPavilionId());
            result.add(new CrowdAlertResponse(alert.getId(), alert.getRoadmapId(), alert.getPavilionId(),
                    pavilion == null ? null : pavilion.getName(), alert.getSentAt(),
                    alert.getCalmAt() == null ? null : alert.getCalmAt().format(HH_MM),
                    alert.getWaitNow(), alert.getWaitCalm(), alert.getDelivered(), alert.getAccepted()));
        }
        return result;
    }

    // ===== WhatsApp alerts =====
    // for every roadmap of today with alerts on: a pavilion planned later is crowded now and will be calm in 15 minutes,
    // so the visitor gets a message 15 minutes before. one alert per pavilion, 3 a day, 20 minutes apart
    @Transactional
    public int checkAlerts(){
        LocalDateTime now = LocalDateTime.now();
        LocalDate today = now.toLocalDate();
        LocalTime time = now.toLocalTime();
        if(time.isAfter(LocalTime.of(23, 0))){
            return 0;
        }
        LocalTime soon = time.plusMinutes(ALERT_AHEAD_MINUTES);
        LocalTime later = soon.plusMinutes(SLOT_MINUTES);
        int sent = 0;

        for(Roadmap roadmap : roadmapRepository.findRoadmapsByVisitDate(today)){
            if(!Boolean.TRUE.equals(roadmap.getWhatsappAlerts())){
                continue;
            }
            if(time.isBefore(roadmap.getArrivalTime().minusMinutes(30)) || time.isAfter(roadmap.getDepartureTime())){
                continue;
            }
            Visitor visitor = roadmap.getVisitor();
            String phone = visitor.getUser() == null ? null : visitor.getUser().getPhone();
            if(phone == null || phone.isBlank()){
                continue;
            }
            List<CrowdAlert> todayAlerts = crowdAlertRepository.findCrowdAlertsByVisitorIdAndSentAtBetweenOrderBySentAtDesc(
                    visitor.getId(), today.atStartOfDay(), today.atTime(LocalTime.MAX));
            if(todayAlerts.size() >= MAX_ALERTS_PER_DAY){
                continue;
            }
            if(!todayAlerts.isEmpty() && todayAlerts.get(0).getSentAt().isAfter(now.minusMinutes(MINUTES_BETWEEN_ALERTS))){
                continue;
            }

            Map<Integer, Visit> stops = new HashMap<>();
            for(Visit stop : visitRepository.findVisitsByRoadmapOrderByStopOrderAsc(roadmap)){
                stops.put(stop.getId(), stop);
            }
            boolean nextStop = true;
            for(Stay stay : timeline(roadmap)){
                Visit stop = stops.get(stay.visitId());
                if(stop == null || stop.getIsVisited()){
                    continue;
                }
                if(nextStop){
                    nextStop = false; // the visitor is going there anyway
                    continue;
                }
                if(!stay.start().isAfter(later) || crowdAlertRepository.existsByRoadmapIdAndPavilionId(roadmap.getId(), stay.pavilionId())){
                    continue;
                }
                Pavilion pavilion = stop.getPavilion();
                int waitNow = waitMinutes(pavilion, today, time);
                int waitSoon = waitMinutes(pavilion, today, soon);
                int waitLater = waitMinutes(pavilion, today, later);
                if(waitNow < CROWDED_MIN || waitSoon > CALM_MAX || waitLater > CALM_MAX){
                    continue;
                }
                int waitPlanned = waitMinutes(pavilion, today, stay.start());
                String message = alertMessage(visitor.getPreferredLanguage(), pavilion.getName(), soon, waitSoon, waitNow, stay.start(), waitPlanned);

                CrowdAlert alert = new CrowdAlert();
                alert.setVisitorId(visitor.getId());
                alert.setRoadmapId(roadmap.getId());
                alert.setPavilionId(pavilion.getId());
                alert.setSentAt(now);
                alert.setCalmAt(soon);
                alert.setWaitNow(waitNow);
                alert.setWaitCalm(waitSoon);
                alert.setAccepted(false);
                alert.setDelivered(whatsAppService.sendText(phone, message));
                crowdAlertRepository.save(alert);
                sent++;
                break; // one alert for this visitor in each check
            }
        }
        return sent;
    }

    private String alertMessage(String language, String pavilion, LocalTime calmAt, int waitCalm, int waitNow, LocalTime planned, int waitPlanned){
        if("EN".equals(language)){
            String plannedWait = waitPlanned > CALM_MAX ? " (about " + waitPlanned + " min queue at that time)" : "";
            return "🟢 *Wijha*\n"
                    + "In 15 minutes (at " + calmAt.format(HH_MM) + ") " + pavilion + " in your plan is expected to be calm: about "
                    + waitCalm + " min queue instead of " + waitNow + ".\n"
                    + "It is planned at " + planned.format(HH_MM) + plannedWait + ".\n"
                    + "Want it as your next stop? Open the app > My plan > \"Move it up\".";
        }
        String plannedWait = waitPlanned > CALM_MAX ? " (والانتظار وقتها متوقع ~" + waitPlanned + " دقيقة)" : "";
        return "🟢 *وجهة*\n"
                + "بعد ربع ساعة (الساعة " + calmAt.format(HH_MM) + ") " + pavilion + " اللي في خطتك متوقع يخف، والانتظار ~"
                + waitCalm + " دقائق بدل ~" + waitNow + ".\n"
                + "هو في خطتك الساعة " + planned.format(HH_MM) + plannedWait + ".\n"
                + "تبي نخليه محطتك الجاية؟ افتح التطبيق ← خطتي ← \"قدّمه\".";
    }

    // ===== helpers =====
    public static int capacityOf(Pavilion pavilion){
        return pavilion.getCapacity() == null || pavilion.getCapacity() < 1 ? DEFAULT_CAPACITY : pavilion.getCapacity();
    }

    public static int visitMinutesOf(Pavilion pavilion){
        return pavilion.getAvgVisitMinutes() == null || pavilion.getAvgVisitMinutes() < 1 ? DEFAULT_VISIT_MINUTES : pavilion.getAvgVisitMinutes();
    }

    // a trip with a mobility need stays 25% longer
    public static int visitMinutes(Pavilion pavilion, boolean mobility){
        int minutes = visitMinutesOf(pavilion);
        return mobility ? (int) Math.round(minutes * 1.25) : minutes;
    }

    // map units of walking to minutes
    public static int walkMinutesFor(double units){
        return (int) Math.round(units * METERS_PER_UNIT / METERS_PER_MINUTE);
    }

    // walking minutes between two places (Dijkstra for the trip needs), kept for 30 minutes
    public int walkMinutes(Location from, Location to, Set<String> needs){
        if(walkCacheTime.isBefore(LocalDateTime.now().minusMinutes(30))){
            walkCache.clear();
            walkCacheTime = LocalDateTime.now();
        }
        boolean mobility = AccessibilityService.needsStepFree(needs);
        String key = from.getId() + "-" + to.getId() + (mobility ? "-m" : "");
        Integer cached = walkCache.get(key);
        if(cached != null){
            return cached;
        }
        double units;
        try{
            units = pathService.getShortestPath(from.getId(), to.getId(), needs).getTotalDistance();
        }catch(ApiException e){
            try{
                units = pathService.getShortestPath(from.getId(), to.getId()).getTotalDistance();
            }catch(ApiException noPath){
                units = Math.hypot(to.getX() - from.getX(), to.getY() - from.getY());
            }
        }
        int minutes = walkMinutesFor(units);
        walkCache.put(key, minutes);
        return minutes;
    }

    private static int minuteOf(LocalTime time){
        return time.getHour() * 60 + time.getMinute();
    }

    private static int slotOf(LocalTime time){
        return Math.min(SLOTS - 1, minuteOf(time) / SLOT_MINUTES);
    }

    // minutes of the day to a time, after midnight stays at 23:59
    private static LocalTime timeOf(int minute){
        if(minute >= 24 * 60){
            return LocalTime.of(23, 59);
        }
        return LocalTime.of(Math.max(0, minute) / 60, Math.max(0, minute) % 60);
    }
}

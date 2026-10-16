package com.example.expo.Service;

import com.example.expo.Api.ApiException;
import com.example.expo.Dto.Out.RoadmapPdfModel;
import com.example.expo.Dto.Out.RoadmapRouteResponse;
import com.example.expo.Model.Entrance;
import com.example.expo.Model.Location;
import com.example.expo.Model.Pavilion;
import com.example.expo.Model.Roadmap;
import com.example.expo.Model.Visit;
import com.example.expo.Repository.LocationRepository;
import com.example.expo.Repository.RoadmapRepository;
import com.example.expo.Repository.VisitRepository;
import com.openhtmltopdf.bidi.support.ICUBidiReorderer;
import com.openhtmltopdf.bidi.support.ICUBidiSplitter;
import com.openhtmltopdf.outputdevice.helper.BaseRendererBuilder;
import com.openhtmltopdf.pdfboxout.PdfRendererBuilder;
import com.openhtmltopdf.svgsupport.BatikSVGDrawer;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.thymeleaf.TemplateEngine;
import org.thymeleaf.context.Context;
import org.thymeleaf.templatemode.TemplateMode;
import org.thymeleaf.templateresolver.ClassLoaderTemplateResolver;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageOutputStream;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.text.NumberFormat;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Locale;
import java.util.Map;

// makes the roadmap PDF the visitor can share: Thymeleaf fills templates/journey.xhtml, openhtmltopdf turns it into a PDF
@Service
@RequiredArgsConstructor
public class JourneyPdfService {

    private final RoadmapRepository roadmapRepository;
    private final VisitRepository visitRepository;
    private final LocationRepository locationRepository;
    private final PathService pathService;

    // how many real meters one map unit is (the map is 0-1000). Not set = the distance card is left out of the PDF.
    // set it in application-local.properties: expo.map.meters-per-unit=2.5
    @Value("${expo.map.meters-per-unit:#{null}}")
    private Double metersPerUnit;

    private static final Locale AR = Locale.forLanguageTag("ar");
    private static final int MAP_WIDTH_PX = 600;

    private final TemplateEngine engine = createEngine();
    private volatile String mapImageDataUri; // the map image shrunk once, a 3 MB png in every PDF would be slow

    @Transactional(readOnly = true)
    public byte[] getRoadmapPdf(Integer visitorId, Integer roadmapId){
        Roadmap roadmap = roadmapRepository.findRoadmapById(roadmapId);
        // only the owner of the roadmap can download it
        if(roadmap == null || !roadmap.getVisitor().getId().equals(visitorId)){
            throw new ApiException("roadmap not found");
        }
        // same route the app draws: entrance -> every stop -> nearest exit
        RoadmapRouteResponse route = pathService.getRoadmapRouteFromEntrance(visitorId, roadmapId);

        Context context = new Context(AR);
        context.setVariable("journey", buildModel(roadmap, route));
        context.setVariable("mapImage", getMapImage());
        context.setVariable("generatedAt", java.time.LocalDate.now().format(DateTimeFormatter.ofPattern("d MMMM yyyy", AR)));
        context.setVariable("labels", arabicLabels());

        return toPdf(engine.process("journey", context));
    }

    // ===== model =====

    private RoadmapPdfModel buildModel(Roadmap roadmap, RoadmapRouteResponse route){
        MapBounds bounds = getMapBounds();
        DateTimeFormatter time = DateTimeFormatter.ofPattern("h:mm a", AR);

        List<RoadmapPdfModel.StopView> stops = new ArrayList<>();
        for(Visit visit : visitRepository.findVisitsByRoadmapOrderByStopOrderAsc(roadmap)){
            Pavilion pavilion = visit.getPavilion();
            Location location = pavilion.getLocation();
            stops.add(new RoadmapPdfModel.StopView(
                    visit.getStopOrder(),
                    pavilion.getName(),
                    pavilion.getZone() == null ? null : pavilion.getZone().getName(),
                    visit.getVisitedAt() == null ? null : visit.getVisitedAt().format(time),
                    Boolean.TRUE.equals(visit.getIsVisited()) ? "STAMPED" : "PLANNED",
                    location == null ? null : bounds.percentX(location),
                    location == null ? null : bounds.percentY(location)));
        }

        // the walking line, every point of the route (not only the pavilions)
        StringBuilder points = new StringBuilder();
        for(Location point : route.getRoute()){
            if(points.length() > 0){
                points.append(' ');
            }
            points.append(bounds.percentX(point)).append(',').append(bounds.percentY(point));
        }

        List<RoadmapPdfModel.GateView> gates = new ArrayList<>();
        Entrance entrance = roadmap.getEntrance();
        if(entrance != null && entrance.getLocation() != null){
            gates.add(new RoadmapPdfModel.GateView("دخول", bounds.percentX(entrance.getLocation()), bounds.percentY(entrance.getLocation())));
        }
        // the route ends at the exit gate
        if(route.getExitEntrance() != null && !route.getRoute().isEmpty()){
            Location exit = route.getRoute().get(route.getRoute().size() - 1);
            gates.add(new RoadmapPdfModel.GateView("خروج", bounds.percentX(exit), bounds.percentY(exit)));
        }

        String distanceKm = null;
        if(metersPerUnit != null && route.getTotalDistance() != null){
            distanceKm = String.format(Locale.ROOT, "%.1f", route.getTotalDistance() * metersPerUnit / 1000.0);
        }

        // the map box has the same ratio as the map bounds, so the picture is stretched exactly like in the web map
        int mapHeight = (int) Math.round(MAP_WIDTH_PX * bounds.height() / bounds.width());

        RoadmapPdfModel model = new RoadmapPdfModel();
        boolean group = "GROUP".equals(roadmap.getPartyType());
        model.setTitle(group ? "حيّاكم الله في إكسبو الرياض" : "حيّاك الله في إكسبو الرياض");
        model.setPartyLine(group ? buildPartyLine(roadmap) : null);
        model.setClosingMessage(group ? "نتمنى لكم رحلة سعيدة!" : "نتمنى لك رحلة سعيدة!");
        model.setDateLabel(roadmap.getVisitDate().format(DateTimeFormatter.ofPattern("EEEE d MMMM", AR)));
        model.setDepartureTime(roadmap.getDepartureTime().format(time));
        model.setDistanceKm(distanceKm);
        model.setEntranceName(entrance == null ? null : entrance.getName());
        model.setExitName(route.getExitEntrance());
        model.setStopsCount(stops.size());
        model.setMapWidth(MAP_WIDTH_PX);
        model.setMapHeight(mapHeight);
        model.setRoutePoints(points.toString());
        model.setStops(stops);
        model.setGates(gates);
        return model;
    }

    // "companions: N" (the visitor is one of the party) and "with children" when child rest breaks were asked for.
    // The roadmap does not store how many children, only that there are some.
    private String buildPartyLine(Roadmap roadmap){
        List<String> parts = new ArrayList<>();
        int companions = roadmap.getPartySize() == null ? 0 : roadmap.getPartySize() - 1;
        if(companions > 0){
            parts.add("عدد المرافقين: " + NumberFormat.getIntegerInstance(AR).format(companions));
        }
        if(Boolean.TRUE.equals(roadmap.getIncludeChildRestBreaks())){
            parts.add("مع أطفال");
        }
        return parts.isEmpty() ? null : String.join(" | ", parts);
    }

    // ======================= map =======================

    // same box the web map uses (route3d.html): every location in the data plus a margin, the picture is stretched over it
    private MapBounds getMapBounds(){
        double minX = Double.MAX_VALUE, maxX = -Double.MAX_VALUE, minY = Double.MAX_VALUE, maxY = -Double.MAX_VALUE;
        for(Location location : locationRepository.findAll()){
            minX = Math.min(minX, location.getX());
            maxX = Math.max(maxX, location.getX());
            minY = Math.min(minY, location.getY());
            maxY = Math.max(maxY, location.getY());
        }
        if(minX > maxX){
            throw new ApiException("the map has no locations yet");
        }
        return new MapBounds(minX - 90, maxX + 90, minY - 60, maxY + 60);
    }

    private record MapBounds(double minX, double maxX, double minY, double maxY){
        double width(){ return maxX - minX; }
        double height(){ return maxY - minY; }
        String percentX(Location location){ return String.format(Locale.ROOT, "%.2f", (location.getX() - minX) / width() * 100); }
        String percentY(Location location){ return String.format(Locale.ROOT, "%.2f", (location.getY() - minY) / height() * 100); }
    }

    // static/expo-map.png as a small jpeg data uri, made once and kept
    private String getMapImage(){
        if(mapImageDataUri != null){
            return mapImageDataUri;
        }
        try(InputStream in = new ClassPathResource("static/expo-map.png").getInputStream()){
            BufferedImage original = ImageIO.read(in);
            int width = 1000;
            int height = Math.round(width * (float) original.getHeight() / original.getWidth());
            BufferedImage small = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
            Graphics2D g = small.createGraphics();
            g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC);
            g.drawImage(original, 0, 0, width, height, null);
            g.dispose();

            ImageWriter writer = ImageIO.getImageWritersByFormatName("jpg").next();
            ImageWriteParam param = writer.getDefaultWriteParam();
            param.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
            param.setCompressionQuality(0.8f);
            ByteArrayOutputStream bytes = new ByteArrayOutputStream();
            try(ImageOutputStream out = ImageIO.createImageOutputStream(bytes)){
                writer.setOutput(out);
                writer.write(null, new IIOImage(small, null, null), param);
            }finally{
                writer.dispose();
            }
            mapImageDataUri = "data:image/jpeg;base64," + Base64.getEncoder().encodeToString(bytes.toByteArray());
            return mapImageDataUri;
        }catch(Exception e){
            // no map picture is not a reason to fail, the pins and route are drawn on a plain dark box
            return null;
        }
    }

    // ===== pdf =====

    private static TemplateEngine createEngine(){
        ClassLoaderTemplateResolver resolver = new ClassLoaderTemplateResolver();
        resolver.setPrefix("templates/");
        resolver.setSuffix(".xhtml");
        resolver.setTemplateMode(TemplateMode.XML); // the output has to be well formed XHTML for openhtmltopdf
        resolver.setCharacterEncoding("UTF-8");
        resolver.setCacheable(true);
        TemplateEngine engine = new TemplateEngine();
        engine.setTemplateResolver(resolver);
        return engine;
    }

    private byte[] toPdf(String xhtml){
        try(ByteArrayOutputStream out = new ByteArrayOutputStream()){
            PdfRendererBuilder builder = new PdfRendererBuilder();
            builder.useFastMode();
            // arabic: ICU4J joins the letters and puts the text right to left
            builder.useUnicodeBidiSplitter(new ICUBidiSplitter.ICUBidiSplitterFactory());
            builder.useUnicodeBidiReorderer(new ICUBidiReorderer());
            builder.defaultTextDirection(BaseRendererBuilder.TextDirection.RTL);
            builder.useSVGDrawer(new BatikSVGDrawer()); // the logo and the route line are inline svg
            builder.useFont(() -> font("/fonts/Cairo-Regular.ttf"), "Cairo", 400, BaseRendererBuilder.FontStyle.NORMAL, true);
            builder.useFont(() -> font("/fonts/Cairo-Bold.ttf"), "Cairo", 700, BaseRendererBuilder.FontStyle.NORMAL, true);
            builder.withHtmlContent(xhtml, null);
            builder.toStream(out);
            builder.run();
            return out.toByteArray();
        }catch(Exception e){
            throw new ApiException("could not create the PDF");
        }
    }

    private InputStream font(String path){
        return JourneyPdfService.class.getResourceAsStream(path);
    }

    private static Map<String, Object> arabicLabels(){
        return Map.ofEntries(
                Map.entry("brand", "وجهة"),
                Map.entry("brandTag", "مسارك في إكسبو 2030 الرياض"),
                Map.entry("kicker", "خطة الرحلة"),
                Map.entry("enterFrom", "الدخول من"),
                Map.entry("exitFrom", "الخروج من"),
                Map.entry("stops", "محطات"),
                Map.entry("stopsLabel", "عدد الأجنحة في الرحلة"),
                Map.entry("km", "كم"),
                Map.entry("distanceLabel", "مسافة المشي التقريبية"),
                Map.entry("departureLabel", "وقت المغادرة"),
                Map.entry("mapTitle", "خريطة المسار"),
                Map.entry("legendStamped", "تم الختم"),
                Map.entry("legendPlanned", "مخطط"),
                Map.entry("legendGate", "البوابات"),
                Map.entry("stopsTitle", "محطات الرحلة"),
                Map.entry("generatedBy", "أُنشئ عبر وجهة"),
                Map.entry("status", Map.of("STAMPED", "تم الختم", "PLANNED", "مخطط")));
    }
}

package com.example.expo.Service;

import com.example.expo.Api.ApiException;
import com.example.expo.Dto.In.AccessibilityUpdateRequest;
import com.example.expo.Dto.Out.AccessibilityWarningResponse;
import com.example.expo.Dto.Out.PavilionAccessibilityResponse;
import com.example.expo.Model.Pavilion;
import com.example.expo.Model.PavilionAccessibility;
import com.example.expo.Model.Review;
import com.example.expo.Repository.PavilionAccessibilityRepository;
import com.example.expo.Repository.PavilionRepository;
import com.example.expo.Repository.ReviewRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

// accessibility of the pavilions for the needs of a trip (wheelchair, hearing ...)
@Service
@RequiredArgsConstructor
public class AccessibilityService {
    private final PavilionAccessibilityRepository pavilionAccessibilityRepository;
    private final PavilionRepository pavilionRepository;
    private final ReviewRepository reviewRepository;

    public static final List<String> NEEDS = List.of("WHEELCHAIR", "LIMITED_MOBILITY", "VISUAL", "HEARING", "SENSORY", "STROLLER_ELDERLY");

    // these needs cannot use stairs, so the walk uses step free paths and prefers the shade
    public static final Set<String> MOBILITY_NEEDS = Set.of("WHEELCHAIR", "LIMITED_MOBILITY", "STROLLER_ELDERLY");

    public static boolean needsStepFree(Collection<String> needs){
        if(needs == null){
            return false;
        }
        for(String need : needs){
            if(MOBILITY_NEEDS.contains(need)){
                return true;
            }
        }
        return false;
    }

    // ACCESSIBLE, PARTIAL, NOT_ACCESSIBLE, or UNKNOWN when the pavilion has no data for this need
    public String statusFor(Pavilion pavilion, String need){
        PavilionAccessibility row = rowFor(pavilion, need);
        return row == null ? "UNKNOWN" : row.getStatus();
    }

    private PavilionAccessibility rowFor(Pavilion pavilion, String need){
        if(pavilion.getAccessibility() == null){
            return null;
        }
        for(PavilionAccessibility row : pavilion.getAccessibility()){
            if(row.getNeedType().equals(need)){
                return row;
            }
        }
        return null;
    }

    // can be suggested for the trip: no need is NOT_ACCESSIBLE and every need has data
    public boolean isSuitable(Pavilion pavilion, Collection<String> needs){
        if(needs == null || needs.isEmpty()){
            return true;
        }
        for(String need : needs){
            String status = statusFor(pavilion, need);
            if(status.equals("NOT_ACCESSIBLE") || status.equals("UNKNOWN")){
                return false;
            }
        }
        return true;
    }

    public boolean isFullyAccessible(Pavilion pavilion, Collection<String> needs){
        if(needs == null || needs.isEmpty()){
            return true;
        }
        for(String need : needs){
            if(!statusFor(pavilion, need).equals("ACCESSIBLE")){
                return false;
            }
        }
        return true;
    }

    // the needs of the trip this pavilion does not fully serve, shown on the stop
    public List<AccessibilityWarningResponse> warnings(Pavilion pavilion, Collection<String> needs){
        List<AccessibilityWarningResponse> warnings = new ArrayList<>();
        if(needs == null){
            return warnings;
        }
        for(String need : NEEDS){
            if(!needs.contains(need)){
                continue;
            }
            PavilionAccessibility row = rowFor(pavilion, need);
            if(row == null){
                warnings.add(new AccessibilityWarningResponse(need, "UNKNOWN", null, null));
            }else if(!row.getStatus().equals("ACCESSIBLE")){
                warnings.add(new AccessibilityWarningResponse(need, row.getStatus(), row.getNote(), row.getNoteAr()));
            }
        }
        return warnings;
    }

    // short text for the AI prompt, for example "WHEELCHAIR=ACCESSIBLE, SENSORY=PARTIAL"
    public String describe(Pavilion pavilion, Collection<String> needs){
        List<String> parts = new ArrayList<>();
        for(String need : NEEDS){
            if(needs.contains(need)){
                parts.add(need + "=" + statusFor(pavilion, need));
            }
        }
        return String.join(", ", parts);
    }

    // pavilion page: every need with the official status and the verdicts of the visitors who had that need
    public List<PavilionAccessibilityResponse> pavilionAccessibility(Pavilion pavilion){
        List<Review> reviews = reviewRepository.findReviewsByPavilion(pavilion);
        List<PavilionAccessibilityResponse> result = new ArrayList<>();
        for(String need : NEEDS){
            PavilionAccessibility row = rowFor(pavilion, need);
            long suitable = 0, partial = 0, notSuitable = 0;
            for(Review review : reviews){
                if(review.getAccessibilityVerdict() == null || review.getAccessibilityNeeds() == null
                        || !review.getAccessibilityNeeds().contains(need)){
                    continue;
                }
                switch(review.getAccessibilityVerdict()){
                    case "SUITABLE" -> suitable++;
                    case "PARTIAL" -> partial++;
                    default -> notSuitable++;
                }
            }
            result.add(new PavilionAccessibilityResponse(need, row == null ? "UNKNOWN" : row.getStatus(),
                    row == null ? null : row.getNote(), row == null ? null : row.getNoteAr(), suitable, partial, notSuitable));
        }
        return result;
    }

    // "WHEELCHAIR,SENSORY" -> the two needs, wrong names are refused
    public Set<String> parseNeeds(String text){
        Set<String> needs = new LinkedHashSet<>();
        if(text == null){
            return needs;
        }
        for(String part : text.split(",")){
            String need = part.trim().toUpperCase();
            if(need.isEmpty()){
                continue;
            }
            if(!NEEDS.contains(need)){
                throw new ApiException("accessibility need must be WHEELCHAIR, LIMITED_MOBILITY, VISUAL, HEARING, SENSORY or STROLLER_ELDERLY");
            }
            needs.add(need);
        }
        if(needs.isEmpty()){
            throw new ApiException("choose at least one accessibility need");
        }
        return needs;
    }

    // pavilions that can serve all the needs (fully or partly), fully accessible first
    public List<Pavilion> getAccessiblePavilions(String needsText){
        Set<String> needs = parseNeeds(needsText);
        List<Pavilion> full = new ArrayList<>();
        List<Pavilion> partly = new ArrayList<>();
        for(Pavilion pavilion : pavilionRepository.findAll()){
            if(isFullyAccessible(pavilion, needs)){
                full.add(pavilion);
            }else if(isSuitable(pavilion, needs)){
                partly.add(pavilion);
            }
        }
        full.addAll(partly);
        if(full.isEmpty()){
            throw new ApiException("no pavilions found for these needs");
        }
        return full;
    }

    // admin sets the status of one need, the row is created if the pavilion had none
    public void updatePavilionAccessibility(Integer pavilionId, String needType, AccessibilityUpdateRequest request){
        Pavilion pavilion = pavilionRepository.findPavilionById(pavilionId);
        if(pavilion == null){
            throw new ApiException("Pavilion not found");
        }
        String need = needType == null ? "" : needType.trim().toUpperCase();
        if(!NEEDS.contains(need)){
            throw new ApiException("accessibility need must be WHEELCHAIR, LIMITED_MOBILITY, VISUAL, HEARING, SENSORY or STROLLER_ELDERLY");
        }
        PavilionAccessibility row = pavilionAccessibilityRepository.findPavilionAccessibilityByPavilionAndNeedType(pavilion, need);
        if(row == null){
            row = new PavilionAccessibility();
            row.setPavilion(pavilion);
            row.setNeedType(need);
        }
        row.setStatus(request.getStatus());
        row.setNote(request.getNote());
        row.setNoteAr(request.getNoteAr());
        pavilionAccessibilityRepository.save(row);
    }
}

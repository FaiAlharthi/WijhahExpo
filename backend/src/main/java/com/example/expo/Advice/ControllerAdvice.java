package com.example.expo.Advice;

import com.example.expo.Api.ApiException;
import com.example.expo.Api.ApiResponse;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.InvalidDataAccessResourceUsageException;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.orm.ObjectOptimisticLockingFailureException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

@RestControllerAdvice
public class ControllerAdvice {
    @ExceptionHandler(ApiException.class)
    public ResponseEntity<?> ApiException(ApiException e){
        return ResponseEntity.status(400).body(new ApiResponse(e.getMessage()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<?> MethodArgumentNotValidException(MethodArgumentNotValidException e){
        return ResponseEntity.status(400).body(new ApiResponse(e.getFieldError().getDefaultMessage()));
    }
    //handle the validation side
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiResponse> handleUnreadableMessage(HttpMessageNotReadableException e) {
        return ResponseEntity.status(400).body(new ApiResponse(
                "Invalid or missing JSON request body. Check the JSON syntax, field types, and date formats"));
    }

    // handle if the entered id while he should not
    @ExceptionHandler(ObjectOptimisticLockingFailureException.class)
    public ResponseEntity<?> handleWritingId(ObjectOptimisticLockingFailureException e){
        return ResponseEntity.status(400).body(new ApiResponse(e.getMessage()));
    }

    //handle the database side constrain SQL
    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<?> handleDataIntegrity(DataIntegrityViolationException e){
        return ResponseEntity.status(400).body(new ApiResponse(e.getMessage()));
    }

    //for invalid type
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<?> handleTypeMismatch(MethodArgumentTypeMismatchException e){
        return ResponseEntity.status(400).body(new ApiResponse("Invalid value for " + e.getName()));
    }

    //for invalid type for mapping
    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<?> handleTypeMismatch(HttpRequestMethodNotSupportedException e){
        return ResponseEntity.status(400).body(new ApiResponse( e.getMessage() ));
    }

    //for invalid type for mapping
    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<?> handleTypeMismatch(NoResourceFoundException e){
        return ResponseEntity.status(400).body(new ApiResponse( e.getMessage() ));
    }


    @ExceptionHandler(InvalidDataAccessResourceUsageException.class)
    public ResponseEntity<ApiResponse> handleInvalidDataAccessResourceUsageException(InvalidDataAccessResourceUsageException exception) {
        return ResponseEntity.status(400).body(new ApiResponse("Database operation failed. Please contact support"));
    }
}

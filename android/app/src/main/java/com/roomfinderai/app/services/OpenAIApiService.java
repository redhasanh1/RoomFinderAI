package com.roomfinderai.app.services;

import retrofit2.Call;
import retrofit2.http.*;
import java.util.Map;

public interface OpenAIApiService {
    
    @POST("chat/completions")
    Call<Map<String, Object>> createChatCompletion(
        @Header("Authorization") String authorization,
        @Header("Content-Type") String contentType,
        @Body Map<String, Object> request
    );
}
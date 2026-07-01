package com.roomfinderai.app.api;

import com.roomfinderai.app.config.ApiConfig;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.logging.HttpLoggingInterceptor;
import retrofit2.Retrofit;
import retrofit2.converter.gson.GsonConverterFactory;
import java.util.concurrent.TimeUnit;

public class ApiClient {
    
    private static ApiClient instance;
    private ApiService apiService;
    private String authToken;
    
    private ApiClient() {
        buildApiService();
    }
    
    public static synchronized ApiClient getInstance() {
        if (instance == null) {
            instance = new ApiClient();
        }
        return instance;
    }
    
    public void setAuthToken(String token) {
        this.authToken = token;
        buildApiService(); // Rebuild with new token
    }
    
    private void buildApiService() {
        HttpLoggingInterceptor logging = new HttpLoggingInterceptor();
        logging.setLevel(HttpLoggingInterceptor.Level.BODY);
        
        OkHttpClient.Builder clientBuilder = new OkHttpClient.Builder()
            .addInterceptor(logging)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS);
        
        // Add auth interceptor if token exists
        if (authToken != null && !authToken.isEmpty()) {
            clientBuilder.addInterceptor(chain -> {
                Request original = chain.request();
                Request request = original.newBuilder()
                    .header("Authorization", "Bearer " + authToken)
                    .method(original.method(), original.body())
                    .build();
                return chain.proceed(request);
            });
        }
        
        OkHttpClient client = clientBuilder.build();
        
        String baseUrl = ApiConfig.getApiBaseUrl();
        
        Retrofit retrofit = new Retrofit.Builder()
            .baseUrl(baseUrl)
            .client(client)
            .addConverterFactory(GsonConverterFactory.create())
            .build();
        
        apiService = retrofit.create(ApiService.class);
    }
    
    public ApiService getApiService() {
        return apiService;
    }
    
    // Keep static method for backward compatibility
    public static ApiService getApiService_DEPRECATED() {
        return getInstance().getApiService();
    }
    
    public static Retrofit getClient() {
        return getInstance().getRetrofitClient();
    }
    
    private Retrofit getRetrofitClient() {
        HttpLoggingInterceptor logging = new HttpLoggingInterceptor();
        logging.setLevel(HttpLoggingInterceptor.Level.BODY);
        
        OkHttpClient.Builder clientBuilder = new OkHttpClient.Builder()
            .addInterceptor(logging)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS);
        
        if (authToken != null && !authToken.isEmpty()) {
            clientBuilder.addInterceptor(chain -> {
                Request original = chain.request();
                Request request = original.newBuilder()
                    .header("Authorization", "Bearer " + authToken)
                    .method(original.method(), original.body())
                    .build();
                return chain.proceed(request);
            });
        }
        
        OkHttpClient client = clientBuilder.build();
        String baseUrl = ApiConfig.getApiBaseUrl();
        
        return new Retrofit.Builder()
            .baseUrl(baseUrl)
            .client(client)
            .addConverterFactory(GsonConverterFactory.create())
            .build();
    }
}
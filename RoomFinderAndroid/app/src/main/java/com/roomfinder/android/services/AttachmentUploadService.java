package com.roomfinder.android.services;

import android.content.Context;
import android.net.Uri;
import android.util.Log;
import android.webkit.MimeTypeMap;
import com.roomfinder.android.utils.ApiKeys;

import java.io.InputStream;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.TimeUnit;
import okhttp3.*;

public class AttachmentUploadService {
    private static final String TAG = "AttachmentUploadService";
    
    // File size limits
    private static final long MAX_IMAGE_SIZE = 10 * 1024 * 1024; // 10MB
    private static final long MAX_DOCUMENT_SIZE = 50 * 1024 * 1024; // 50MB
    
    // Allowed file types
    private static final List<String> ALLOWED_IMAGE_TYPES = Arrays.asList(
        "image/jpeg", "image/png", "image/gif", "image/webp"
    );
    
    private static final List<String> ALLOWED_DOCUMENT_TYPES = Arrays.asList(
        "application/pdf",
        "application/msword",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    );
    
    private final Context context;
    private final OkHttpClient client;
    
    public AttachmentUploadService(Context context) {
        this.context = context;
        this.client = new OkHttpClient.Builder()
                .connectTimeout(60, TimeUnit.SECONDS)
                .readTimeout(120, TimeUnit.SECONDS)
                .writeTimeout(120, TimeUnit.SECONDS)
                .build();
    }
    
    public interface UploadCallback {
        void onSuccess(String publicUrl, String fileName, String mimeType);
        void onProgress(int percentage);
        void onError(String error);
    }
    
    public static class FileValidationResult {
        public final boolean isValid;
        public final String error;
        public final String mimeType;
        public final long fileSize;
        
        public FileValidationResult(boolean isValid, String error, String mimeType, long fileSize) {
            this.isValid = isValid;
            this.error = error;
            this.mimeType = mimeType;
            this.fileSize = fileSize;
        }
    }
    
    /**
     * Validate file before upload
     */
    public FileValidationResult validateFile(Uri fileUri) {
        try {
            // Get file size
            InputStream inputStream = context.getContentResolver().openInputStream(fileUri);
            if (inputStream == null) {
                return new FileValidationResult(false, "Cannot access file", null, 0);
            }
            
            long fileSize = inputStream.available();
            inputStream.close();
            
            // Get MIME type
            String mimeType = context.getContentResolver().getType(fileUri);
            if (mimeType == null) {
                // Fallback to extension-based detection
                String extension = MimeTypeMap.getFileExtensionFromUrl(fileUri.toString());
                mimeType = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);
            }
            
            if (mimeType == null) {
                return new FileValidationResult(false, "Cannot determine file type", null, fileSize);
            }
            
            // Validate file type and size
            if (ALLOWED_IMAGE_TYPES.contains(mimeType)) {
                if (fileSize > MAX_IMAGE_SIZE) {
                    return new FileValidationResult(false, "Image file too large (max 10MB)", mimeType, fileSize);
                }
            } else if (ALLOWED_DOCUMENT_TYPES.contains(mimeType)) {
                if (fileSize > MAX_DOCUMENT_SIZE) {
                    return new FileValidationResult(false, "Document file too large (max 50MB)", mimeType, fileSize);
                }
            } else {
                return new FileValidationResult(false, "File type not supported. Allowed: Images (JPEG, PNG, GIF, WebP), PDF, Word documents", mimeType, fileSize);
            }
            
            return new FileValidationResult(true, null, mimeType, fileSize);
            
        } catch (Exception e) {
            Log.e(TAG, "Error validating file", e);
            return new FileValidationResult(false, "Error accessing file: " + e.getMessage(), null, 0);
        }
    }
    
    /**
     * Upload listing photo to listing-media bucket (matches web app).
     */
    public void uploadListingPhoto(Uri fileUri, String fileName, UploadCallback callback) {
        uploadToBucket(fileUri, "listing-media", "Photos/" + fileName, callback);
    }

    /**
     * Upload file to Supabase Storage
     */
    public void uploadFile(Uri fileUri, String fileName, String conversationId, UploadCallback callback) {
        if (conversationId == null || conversationId.isEmpty()) {
            uploadListingPhoto(fileUri, fileName, callback);
            return;
        }
        uploadToBucket(fileUri, "chat-attachments", "conversations/" + conversationId + "/" + fileName, callback);
    }

    private void uploadToBucket(Uri fileUri, String bucketName, String uploadPath, UploadCallback callback) {
        new Thread(() -> {
            try {
                // Validate file first
                FileValidationResult validation = validateFile(fileUri);
                if (!validation.isValid) {
                    callback.onError(validation.error);
                    return;
                }
                
                callback.onProgress(10);
                
                // Read file bytes
                InputStream inputStream = context.getContentResolver().openInputStream(fileUri);
                if (inputStream == null) {
                    callback.onError("Cannot access file");
                    return;
                }
                
                // Read file into byte array
                java.io.ByteArrayOutputStream byteArrayOutputStream = new java.io.ByteArrayOutputStream();
                byte[] buffer = new byte[8192];
                int length;
                long totalRead = 0;
                
                while ((length = inputStream.read(buffer)) != -1) {
                    byteArrayOutputStream.write(buffer, 0, length);
                    totalRead += length;
                    
                    // Report progress
                    int progress = (int) (10 + (totalRead * 40 / validation.fileSize));
                    callback.onProgress(Math.min(progress, 50));
                }
                
                byte[] fileBytes = byteArrayOutputStream.toByteArray();
                inputStream.close();
                byteArrayOutputStream.close();
                
                callback.onProgress(60);
                
                String baseUrl = ApiKeys.SUPABASE_URL;
                if (baseUrl.endsWith("/")) {
                    baseUrl = baseUrl.substring(0, baseUrl.length() - 1);
                }
                String supabaseStorageUrl = baseUrl + "/storage/v1/object/" + bucketName + "/" + uploadPath;
                
                Log.d(TAG, "Uploading " + validation.mimeType + " file to: " + supabaseStorageUrl);
                
                // Create upload request
                RequestBody requestBody = RequestBody.create(
                    MediaType.parse(validation.mimeType), 
                    fileBytes
                );
                
                Request request = new Request.Builder()
                        .url(supabaseStorageUrl)
                        .post(requestBody)
                        .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                        .addHeader("Content-Type", validation.mimeType)
                        .addHeader("x-upsert", "true")
                        .build();
                
                callback.onProgress(80);
                
                Response response = client.newCall(request).execute();
                
                if (response.isSuccessful()) {
                    // Success: Generate public URL
                    String publicUrl = baseUrl + "/storage/v1/object/public/" + bucketName + "/" + uploadPath;
                    
                    Log.d(TAG, "File uploaded successfully to Supabase: " + publicUrl);
                    callback.onProgress(100);
                    String storedFileName = uploadPath.substring(uploadPath.lastIndexOf('/') + 1);
                    callback.onSuccess(publicUrl, storedFileName, validation.mimeType);
                    
                } else {
                    String errorBody = response.body() != null ? response.body().string() : "Unknown error";
                    Log.e(TAG, "Supabase upload failed: " + response.code() + " - " + errorBody);
                    callback.onError("Upload failed: " + response.code() + " " + response.message());
                }
                
                response.close();
                
            } catch (Exception e) {
                Log.e(TAG, "Error uploading file", e);
                callback.onError("Upload error: " + e.getMessage());
            }
        }).start();
    }
    
    /**
     * Generate file name with timestamp
     */
    public static String generateFileName(String originalName, String mimeType) {
        String timestamp = String.valueOf(System.currentTimeMillis());
        
        if (originalName != null && !originalName.isEmpty()) {
            // Extract extension from original name
            int dotIndex = originalName.lastIndexOf('.');
            if (dotIndex > 0) {
                String extension = originalName.substring(dotIndex);
                return "file_" + timestamp + extension;
            }
        }
        
        // Fallback based on MIME type
        String extension = getExtensionFromMimeType(mimeType);
        return "file_" + timestamp + extension;
    }
    
    private static String getExtensionFromMimeType(String mimeType) {
        switch (mimeType) {
            case "image/jpeg": return ".jpg";
            case "image/png": return ".png";
            case "image/gif": return ".gif";
            case "image/webp": return ".webp";
            case "application/pdf": return ".pdf";
            case "application/msword": return ".doc";
            case "application/vnd.openxmlformats-officedocument.wordprocessingml.document": return ".docx";
            default: return ".bin";
        }
    }
    
    /**
     * Check if file is an image
     */
    public static boolean isImageFile(String mimeType) {
        return mimeType != null && ALLOWED_IMAGE_TYPES.contains(mimeType);
    }
    
    /**
     * Check if file is a document
     */
    public static boolean isDocumentFile(String mimeType) {
        return mimeType != null && ALLOWED_DOCUMENT_TYPES.contains(mimeType);
    }
}
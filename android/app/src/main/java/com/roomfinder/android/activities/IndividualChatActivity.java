package com.roomfinder.android.activities;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.MediaStore;
import android.text.TextUtils;
import android.util.Log;
import android.widget.Toast;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.core.content.FileProvider;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import com.roomfinder.android.adapters.ChatAdapter;
import com.roomfinder.android.databinding.ActivityIndividualChatBinding;
import com.roomfinder.android.models.ChatMessage;
import com.roomfinder.android.models.Conversation;
import com.roomfinder.android.models.Listing;
import com.roomfinder.android.services.RealTimeChatService;
import com.roomfinder.android.services.AiNegotiationEngine;
import com.roomfinder.android.auth.AuthManager;
import com.roomfinder.android.utils.ApiKeys;
import com.roomfinder.android.services.AttachmentUploadService;
import com.roomfinder.android.services.ChatModerationService;

import java.io.File;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public class IndividualChatActivity extends AppCompatActivity implements RealTimeChatService.MessageListener {
    
    private static final String TAG = "IndividualChatActivity";
    
    // Request codes
    private static final int REQUEST_CAMERA_PERMISSION = 1001;
    private static final int REQUEST_STORAGE_PERMISSION = 1002;
    private static final int REQUEST_IMAGE_CAPTURE = 2001;
    private static final int REQUEST_IMAGE_PICK = 2002;
    private static final int REQUEST_DOCUMENT_PICK = 2003;
    
    private ActivityIndividualChatBinding binding;
    private ChatAdapter chatAdapter;
    private List<ChatMessage> messages = new ArrayList<>();
    
    // Real-time messaging
    private RealTimeChatService chatService;
    private String conversationId;
    private String currentUserEmail;
    private String otherUserEmail;
    private Listing currentListing;
    private boolean isLoadingMessages = false;
    
    // Intent data
    private String listingId;
    private String listingTitle;
    private String listingOwnerEmail;
    
    // Photo handling
    private Uri currentPhotoUri;
    private String currentPhotoPath;
    
    // Attachment service
    private AttachmentUploadService attachmentService;
    
    // Chat moderation service
    private ChatModerationService moderationService;
    
    // AI negotiation integration
    private String pendingMessageTemplate;
    private String conversationType;
    private AiNegotiationEngine negotiationEngine;
    private String negotiationId;
    private String negotiationStrategy;
    private boolean isAiNegotiationActive = false;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        binding = ActivityIndividualChatBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());
        
        // Get user authentication
        AuthManager authManager = AuthManager.getInstance(this);
        if (!authManager.isUserAuthenticated()) {
            Toast.makeText(this, "Please log in to use chat", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }
        
        currentUserEmail = authManager.getCurrentUser().getEmail();
        
        // Get intent data
        getIntentData();
        
        if (otherUserEmail == null) {
            Toast.makeText(this, "Error: Missing chat information", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }
        
        setupUI();
        initializeChatService();
        initializeServices();
    }
    
    private void getIntentData() {
        Intent intent = getIntent();
        
        // Check if this is an existing conversation
        conversationId = intent.getStringExtra("conversation_id");
        
        // Get listing and other user data
        listingId = intent.getStringExtra("listing_id");
        listingTitle = intent.getStringExtra("listing_title");
        listingOwnerEmail = intent.getStringExtra("owner_email");
        otherUserEmail = intent.getStringExtra("other_user_email");
        
        // Handle AI negotiation integration
        String landlordEmail = intent.getStringExtra("LANDLORD_EMAIL");
        String landlordName = intent.getStringExtra("LANDLORD_NAME");
        String propertyTitle = intent.getStringExtra("PROPERTY_TITLE");
        conversationType = intent.getStringExtra("CONVERSATION_TYPE");
        String aiGeneratedMessage = intent.getStringExtra("AI_GENERATED_MESSAGE");
        negotiationId = intent.getStringExtra("AI_NEGOTIATION_ID");
        negotiationStrategy = intent.getStringExtra("NEGOTIATION_STRATEGY");
        
        // If coming from AI negotiation, set up for real negotiation (only if we have negotiation ID)
        if ("AI_NEGOTIATION".equals(conversationType) && landlordEmail != null && negotiationId != null) {
            otherUserEmail = landlordEmail;
            listingTitle = propertyTitle != null ? propertyTitle : "Property Negotiation";
            isAiNegotiationActive = true;
            
            // Keep the real listing ID that was passed - don't override it
            // listingId is already set from line 120 above
            listingOwnerEmail = landlordEmail;
            
            Log.d(TAG, "AI Negotiation setup - landlord: " + landlordEmail + ", property: " + propertyTitle + ", listingId: " + listingId + ", negotiationId: " + negotiationId);
            
            // Pre-populate message input with AI-generated message
            if (aiGeneratedMessage != null && !aiGeneratedMessage.isEmpty()) {
                pendingMessageTemplate = aiGeneratedMessage;
                Log.d(TAG, "AI-generated message prepared for negotiation");
            }
        }
        // Legacy support for old LANDLORD_CONTACT type
        else if ("LANDLORD_CONTACT".equals(conversationType) && landlordEmail != null) {
            otherUserEmail = landlordEmail;
            listingTitle = propertyTitle != null ? propertyTitle : "Property Inquiry";
            // Keep the real listing ID - don't create a virtual one
            listingOwnerEmail = landlordEmail;
            
            String aiMessageTemplate = intent.getStringExtra("AI_MESSAGE_TEMPLATE");
            if (aiMessageTemplate != null && !aiMessageTemplate.isEmpty()) {
                pendingMessageTemplate = aiMessageTemplate;
            }
        }
        
        // If no explicit other_user_email, use owner_email
        if (otherUserEmail == null) {
            otherUserEmail = listingOwnerEmail;
        }
        
        // Create listing object if we have the data
        if (listingId != null && listingTitle != null) {
            currentListing = new Listing();
            currentListing.setId(listingId);
            currentListing.setTitle(listingTitle);
            currentListing.setUserEmail(listingOwnerEmail != null ? listingOwnerEmail : otherUserEmail);
            
            // For AI negotiation conversations, use the real listing data that was passed
            if ("AI_NEGOTIATION".equals(conversationType) || "LANDLORD_CONTACT".equals(conversationType)) {
                // The listing data is already set from the intent extras
                Log.d(TAG, "Using real listing for AI conversation: " + listingId);
            }
        }
        
        Log.d(TAG, "Intent data - listingId: " + listingId + ", otherUser: " + otherUserEmail + ", conversationId: " + conversationId);
    }
    
    private void setupUI() {
        // Set title based on conversation type
        if (isAiNegotiationActive) {
            binding.toolbar.setTitle("🤖 AI Negotiation - " + (listingTitle != null ? listingTitle : "Property"));
            binding.toolbar.setSubtitle("Real-time AI assistance active");
        } else if (listingTitle != null) {
            binding.toolbar.setTitle("Chat about " + listingTitle);
        } else {
            binding.toolbar.setTitle("Chat with " + getDisplayName(otherUserEmail));
        }
        
        // Setup RecyclerView
        chatAdapter = new ChatAdapter(messages, currentUserEmail);
        binding.messagesRecyclerView.setLayoutManager(new LinearLayoutManager(this));
        binding.messagesRecyclerView.setAdapter(chatAdapter);
        
        // Setup click listeners
        binding.sendButton.setOnClickListener(v -> sendMessage());
        binding.attachmentButton.setOnClickListener(v -> showAttachmentOptions());
        binding.toolbar.setNavigationOnClickListener(v -> finish());
        
        // Handle enter key in message input
        binding.messageInput.setOnEditorActionListener((v, actionId, event) -> {
            sendMessage();
            return true;
        });
        
        // Pre-populate message input with AI-generated message if available
        if (pendingMessageTemplate != null && !pendingMessageTemplate.isEmpty()) {
            binding.messageInput.setText(pendingMessageTemplate);
            binding.messageInput.setSelection(binding.messageInput.getText().length());
            
            if (isAiNegotiationActive) {
                Toast.makeText(this, "🤖 AI has crafted a strategic negotiation message for you!", Toast.LENGTH_LONG).show();
            } else {
                Toast.makeText(this, "💡 AI has prepared a professional message for you. Feel free to customize it!", Toast.LENGTH_LONG).show();
            }
            
            pendingMessageTemplate = null;
        }
    }
    
    private String getDisplayName(String email) {
        if (email == null) return "User";
        
        // Extract name from email (before @)
        int atIndex = email.indexOf('@');
        if (atIndex > 0) {
            return email.substring(0, atIndex);
        }
        return email;
    }
    
    private void initializeServices() {
        attachmentService = new AttachmentUploadService(this);
        moderationService = ChatModerationService.getInstance(this);
        
        // Initialize AI negotiation engine if this is an AI negotiation
        if (isAiNegotiationActive && negotiationId != null) {
            negotiationEngine = new AiNegotiationEngine();
            Log.d(TAG, "AI Negotiation Engine initialized for negotiation: " + negotiationId);
        }
    }
    
    private void initializeChatService() {
        chatService = RealTimeChatService.getInstance(this);
        chatService.initialize();
        
        if (conversationId != null) {
            // Existing conversation
            loadMessagesForConversation();
        } else if (currentListing != null) {
            // New conversation
            startNewConversation();
        } else {
            Toast.makeText(this, "Cannot start chat: Missing listing information", Toast.LENGTH_SHORT).show();
            finish();
        }
    }
    
    private void startNewConversation() {
        if (currentListing == null || otherUserEmail == null) {
            Toast.makeText(this, "Cannot start chat: Missing information", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }
        
        Log.d(TAG, "Starting new conversation for listing: " + currentListing.getId() + " with user: " + otherUserEmail);
        
        chatService.startConversation(currentListing, otherUserEmail, new RealTimeChatService.ConversationCallback() {
            @Override
            public void onSuccess(Conversation conversation) {
                conversationId = conversation.getId();
                Log.d(TAG, "Conversation started: " + conversationId);
                loadMessagesForConversation();
            }
            
            @Override
            public void onError(String error) {
                Log.e(TAG, "Failed to start conversation: " + error);
                Toast.makeText(IndividualChatActivity.this, "Failed to start chat: " + error, Toast.LENGTH_SHORT).show();
                finish();
            }
        });
    }
    
    private void loadMessagesForConversation() {
        if (conversationId == null || isLoadingMessages) return;
        
        isLoadingMessages = true;
        Log.d(TAG, "Loading messages for conversation: " + conversationId);
        
        // Register for real-time updates
        chatService.registerMessageListener(conversationId, this);
        
        // Load existing messages
        chatService.loadMessages(conversationId, new RealTimeChatService.MessagesCallback() {
            @Override
            public void onSuccess(List<ChatMessage> loadedMessages) {
                isLoadingMessages = false;
                runOnUiThread(() -> {
                    messages.clear();
                    messages.addAll(loadedMessages);
                    chatAdapter.notifyDataSetChanged();
                    scrollToBottom();
                    Log.d(TAG, "Loaded " + loadedMessages.size() + " messages");
                });
            }
            
            @Override
            public void onError(String error) {
                isLoadingMessages = false;
                runOnUiThread(() -> {
                    Log.e(TAG, "Failed to load messages: " + error);
                    Toast.makeText(IndividualChatActivity.this, "Failed to load messages", Toast.LENGTH_SHORT).show();
                });
            }
        });
    }
    
    private void sendMessage() {
        String messageText = binding.messageInput.getText().toString().trim();
        if (TextUtils.isEmpty(messageText) || conversationId == null) {
            return;
        }
        
        // Clear input immediately for better UX
        binding.messageInput.setText("");
        
        Log.d(TAG, "Sending message: " + messageText);
        
        // Send message through chat service
        chatService.sendMessage(conversationId, messageText, this);
        
        // If AI negotiation is active, analyze the message and provide assistance
        if (isAiNegotiationActive && negotiationEngine != null && negotiationId != null) {
            provideAiNegotiationAssistance(messageText);
        }
    }
    
    // Provide real-time AI assistance during negotiation
    private void provideAiNegotiationAssistance(String userMessage) {
        // Get the active negotiation
        AiNegotiationEngine.Negotiation negotiation = negotiationEngine.getNegotiation(negotiationId);
        if (negotiation == null) {
            Log.w(TAG, "No active negotiation found for ID: " + negotiationId);
            return;
        }
        
        // Analyze user's message and provide contextual assistance
        String analysisContext = "The user just sent this message to the landlord: '" + userMessage + "'. " +
                                "Provide brief strategic advice for the next steps in this negotiation. " +
                                "Keep response under 100 words and focus on actionable negotiation tips.";
        
        negotiationEngine.generateNegotiationMessage(negotiation, analysisContext, new AiNegotiationEngine.NegotiationCallback() {
            @Override
            public void onSuccess(String aiAdvice) {
                runOnUiThread(() -> {
                    // Add AI assistance message to the chat
                    ChatMessage aiAssistance = ChatMessage.createAiMessage(
                        "🤖 **AI Negotiation Assistant:**\n\n" + aiAdvice
                    );
                    messages.add(aiAssistance);
                    chatAdapter.notifyItemInserted(messages.size() - 1);
                    scrollToBottom();
                    
                    Log.d(TAG, "AI negotiation assistance provided");
                });
            }
            
            @Override
            public void onError(String error) {
                Log.e(TAG, "AI assistance failed: " + error);
                // Don't show error to user for assistance - it's not critical
            }
        });
    }
    
    private void scrollToBottom() {
        if (messages.size() > 0) {
            binding.messagesRecyclerView.scrollToPosition(messages.size() - 1);
        }
    }
    
    /**
     * Show attachment options dialog
     */
    private void showAttachmentOptions() {
        String[] options = {"Camera", "Photo Gallery", "Documents"};
        
        new MaterialAlertDialogBuilder(this)
                .setTitle("Add Attachment")
                .setItems(options, (dialog, which) -> {
                    switch (which) {
                        case 0:
                            openCamera();
                            break;
                        case 1:
                            openGallery();
                            break;
                        case 2:
                            openDocumentPicker();
                            break;
                    }
                })
                .setNegativeButton("Cancel", null)
                .show();
    }
    
    /**
     * Open camera to take a photo
     */
    private void openCamera() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) 
                != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, 
                    new String[]{Manifest.permission.CAMERA}, 
                    REQUEST_CAMERA_PERMISSION);
            return;
        }
        
        try {
            Intent takePictureIntent = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
            
            // Create the File where the photo should go
            File photoFile = createImageFile();
            if (photoFile != null) {
                currentPhotoUri = FileProvider.getUriForFile(this,
                        getPackageName() + ".fileprovider",
                        photoFile);
                takePictureIntent.putExtra(MediaStore.EXTRA_OUTPUT, currentPhotoUri);
                
                // Grant temporary permissions for the camera app
                takePictureIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                takePictureIntent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
                
                startActivityForResult(takePictureIntent, REQUEST_IMAGE_CAPTURE);
            } else {
                Toast.makeText(this, "Error creating photo file", Toast.LENGTH_SHORT).show();
            }
        } catch (Exception ex) {
            Log.e(TAG, "Error opening camera", ex);
            // Fallback: try to open camera without file output (will get thumbnail)
            try {
                Intent simpleCameraIntent = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
                startActivityForResult(simpleCameraIntent, REQUEST_IMAGE_CAPTURE);
            } catch (Exception e) {
                Toast.makeText(this, "No camera app available", Toast.LENGTH_SHORT).show();
            }
        }
    }
    
    /**
     * Open gallery to select a photo
     */
    private void openGallery() {
        // Check permissions based on Android version
        String permission;
        if (Build.VERSION.SDK_INT >= 33) { // Android 13 (API 33)
            permission = Manifest.permission.READ_MEDIA_IMAGES;
        } else {
            permission = Manifest.permission.READ_EXTERNAL_STORAGE;
        }
        
        if (ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, 
                    new String[]{permission}, 
                    REQUEST_STORAGE_PERMISSION);
            return;
        }
        
        try {
            // Try multiple approaches to open gallery
            Intent intent = null;
            
            // Method 1: Standard ACTION_PICK with MediaStore
            intent = new Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI);
            intent.setType("image/*");
            
            if (intent.resolveActivity(getPackageManager()) != null) {
                startActivityForResult(intent, REQUEST_IMAGE_PICK);
                return;
            }
            
            // Method 2: ACTION_GET_CONTENT (works with more apps)
            intent = new Intent(Intent.ACTION_GET_CONTENT);
            intent.setType("image/*");
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            
            if (intent.resolveActivity(getPackageManager()) != null) {
                startActivityForResult(Intent.createChooser(intent, "Select Photo"), REQUEST_IMAGE_PICK);
                return;
            }
            
            // Method 3: Open any file manager/gallery app
            intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.setType("image/*");
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            
            if (intent.resolveActivity(getPackageManager()) != null) {
                startActivityForResult(intent, REQUEST_IMAGE_PICK);
                return;
            }
            
            Toast.makeText(this, "No photo app available", Toast.LENGTH_SHORT).show();
            
        } catch (Exception e) {
            Log.e(TAG, "Error opening gallery", e);
            Toast.makeText(this, "Error opening photo gallery", Toast.LENGTH_SHORT).show();
        }
    }
    
    /**
     * Open document picker for PDF and Word documents
     */
    private void openDocumentPicker() {
        try {
            Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType("*/*");
            
            // Specify allowed MIME types
            String[] mimeTypes = {
                "application/pdf",
                "application/msword",
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            };
            intent.putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes);
            
            if (intent.resolveActivity(getPackageManager()) != null) {
                startActivityForResult(Intent.createChooser(intent, "Select Document"), REQUEST_DOCUMENT_PICK);
            } else {
                Toast.makeText(this, "No document picker available", Toast.LENGTH_SHORT).show();
            }
        } catch (Exception e) {
            Log.e(TAG, "Error opening document picker", e);
            Toast.makeText(this, "Error opening document picker", Toast.LENGTH_SHORT).show();
        }
    }
    
    /**
     * Create a temporary file for camera photo
     */
    private File createImageFile() throws IOException {
        // Create an image file name
        String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(new Date());
        String imageFileName = "JPEG_" + timeStamp + "_";
        File storageDir = getExternalFilesDir("Pictures");
        File image = File.createTempFile(
                imageFileName,  /* prefix */
                ".jpg",         /* suffix */
                storageDir      /* directory */
        );
        
        // Save a file: path for use with ACTION_VIEW intents
        currentPhotoPath = image.getAbsolutePath();
        return image;
    }
    
    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        
        switch (requestCode) {
            case REQUEST_CAMERA_PERMISSION:
                if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    openCamera();
                } else {
                    Toast.makeText(this, "Camera permission required to take photos", Toast.LENGTH_SHORT).show();
                }
                break;
            case REQUEST_STORAGE_PERMISSION:
                if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    openGallery();
                } else {
                    String message = Build.VERSION.SDK_INT >= 33 ? 
                        "Media access permission required to select photos" : 
                        "Storage permission required to select photos";
                    Toast.makeText(this, message, Toast.LENGTH_LONG).show();
                }
                break;
        }
    }
    
    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        
        if (resultCode == Activity.RESULT_OK) {
            switch (requestCode) {
                case REQUEST_IMAGE_CAPTURE:
                    // Check if we have a file URI (full image)
                    if (currentPhotoUri != null) {
                        handlePhotoSelected(currentPhotoUri);
                    } 
                    // Fallback: check if we got a bitmap thumbnail
                    else if (data != null && data.getExtras() != null) {
                        android.graphics.Bitmap thumbnail = (android.graphics.Bitmap) data.getExtras().get("data");
                        if (thumbnail != null) {
                            // Save thumbnail to temporary file
                            Uri thumbnailUri = saveBitmapToFile(thumbnail);
                            if (thumbnailUri != null) {
                                handlePhotoSelected(thumbnailUri);
                            } else {
                                Toast.makeText(this, "Error processing camera photo", Toast.LENGTH_SHORT).show();
                            }
                        }
                    } else {
                        Toast.makeText(this, "No photo captured", Toast.LENGTH_SHORT).show();
                    }
                    break;
                case REQUEST_IMAGE_PICK:
                    if (data != null && data.getData() != null) {
                        handlePhotoSelected(data.getData());
                    } else {
                        Toast.makeText(this, "No photo selected", Toast.LENGTH_SHORT).show();
                    }
                    break;
                case REQUEST_DOCUMENT_PICK:
                    if (data != null && data.getData() != null) {
                        handleDocumentSelected(data.getData());
                    } else {
                        Toast.makeText(this, "No document selected", Toast.LENGTH_SHORT).show();
                    }
                    break;
            }
        }
    }
    
    /**
     * Save bitmap to temporary file and return URI
     */
    private Uri saveBitmapToFile(android.graphics.Bitmap bitmap) {
        try {
            File tempFile = createImageFile();
            if (tempFile != null) {
                java.io.FileOutputStream out = new java.io.FileOutputStream(tempFile);
                bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 90, out);
                out.close();
                
                return FileProvider.getUriForFile(this,
                        getPackageName() + ".fileprovider",
                        tempFile);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error saving bitmap to file", e);
        }
        return null;
    }
    
    /**
     * Handle selected photo and prepare for sending
     */
    private void handlePhotoSelected(Uri photoUri) {
        Log.d(TAG, "Photo selected: " + photoUri.toString());
        
        // Use new attachment service for photos
        handleAttachmentSelected(photoUri, true);
    }
    
    /**
     * Handle selected document and prepare for sending
     */
    private void handleDocumentSelected(Uri documentUri) {
        Log.d(TAG, "Document selected: " + documentUri.toString());
        
        // Use new attachment service for documents
        handleAttachmentSelected(documentUri, false);
    }
    
    /**
     * Handle any attachment (photo or document) using AttachmentUploadService
     */
    private void handleAttachmentSelected(Uri attachmentUri, boolean isPhoto) {
        if (conversationId == null) {
            Toast.makeText(this, "Cannot send attachment: No conversation", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Validate file first
        AttachmentUploadService.FileValidationResult validation = attachmentService.validateFile(attachmentUri);
        if (!validation.isValid) {
            Toast.makeText(this, validation.error, Toast.LENGTH_LONG).show();
            return;
        }
        
        // Generate file name
        String fileName = AttachmentUploadService.generateFileName(null, validation.mimeType);
        
        // Create file message with temporary URI (for immediate display)
        ChatMessage fileMessage = ChatMessage.createFileMessage(fileName, attachmentUri.toString(), currentUserEmail, conversationId);
        fileMessage.setFileType(validation.mimeType);
        fileMessage.setFileSize(validation.fileSize);
        
        // Add to local messages immediately for better UX
        runOnUiThread(() -> {
            messages.add(fileMessage);
            chatAdapter.notifyItemInserted(messages.size() - 1);
            scrollToBottom();
        });
        
        // Start background upload
        attachmentService.uploadFile(attachmentUri, fileName, conversationId, new AttachmentUploadService.UploadCallback() {
            @Override
            public void onSuccess(String publicUrl, String fileName, String mimeType) {
                runOnUiThread(() -> {
                    // Update message with public URL
                    fileMessage.setFileUrl(publicUrl);
                    
                    // Send through chat service
                    chatService.sendFileMessage(conversationId, fileName, publicUrl, null, IndividualChatActivity.this);
                    
                    String fileType = AttachmentUploadService.isImageFile(mimeType) ? "Photo" : "Document";
                    Toast.makeText(IndividualChatActivity.this, fileType + " shared successfully!", Toast.LENGTH_SHORT).show();
                });
            }
            
            @Override
            public void onProgress(int percentage) {
                // TODO: Show progress indicator in UI
                Log.d(TAG, "Upload progress: " + percentage + "%");
            }
            
            @Override
            public void onError(String error) {
                runOnUiThread(() -> {
                    Toast.makeText(IndividualChatActivity.this, "Upload failed: " + error, Toast.LENGTH_LONG).show();
                    
                    // Remove failed message from list
                    for (int i = messages.size() - 1; i >= 0; i--) {
                        if (messages.get(i) == fileMessage) {
                            messages.remove(i);
                            chatAdapter.notifyItemRemoved(i);
                            break;
                        }
                    }
                });
            }
        });
    }
    
    /**
     * Upload photo and send as message
     */
    private void uploadAndSendPhoto(Uri photoUri, String caption) {
        if (conversationId == null) {
            Toast.makeText(this, "Cannot send photo: No conversation", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Create file message with temporary URI (for immediate display)
        String fileName = "photo_" + System.currentTimeMillis() + ".jpg";
        String temporaryUrl = photoUri.toString();
        
        ChatMessage photoMessage = ChatMessage.createFileMessage(fileName, temporaryUrl, currentUserEmail, conversationId);
        if (caption != null && !caption.trim().isEmpty()) {
            photoMessage.setContent(caption);
        }
        
        // Add to local messages immediately for better UX
        runOnUiThread(() -> {
            messages.add(photoMessage);
            chatAdapter.notifyItemInserted(messages.size() - 1);
            scrollToBottom();
        });
        
        // Start background upload to Supabase Storage
        uploadPhotoToSupabase(photoUri, fileName, photoMessage);
    }
    
    /**
     * Upload photo to Supabase Storage
     */
    private void uploadPhotoToSupabase(Uri photoUri, String fileName, ChatMessage photoMessage) {
        new Thread(() -> {
            try {
                // Read the image file and prepare for upload
                java.io.InputStream inputStream = getContentResolver().openInputStream(photoUri);
                if (inputStream == null) {
                    runOnUiThread(() -> Toast.makeText(this, "Error reading photo file", Toast.LENGTH_SHORT).show());
                    return;
                }
                
                // Convert to byte array
                java.io.ByteArrayOutputStream byteArrayOutputStream = new java.io.ByteArrayOutputStream();
                byte[] buffer = new byte[1024];
                int length;
                while ((length = inputStream.read(buffer)) != -1) {
                    byteArrayOutputStream.write(buffer, 0, length);
                }
                byte[] imageBytes = byteArrayOutputStream.toByteArray();
                inputStream.close();
                byteArrayOutputStream.close();
                
                // Try to upload to Supabase Storage
                String bucketName = "chat-attachments";
                String uploadPath = "conversations/" + conversationId + "/" + fileName;
                // Fix URL construction to avoid double slashes
                String baseUrl = ApiKeys.SUPABASE_URL;
                if (baseUrl.endsWith("/")) {
                    baseUrl = baseUrl.substring(0, baseUrl.length() - 1);
                }
                String supabaseStorageUrl = baseUrl + "/storage/v1/object/" + bucketName + "/" + uploadPath;
                
                Log.d(TAG, "Attempting to upload photo to: " + supabaseStorageUrl);
                
                // Create upload request
                okhttp3.RequestBody requestBody = okhttp3.RequestBody.create(
                    okhttp3.MediaType.parse("image/jpeg"), 
                    imageBytes
                );
                
                okhttp3.Request request = new okhttp3.Request.Builder()
                        .url(supabaseStorageUrl)
                        .post(requestBody)
                        .addHeader("Authorization", "Bearer " + ApiKeys.SUPABASE_ANON_KEY)
                        .addHeader("Content-Type", "image/jpeg")
                        .addHeader("x-upsert", "true")
                        .build();
                
                okhttp3.OkHttpClient client = new okhttp3.OkHttpClient();
                okhttp3.Response response = client.newCall(request).execute();
                
                if (response.isSuccessful()) {
                    // Success: Use Supabase Storage URL
                    String publicUrl = baseUrl + "/storage/v1/object/public/" + bucketName + "/" + uploadPath;
                    photoMessage.setFileUrl(publicUrl);
                    
                    Log.d(TAG, "Photo uploaded successfully to Supabase: " + publicUrl);
                    sendPhotoMessage(fileName, publicUrl, photoMessage.getContent());
                    
                } else {
                    // Supabase upload failed - use fallback approach
                    Log.w(TAG, "Supabase upload failed (" + response.code() + " " + response.message() + "), using fallback");
                    response.close();
                    
                    // Fallback: Convert to base64 and store in database directly
                    useFallbackPhotoUpload(imageBytes, fileName, photoMessage);
                }
                
                if (response != null) response.close();
                
            } catch (Exception e) {
                Log.e(TAG, "Error uploading photo to Supabase", e);
                
                // Fallback: Try to encode as base64
                try {
                    java.io.InputStream fallbackStream = getContentResolver().openInputStream(photoUri);
                    if (fallbackStream != null) {
                        java.io.ByteArrayOutputStream baos = new java.io.ByteArrayOutputStream();
                        byte[] buffer = new byte[1024];
                        int length;
                        while ((length = fallbackStream.read(buffer)) != -1) {
                            baos.write(buffer, 0, length);
                        }
                        useFallbackPhotoUpload(baos.toByteArray(), fileName, photoMessage);
                        fallbackStream.close();
                        baos.close();
                    } else {
                        runOnUiThread(() -> Toast.makeText(this, "Error uploading photo: " + e.getMessage(), Toast.LENGTH_SHORT).show());
                    }
                } catch (Exception fallbackException) {
                    runOnUiThread(() -> Toast.makeText(this, "Error uploading photo", Toast.LENGTH_SHORT).show());
                }
            }
        }).start();
    }
    
    /**
     * Fallback photo upload using base64 encoding
     */
    private void useFallbackPhotoUpload(byte[] imageBytes, String fileName, ChatMessage photoMessage) {
        try {
            // Compress image more aggressively for base64 (max 500KB)
            if (imageBytes.length > 512 * 1024) {
                Log.d(TAG, "Image size before compression: " + imageBytes.length + " bytes");
                imageBytes = compressImageBytes(imageBytes);
                Log.d(TAG, "Image size after compression: " + imageBytes.length + " bytes");
            }
            
            // Convert to base64
            String base64Image = android.util.Base64.encodeToString(imageBytes, android.util.Base64.NO_WRAP);
            String dataUrl = "data:image/jpeg;base64," + base64Image;
            
            photoMessage.setFileUrl(dataUrl);
            
            Log.d(TAG, "Using fallback base64 encoding for photo, data URL length: " + dataUrl.length());
            
            // Check if data URL is reasonable size (under 2MB when encoded)
            if (dataUrl.length() > 2 * 1024 * 1024) {
                Log.w(TAG, "Base64 encoded image is too large: " + dataUrl.length() + " characters");
                // Compress more aggressively
                imageBytes = compressImageBytes(imageBytes, 50); // Use lower quality
                base64Image = android.util.Base64.encodeToString(imageBytes, android.util.Base64.NO_WRAP);
                dataUrl = "data:image/jpeg;base64," + base64Image;
                Log.d(TAG, "Re-compressed image, new data URL length: " + dataUrl.length());
            }
            
            sendPhotoMessage(fileName, dataUrl, photoMessage.getContent());
            
        } catch (Exception e) {
            Log.e(TAG, "Fallback photo upload failed", e);
            runOnUiThread(() -> Toast.makeText(this, "Failed to send photo", Toast.LENGTH_SHORT).show());
        }
    }
    
    /**
     * Compress image bytes to reduce size
     */
    private byte[] compressImageBytes(byte[] originalBytes) {
        return compressImageBytes(originalBytes, 70);
    }
    
    /**
     * Compress image bytes with specified quality
     */
    private byte[] compressImageBytes(byte[] originalBytes, int quality) {
        try {
            android.graphics.Bitmap bitmap = android.graphics.BitmapFactory.decodeByteArray(originalBytes, 0, originalBytes.length);
            if (bitmap == null) return originalBytes;
            
            // Scale down if too large
            int maxDimension = 600; // Reduced for better compression
            int width = bitmap.getWidth();
            int height = bitmap.getHeight();
            
            if (width > maxDimension || height > maxDimension) {
                float scale = Math.min((float) maxDimension / width, (float) maxDimension / height);
                int newWidth = Math.round(width * scale);
                int newHeight = Math.round(height * scale);
                bitmap = android.graphics.Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, true);
            }
            
            java.io.ByteArrayOutputStream compressed = new java.io.ByteArrayOutputStream();
            bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, quality, compressed);
            byte[] result = compressed.toByteArray();
            compressed.close();
            bitmap.recycle();
            
            return result;
        } catch (Exception e) {
            Log.e(TAG, "Error compressing image", e);
            return originalBytes;
        }
    }
    
    /**
     * Send photo message through chat service
     */
    private void sendPhotoMessage(String fileName, String photoUrl, String caption) {
        if (chatService != null) {
            runOnUiThread(() -> {
                chatService.sendFileMessage(conversationId, fileName, photoUrl, caption, this);
                Toast.makeText(this, "Photo shared!", Toast.LENGTH_SHORT).show();
            });
        }
    }
    
    // RealTimeChatService.MessageListener implementation
    @Override
    public void onMessageReceived(ChatMessage message) {
        runOnUiThread(() -> {
            // Only add if not already in list (avoid duplicates)
            boolean exists = false;
            for (ChatMessage existingMessage : messages) {
                if (message.getId() != null && message.getId().equals(existingMessage.getId())) {
                    exists = true;
                    break;
                }
            }
            
            if (!exists) {
                messages.add(message);
                chatAdapter.notifyItemInserted(messages.size() - 1);
                scrollToBottom();
                Log.d(TAG, "Message received: " + message.getContent());
                
                // If AI negotiation is active and this is from the landlord, provide response suggestions
                if (isAiNegotiationActive && !message.getSender().equals(currentUserEmail)) {
                    provideLandlordResponseAnalysis(message.getContent());
                }
            }
        });
    }
    
    // Analyze landlord's response and suggest user's next move
    private void provideLandlordResponseAnalysis(String landlordMessage) {
        if (negotiationEngine == null || negotiationId == null) return;
        
        AiNegotiationEngine.Negotiation negotiation = negotiationEngine.getNegotiation(negotiationId);
        if (negotiation == null) return;
        
        String responseContext = "The landlord responded with: '" + landlordMessage + "'. " +
                               "Analyze this response and suggest the user's best next move in the negotiation. " +
                               "Provide 2-3 specific response options or strategies. Keep under 150 words.";
        
        negotiationEngine.generateNegotiationMessage(negotiation, responseContext, new AiNegotiationEngine.NegotiationCallback() {
            @Override
            public void onSuccess(String aiAnalysis) {
                runOnUiThread(() -> {
                    // Add AI response analysis after a short delay
                    new android.os.Handler().postDelayed(() -> {
                        ChatMessage aiResponseAnalysis = ChatMessage.createAiMessage(
                            "🎯 **Negotiation Analysis:**\n\n" + aiAnalysis
                        );
                        messages.add(aiResponseAnalysis);
                        chatAdapter.notifyItemInserted(messages.size() - 1);
                        scrollToBottom();
                    }, 2000); // 2 second delay to let user read landlord's message first
                });
            }
            
            @Override
            public void onError(String error) {
                Log.e(TAG, "AI response analysis failed: " + error);
            }
        });
    }
    
    @Override
    public void onMessageSent(ChatMessage message) {
        runOnUiThread(() -> {
            // Add sent message to UI
            messages.add(message);
            chatAdapter.notifyItemInserted(messages.size() - 1);
            scrollToBottom();
            Log.d(TAG, "Message sent: " + message.getContent());
        });
    }
    
    @Override
    public void onTypingIndicator(String senderEmail, boolean isTyping) {
        // Handle typing indicator if needed
        Log.d(TAG, "Typing indicator: " + senderEmail + " is " + (isTyping ? "typing" : "not typing"));
    }
    
    @Override
    public void onError(String error) {
        runOnUiThread(() -> {
            Toast.makeText(this, "Chat error: " + error, Toast.LENGTH_SHORT).show();
            Log.e(TAG, "Chat error: " + error);
        });
    }
    
    /**
     * Show report user dialog
     */
    private void showReportUserDialog() {
        if (otherUserEmail == null) {
            Toast.makeText(this, "Cannot report user", Toast.LENGTH_SHORT).show();
            return;
        }
        
        String[] reportCategories = {
            "Spam or unwanted messages",
            "Harassment or bullying", 
            "Inappropriate content",
            "Fake or impersonation profile",
            "Scam or fraud",
            "Hate speech",
            "Violence or threats",
            "Sexual content",
            "Other violation"
        };
        
        new MaterialAlertDialogBuilder(this)
            .setTitle("Report User")
            .setMessage("Why are you reporting this user?")
            .setItems(reportCategories, (dialog, which) -> {
                String selectedCategory = reportCategories[which];
                showReportReasonDialog(selectedCategory);
            })
            .setNegativeButton("Cancel", null)
            .show();
    }
    
    /**
     * Show dialog to enter report reason
     */
    private void showReportReasonDialog(String category) {
        android.widget.EditText editText = new android.widget.EditText(this);
        editText.setHint("Please provide additional details (optional)");
        editText.setMaxLines(3);
        
        new MaterialAlertDialogBuilder(this)
            .setTitle("Report Details")
            .setMessage("Category: " + category)
            .setView(editText)
            .setPositiveButton("Submit Report", (dialog, which) -> {
                String reason = editText.getText().toString().trim();
                submitUserReport(category, reason);
            })
            .setNegativeButton("Cancel", null)
            .show();
    }
    
    /**
     * Submit user report
     */
    private void submitUserReport(String category, String reason) {
        if (moderationService == null || otherUserEmail == null) {
            Toast.makeText(this, "Unable to submit report", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Show loading
        android.app.ProgressDialog progressDialog = new android.app.ProgressDialog(this);
        progressDialog.setMessage("Submitting report...");
        progressDialog.show();
        
        moderationService.reportContent(
            currentUserEmail,
            otherUserEmail,
            null, // No specific message ID for user report
            reason,
            category.toUpperCase().replace(" ", "_"),
            new ChatModerationService.ReportCallback() {
                @Override
                public void onReportSubmitted() {
                    runOnUiThread(() -> {
                        progressDialog.dismiss();
                        Toast.makeText(IndividualChatActivity.this, 
                            "Report submitted successfully", Toast.LENGTH_SHORT).show();
                    });
                }
                
                @Override
                public void onReportError(String error) {
                    runOnUiThread(() -> {
                        progressDialog.dismiss();
                        Toast.makeText(IndividualChatActivity.this, 
                            "Failed to submit report: " + error, Toast.LENGTH_SHORT).show();
                    });
                }
            }
        );
    }
    
    /**
     * Show block user confirmation dialog
     */
    private void showBlockUserDialog() {
        if (otherUserEmail == null) {
            Toast.makeText(this, "Cannot block user", Toast.LENGTH_SHORT).show();
            return;
        }
        
        new MaterialAlertDialogBuilder(this)
            .setTitle("Block User")
            .setMessage("Are you sure you want to block this user? You will no longer receive messages from them.")
            .setPositiveButton("Block", (dialog, which) -> {
                blockUser();
            })
            .setNegativeButton("Cancel", null)
            .show();
    }
    
    /**
     * Block the current user
     */
    private void blockUser() {
        if (moderationService == null || otherUserEmail == null) {
            Toast.makeText(this, "Unable to block user", Toast.LENGTH_SHORT).show();
            return;
        }
        
        // Show loading
        android.app.ProgressDialog progressDialog = new android.app.ProgressDialog(this);
        progressDialog.setMessage("Blocking user...");
        progressDialog.show();
        
        moderationService.blockUser(
            currentUserEmail,
            otherUserEmail,
            new ChatModerationService.BlockCallback() {
                @Override
                public void onUserBlocked() {
                    runOnUiThread(() -> {
                        progressDialog.dismiss();
                        Toast.makeText(IndividualChatActivity.this, 
                            "User blocked successfully", Toast.LENGTH_SHORT).show();
                        
                        // Close the chat since user is now blocked
                        finish();
                    });
                }
                
                @Override
                public void onBlockError(String error) {
                    runOnUiThread(() -> {
                        progressDialog.dismiss();
                        Toast.makeText(IndividualChatActivity.this, 
                            "Failed to block user: " + error, Toast.LENGTH_SHORT).show();
                    });
                }
            }
        );
    }
    
    /**
     * Check if current user is blocked by the other user
     */
    private boolean isUserBlocked() {
        if (moderationService == null || otherUserEmail == null) {
            return false;
        }
        
        return moderationService.isUserBlocked(currentUserEmail, otherUserEmail) ||
               moderationService.isUserBlocked(otherUserEmail, currentUserEmail);
    }
    
    @Override
    protected void onDestroy() {
        super.onDestroy();
        
        // Cleanup chat service
        if (chatService != null && conversationId != null) {
            chatService.unregisterMessageListener(conversationId);
        }
    }
    
    // Static helper methods to start chat from other activities
    public static void startChatWithUser(android.content.Context context, String listingId, String listingTitle, String ownerEmail) {
        Intent intent = new Intent(context, IndividualChatActivity.class);
        intent.putExtra("listing_id", listingId);
        intent.putExtra("listing_title", listingTitle);
        intent.putExtra("owner_email", ownerEmail);
        intent.putExtra("other_user_email", ownerEmail);
        context.startActivity(intent);
    }
    
    public static void openExistingConversation(android.content.Context context, String conversationId, String otherUserEmail) {
        Intent intent = new Intent(context, IndividualChatActivity.class);
        intent.putExtra("conversation_id", conversationId);
        intent.putExtra("other_user_email", otherUserEmail);
        context.startActivity(intent);
    }
}
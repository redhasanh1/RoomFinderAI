// Simplified verification system that doesn't require Supabase Storage
// This stores ID documents as base64 in the database temporarily

class SimpleVerificationSystem extends VerificationSystem {
    constructor(supabaseClient) {
        super(supabaseClient);
    }

    // Upload ID document as base64 (simpler approach)
    async uploadIDDocument(file, userEmail) {
        try {
            // Validate file
            if (!this.isValidIDDocument(file)) {
                throw new Error('Invalid ID document format');
            }

            // Convert file to base64
            const base64Data = await this.fileToBase64(file);
            
            // Create document data
            const documentData = {
                filename: file.name,
                fileType: file.type,
                fileSize: file.size,
                base64Data: base64Data,
                uploadedAt: new Date().toISOString()
            };

            return {
                url: base64Data, // Use base64 as URL for now
                path: `temp/${userEmail}-${Date.now()}`,
                filename: file.name,
                documentData: documentData
            };
        } catch (error) {
            console.error('ID upload error:', error);
            throw error;
        }
    }

    // Convert file to base64
    fileToBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(reader.result);
            reader.onerror = reject;
            reader.readAsDataURL(file);
        });
    }

    // Submit verification request (modified for simple upload)
    async submitVerificationRequest(userEmail, idDocumentData, faceData) {
        try {
            const verificationData = {
                user_email: userEmail,
                id_document_url: 'stored_in_database', // Flag that it's in the database
                id_document_type: this.detectIDType(idDocumentData.filename),
                face_scan_data: {
                    image_url: faceData.dataUrl,
                    confidence: faceData.confidence || 0.85,
                    captured_at: new Date().toISOString()
                },
                face_verification_score: faceData.confidence || 0.85,
                third_party_verification_data: {
                    id_document: idDocumentData.documentData,
                    face_scan: faceData,
                    provider: 'manual'
                },
                ip_address: await this.getUserIP(),
                user_agent: navigator.userAgent
            };

            const response = await fetch('http://localhost:3000/api/verification/submit', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(verificationData)
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error || 'Verification submission failed');
            }

            const result = await response.json();
            return result.verification;
        } catch (error) {
            console.error('Verification submission error:', error);
            throw error;
        }
    }
}
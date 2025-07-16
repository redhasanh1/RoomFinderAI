import { universalApi } from './universal-api';

export interface OpenAIConfig {
  apiKey: string;
  organization?: string;
  baseUrl?: string;
}

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
  name?: string;
}

export interface ChatCompletionRequest {
  model: string;
  messages: ChatMessage[];
  temperature?: number;
  max_tokens?: number;
  top_p?: number;
  frequency_penalty?: number;
  presence_penalty?: number;
  stop?: string | string[];
  stream?: boolean;
}

export interface ChatCompletionResponse {
  id: string;
  object: string;
  created: number;
  model: string;
  choices: {
    index: number;
    message: ChatMessage;
    finish_reason: string;
  }[];
  usage: {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
  };
}

export interface EmbeddingRequest {
  model: string;
  input: string | string[];
  user?: string;
}

export interface EmbeddingResponse {
  object: string;
  data: {
    object: string;
    embedding: number[];
    index: number;
  }[];
  model: string;
  usage: {
    prompt_tokens: number;
    total_tokens: number;
  };
}

export interface ImageGenerationRequest {
  model?: string;
  prompt: string;
  n?: number;
  size?: '256x256' | '512x512' | '1024x1024' | '1792x1024' | '1024x1792';
  quality?: 'standard' | 'hd';
  response_format?: 'url' | 'b64_json';
  style?: 'vivid' | 'natural';
  user?: string;
}

export interface ImageGenerationResponse {
  created: number;
  data: {
    url?: string;
    b64_json?: string;
    revised_prompt?: string;
  }[];
}

export interface ModerationRequest {
  input: string | string[];
  model?: string;
}

export interface ModerationResponse {
  id: string;
  model: string;
  results: {
    flagged: boolean;
    categories: Record<string, boolean>;
    category_scores: Record<string, number>;
  }[];
}

class OpenAIApiService {
  private static instance: OpenAIApiService;
  private config: OpenAIConfig;
  private baseUrl: string;

  private constructor(config: OpenAIConfig) {
    this.config = config;
    this.baseUrl = config.baseUrl || 'https://api.openai.com/v1';
    this.setupDefaultHeaders();
  }

  static getInstance(config?: OpenAIConfig): OpenAIApiService {
    if (!OpenAIApiService.instance) {
      if (!config) {
        throw new Error('OpenAIApiService requires config on first initialization');
      }
      OpenAIApiService.instance = new OpenAIApiService(config);
    }
    return OpenAIApiService.instance;
  }

  private setupDefaultHeaders() {
    universalApi.setHeader('Authorization', `Bearer ${this.config.apiKey}`);
    universalApi.setHeader('Content-Type', 'application/json');
    
    if (this.config.organization) {
      universalApi.setHeader('OpenAI-Organization', this.config.organization);
    }
  }

  // Chat Completions
  async createChatCompletion(request: ChatCompletionRequest): Promise<ChatCompletionResponse> {
    const response = await universalApi.post(`${this.baseUrl}/chat/completions`, request);
    return response.data;
  }

  // Streaming chat completions (simplified for mobile)
  async createChatCompletionStream(
    request: ChatCompletionRequest,
    onChunk: (chunk: any) => void,
    onComplete: () => void,
    onError: (error: any) => void
  ): Promise<void> {
    try {
      const streamRequest = { ...request, stream: true };
      
      // For mobile, we'll simulate streaming by making regular requests
      // In a real implementation, you'd use Server-Sent Events or WebSocket
      const response = await universalApi.post(`${this.baseUrl}/chat/completions`, streamRequest);
      
      if (response.data.choices && response.data.choices.length > 0) {
        onChunk(response.data);
      }
      
      onComplete();
    } catch (error) {
      onError(error);
    }
  }

  // Embeddings
  async createEmbedding(request: EmbeddingRequest): Promise<EmbeddingResponse> {
    const response = await universalApi.post(`${this.baseUrl}/embeddings`, request);
    return response.data;
  }

  // Image Generation
  async generateImage(request: ImageGenerationRequest): Promise<ImageGenerationResponse> {
    const response = await universalApi.post(`${this.baseUrl}/images/generations`, request);
    return response.data;
  }

  // Image Editing
  async editImage(
    image: File | Blob,
    prompt: string,
    mask?: File | Blob,
    options?: {
      n?: number;
      size?: '256x256' | '512x512' | '1024x1024';
      response_format?: 'url' | 'b64_json';
      user?: string;
    }
  ): Promise<ImageGenerationResponse> {
    const formData = new FormData();
    formData.append('image', image);
    formData.append('prompt', prompt);
    
    if (mask) {
      formData.append('mask', mask);
    }
    
    if (options) {
      Object.entries(options).forEach(([key, value]) => {
        if (value !== undefined) {
          formData.append(key, value.toString());
        }
      });
    }

    const response = await universalApi.uploadFile(
      `${this.baseUrl}/images/edits`,
      image,
      'image',
      Object.fromEntries(formData.entries())
    );
    
    return response.data;
  }

  // Image Variations
  async createImageVariation(
    image: File | Blob,
    options?: {
      n?: number;
      size?: '256x256' | '512x512' | '1024x1024';
      response_format?: 'url' | 'b64_json';
      user?: string;
    }
  ): Promise<ImageGenerationResponse> {
    const formData = new FormData();
    formData.append('image', image);
    
    if (options) {
      Object.entries(options).forEach(([key, value]) => {
        if (value !== undefined) {
          formData.append(key, value.toString());
        }
      });
    }

    const response = await universalApi.uploadFile(
      `${this.baseUrl}/images/variations`,
      image,
      'image',
      Object.fromEntries(formData.entries())
    );
    
    return response.data;
  }

  // Moderation
  async createModeration(request: ModerationRequest): Promise<ModerationResponse> {
    const response = await universalApi.post(`${this.baseUrl}/moderations`, request);
    return response.data;
  }

  // Audio Transcription
  async transcribeAudio(
    audio: File | Blob,
    options?: {
      model?: string;
      language?: string;
      prompt?: string;
      response_format?: 'json' | 'text' | 'srt' | 'verbose_json' | 'vtt';
      temperature?: number;
    }
  ): Promise<any> {
    const formData = new FormData();
    formData.append('file', audio);
    formData.append('model', options?.model || 'whisper-1');
    
    if (options) {
      Object.entries(options).forEach(([key, value]) => {
        if (value !== undefined && key !== 'model') {
          formData.append(key, value.toString());
        }
      });
    }

    const response = await universalApi.uploadFile(
      `${this.baseUrl}/audio/transcriptions`,
      audio,
      'file',
      Object.fromEntries(formData.entries())
    );
    
    return response.data;
  }

  // Audio Translation
  async translateAudio(
    audio: File | Blob,
    options?: {
      model?: string;
      prompt?: string;
      response_format?: 'json' | 'text' | 'srt' | 'verbose_json' | 'vtt';
      temperature?: number;
    }
  ): Promise<any> {
    const formData = new FormData();
    formData.append('file', audio);
    formData.append('model', options?.model || 'whisper-1');
    
    if (options) {
      Object.entries(options).forEach(([key, value]) => {
        if (value !== undefined && key !== 'model') {
          formData.append(key, value.toString());
        }
      });
    }

    const response = await universalApi.uploadFile(
      `${this.baseUrl}/audio/translations`,
      audio,
      'file',
      Object.fromEntries(formData.entries())
    );
    
    return response.data;
  }

  // Text-to-Speech
  async createSpeech(
    text: string,
    options?: {
      model?: string;
      voice?: 'alloy' | 'echo' | 'fable' | 'onyx' | 'nova' | 'shimmer';
      response_format?: 'mp3' | 'opus' | 'aac' | 'flac';
      speed?: number;
    }
  ): Promise<Blob> {
    const request = {
      model: options?.model || 'tts-1',
      input: text,
      voice: options?.voice || 'alloy',
      response_format: options?.response_format || 'mp3',
      speed: options?.speed || 1,
    };

    const response = await universalApi.request({
      url: `${this.baseUrl}/audio/speech`,
      method: 'POST',
      data: request,
      responseType: 'blob',
    });
    
    return response.data;
  }

  // Fine-tuning (basic support)
  async createFineTuningJob(request: {
    training_file: string;
    model?: string;
    hyperparameters?: {
      batch_size?: number;
      learning_rate_multiplier?: number;
      n_epochs?: number;
    };
    suffix?: string;
  }): Promise<any> {
    const response = await universalApi.post(`${this.baseUrl}/fine_tuning/jobs`, request);
    return response.data;
  }

  async listFineTuningJobs(limit?: number): Promise<any> {
    const params = limit ? `?limit=${limit}` : '';
    const response = await universalApi.get(`${this.baseUrl}/fine_tuning/jobs${params}`);
    return response.data;
  }

  async getFineTuningJob(jobId: string): Promise<any> {
    const response = await universalApi.get(`${this.baseUrl}/fine_tuning/jobs/${jobId}`);
    return response.data;
  }

  async cancelFineTuningJob(jobId: string): Promise<any> {
    const response = await universalApi.post(`${this.baseUrl}/fine_tuning/jobs/${jobId}/cancel`, {});
    return response.data;
  }

  // Models
  async listModels(): Promise<any> {
    const response = await universalApi.get(`${this.baseUrl}/models`);
    return response.data;
  }

  async getModel(modelId: string): Promise<any> {
    const response = await universalApi.get(`${this.baseUrl}/models/${modelId}`);
    return response.data;
  }

  // Convenience methods for common use cases
  async simpleChat(message: string, systemPrompt?: string): Promise<string> {
    const messages: ChatMessage[] = [];
    
    if (systemPrompt) {
      messages.push({ role: 'system', content: systemPrompt });
    }
    
    messages.push({ role: 'user', content: message });

    const response = await this.createChatCompletion({
      model: 'gpt-3.5-turbo',
      messages,
      temperature: 0.7,
      max_tokens: 1000,
    });

    return response.choices[0]?.message?.content || '';
  }

  async analyzeText(text: string, instructions: string): Promise<string> {
    const systemPrompt = `You are a helpful assistant that analyzes text based on the following instructions: ${instructions}`;
    return this.simpleChat(text, systemPrompt);
  }

  async generateSummary(text: string, maxWords?: number): Promise<string> {
    const wordLimit = maxWords ? ` in no more than ${maxWords} words` : '';
    const systemPrompt = `You are a helpful assistant that creates concise summaries. Summarize the following text${wordLimit}:`;
    return this.simpleChat(text, systemPrompt);
  }
}

// Export singleton instance creator
export const createOpenAIApi = (config: OpenAIConfig) => {
  return OpenAIApiService.getInstance(config);
};

export default OpenAIApiService;
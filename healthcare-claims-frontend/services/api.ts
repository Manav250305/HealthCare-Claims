// services/api.ts
import { UploadUrlResponse, ProcessClaimResponse } from '@/types/claims';

// API Gateway for fast operations (upload URL)
const API_GATEWAY_URL = 'https://gdc3i9r6ha.execute-api.us-east-1.amazonaws.com/prod';

// Direct EC2 for long-running operations (processing)
const EC2_IP = process.env.NEXT_PUBLIC_EC2_IP || '34.227.107.139';
const EC2_PORT = process.env.NEXT_PUBLIC_EC2_PORT || '5000';
const EC2_DIRECT_URL = `http://${EC2_IP}:${EC2_PORT}`;

// Helper function for fetch with timeout
async function fetchWithTimeout(
  url: string, 
  options: RequestInit, 
  timeout: number = 60000
): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeout);
  
  try {
    const response = await fetch(url, {
      ...options,
      signal: controller.signal
    });
    clearTimeout(timeoutId);
    return response;
  } catch (error) {
    clearTimeout(timeoutId);
    if (error instanceof Error && error.name === 'AbortError') {
      throw new Error(`Request timed out after ${timeout / 1000} seconds`);
    }
    throw error;
  }
}

export const claimsService = {
  
  async getUploadUrl(filename: string): Promise<UploadUrlResponse> {
    console.log('Getting presigned upload URL...');
    
    const response = await fetchWithTimeout(
      `${API_GATEWAY_URL}/upload-url`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ filename })
      },
      10000 // 10 seconds
    );
    
    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(error.message || 'Failed to generate upload URL');
    }
    
    const result = await response.json();
    console.log('✓ Got upload URL for:', result.s3_key);
    return result;
  },

  async uploadToS3(uploadUrl: string, file: File): Promise<void> {
    console.log('Uploading file to S3...');
    
    const response = await fetchWithTimeout(
      uploadUrl,
      {
        method: 'PUT',
        headers: { 'Content-Type': 'application/pdf' },
        body: file
      },
      30000 // 30 seconds
    );
    
    if (!response.ok) {
      const errorText = await response.text();
      console.error('S3 Upload Error:', errorText);
      throw new Error('S3 Upload Failed. Check CORS configuration.');
    }
    
    console.log('✓ File uploaded to S3 successfully');
  },

  async processClaim(
    s3Key: string, 
    claimId?: string
  ): Promise<ProcessClaimResponse> {
    console.log('🤖 Starting AI Analysis (30-45 seconds)...');
    console.log('📄 Processing document:', s3Key);
    console.log('🔗 Using direct EC2 endpoint (bypassing API Gateway timeout)');
    
    const startTime = Date.now();
    
    try {
      // Use DIRECT EC2 connection to avoid API Gateway 29s timeout
      const response = await fetchWithTimeout(
        `${EC2_DIRECT_URL}/process-claim`,
        {
          method: 'POST',
          headers: { 
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            s3_key: s3Key,
            claim_id: claimId || `CLAIM-${Date.now()}`
          })
        },
        120000 // 120 seconds (2 minutes) - backend takes 30-40s
      );
      
      const elapsedTime = ((Date.now() - startTime) / 1000).toFixed(1);
      console.log(`⏱️  Request completed in ${elapsedTime}s`);
      
      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        console.error('❌ Backend Error:', errorData);
        throw new Error(
          errorData.error || 
          errorData.message || 
          `Backend error: ${response.status} ${response.statusText}`
        );
      }
      
      const result = await response.json();
      console.log('✅ Analysis complete!');
      console.log('📊 Risk Score:', result.risk_score);
      console.log('🎯 Risk Level:', result.risk_level);
      console.log('💡 Recommendation:', result.recommendation);
      
      return result;
      
    } catch (error) {
      const elapsedTime = ((Date.now() - startTime) / 1000).toFixed(1);
      console.error(`❌ Request failed after ${elapsedTime}s`);
      
      if (error instanceof Error) {
        if (error.message.includes('timed out')) {
          throw new Error(
            `Processing timed out after ${elapsedTime}s. ` +
            `This usually means the backend is still processing. ` +
            `Check EC2 logs or try again in a moment.`
          );
        }
        if (error.message.includes('Failed to fetch')) {
          throw new Error(
            `Cannot connect to processing server. ` +
            `Make sure EC2 instance is running and security group allows port 5000.`
          );
        }
        throw error;
      }
      
      throw new Error('Unknown error during processing');
    }
  },

  async processFullFlow(
    file: File,
    onProgress?: (stage: string, progress: number) => void
  ): Promise<ProcessClaimResponse> {
    try {
      // Step 1: Get upload URL (10%)
      onProgress?.('Getting upload URL...', 10);
      const { upload_url, s3_key } = await this.getUploadUrl(file.name);
      
      // Step 2: Upload to S3 (30%)
      onProgress?.('Uploading file to S3...', 30);
      await this.uploadToS3(upload_url, file);
      
      // Small delay for S3 consistency
      onProgress?.('Preparing for analysis...', 40);
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Step 3: Process claim (50-100%)
      onProgress?.('Analyzing with AI (this takes 30-45 seconds)...', 50);
      const result = await this.processClaim(s3_key);
      
      onProgress?.('Complete!', 100);
      return result;
      
    } catch (error) {
      console.error('❌ Full flow error:', error);
      throw error;
    }
  }
};

import { NextRequest, NextResponse } from 'next/server';
import { getServerSession } from 'next-auth';

export async function POST(request: NextRequest) {
  try {
    // Get authenticated user
    const session = await getServerSession();
    if (!session?.user?.email) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    // Parse FormData from frontend
    const formData = await request.formData();
    const file = formData.get('file') as File;
    
    if (!file) {
      return NextResponse.json({ error: 'No file provided' }, { status: 400 });
    }

    console.log('📤 Processing file:', file.name, 'for user:', session.user.email);

    // Get environment variables
    const apiGatewayUrl = process.env.API_GATEWAY_URL;
    const ec2Ip = process.env.EC2_IP;
    const ec2Port = process.env.EC2_PORT;

    if (!apiGatewayUrl || !ec2Ip || !ec2Port) {
      console.error('Missing environment variables');
      return NextResponse.json(
        { error: 'Server configuration error' },
        { status: 500 }
      );
    }

    // Step 1: Get presigned URL from Lambda via API Gateway
    console.log('Step 1: Getting presigned URL from Lambda...');
    console.log('Calling:', `${apiGatewayUrl}/upload-url`);
    
    const lambdaResponse = await fetch(
      `${apiGatewayUrl}/upload-url`,  // ✅ Changed from /get-presigned-url
      {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          filename: file.name
        })
      }
    );

    console.log('Lambda response status:', lambdaResponse.status);

    if (!lambdaResponse.ok) {
      const errorText = await lambdaResponse.text();
      console.error('Lambda error response:', errorText);
      throw new Error(`Lambda failed: ${lambdaResponse.status} - ${errorText}`);
    }

    const lambdaData = await lambdaResponse.json();
    console.log('Lambda response:', lambdaData);

    // Your Lambda returns: upload_url, s3_key, s3_bucket
    const { upload_url, s3_key } = lambdaData;
    
    if (!upload_url || !s3_key) {
      throw new Error('Invalid Lambda response - missing upload_url or s3_key');
    }

    console.log('✅ Got presigned URL for S3 key:', s3_key);

    // Step 2: Upload file to S3 using presigned URL
    console.log('Step 2: Uploading to S3...');
    const uploadResponse = await fetch(upload_url, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/pdf'
      },
      body: await file.arrayBuffer()
    });

    console.log('S3 upload status:', uploadResponse.status);

    if (!uploadResponse.ok) {
      const errorText = await uploadResponse.text();
      console.error('S3 upload error:', errorText);
      throw new Error(`S3 upload failed: ${uploadResponse.status}`);
    }

    console.log('✅ File uploaded to S3');

    // Step 3: Send S3 key to EC2 backend for processing
    console.log('Step 3: Sending to EC2 for processing...');
    const ec2Url = `http://${ec2Ip}:${ec2Port}/process-claim`;
    console.log('EC2 URL:', ec2Url);

    const ec2Response = await fetch(ec2Url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        s3_key: s3_key,
        user_id: session.user.email,
        claim_id: `CLAIM-${Date.now()}`
      })
    });

    console.log('EC2 response status:', ec2Response.status);

    if (!ec2Response.ok) {
      const errorData = await ec2Response.json();
      console.error('EC2 Backend Error:', errorData);
      throw new Error(errorData.error || 'Failed to process claim on EC2');
    }

    const result = await ec2Response.json();
    
    console.log('✅ Claim processed successfully:', result.claim_id);

    return NextResponse.json(result);

  } catch (error: any) {
    console.error('❌ Process claim error:', error);
    return NextResponse.json(
      { 
        error: error.message || 'Failed to process claim',
        stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
      },
      { status: 500 }
    );
  }
}

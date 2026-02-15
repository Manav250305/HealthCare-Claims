import { NextRequest, NextResponse } from 'next/server';
import { getServerSession } from 'next-auth';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, QueryCommand } from '@aws-sdk/lib-dynamodb';

const dynamoClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const docClient = DynamoDBDocumentClient.from(dynamoClient);

export async function GET(request: NextRequest) {
  try {
    // Get authenticated user
    const session = await getServerSession();
    if (!session?.user?.email) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    // Get query parameters
    const searchParams = request.nextUrl.searchParams;
    const page = parseInt(searchParams.get('page') || '1');
    const limit = parseInt(searchParams.get('limit') || '10');
    const riskLevel = searchParams.get('risk_level');
    
    // Query DynamoDB using GSI
    const command = new QueryCommand({
      TableName: process.env.DYNAMODB_TABLE || 'ClaimProcessingResults',
      IndexName: 'UserIdIndex',
      KeyConditionExpression: 'user_id = :userId',
      ExpressionAttributeValues: {
        ':userId': session.user.email
      },
      ScanIndexForward: false, // Sort by timestamp descending (newest first)
      Limit: limit
    });

    const response = await docClient.send(command);
    
    // Filter by risk level if provided
    let claims = response.Items || [];
    if (riskLevel && riskLevel !== 'ALL') {
      claims = claims.filter(claim => claim.risk_level === riskLevel);
    }

    // Calculate pagination
    const total = claims.length;
    const totalPages = Math.ceil(total / limit);

    return NextResponse.json({
      claims,
      pagination: {
        page,
        limit,
        total,
        totalPages
      }
    });

  } catch (error: any) {
    console.error('Error fetching claims:', error);
    return NextResponse.json(
      { error: 'Failed to fetch claims' },
      { status: 500 }
    );
  }
}

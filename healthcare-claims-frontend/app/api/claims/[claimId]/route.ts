import { NextRequest, NextResponse } from 'next/server';
import { getServerSession } from 'next-auth';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand } from '@aws-sdk/lib-dynamodb';

const dynamoClient = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const docClient = DynamoDBDocumentClient.from(dynamoClient);

export async function GET(
  request: NextRequest,
  { params }: { params: { claimId: string } }
) {
  try {
    const session = await getServerSession();
    if (!session?.user?.email) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const command = new GetCommand({
      TableName: process.env.DYNAMODB_TABLE || 'ClaimProcessingResults',
      Key: { claim_id: params.claimId }
    });

    const response = await docClient.send(command);
    
    if (!response.Item) {
      return NextResponse.json({ error: 'Claim not found' }, { status: 404 });
    }

    // Verify claim belongs to user
    if (response.Item.user_id !== session.user.email) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
    }

    return NextResponse.json(response.Item);

  } catch (error: any) {
    console.error('Error fetching claim:', error);
    return NextResponse.json(
      { error: 'Failed to fetch claim' },
      { status: 500 }
    );
  }
}

import json
import boto3
from datetime import datetime

# Initialize AWS clients
lambda_client = boto3.client('lambda')
dynamodb = boto3.resource('dynamodb')
s3_client = boto3.client('s3')

# Configuration
DYNAMODB_TABLE = 'ClaimResults'
RESULTS_BUCKET = 'healthcare-claims-results-1768911696'
PDF_EXTRACTOR_FUNCTION = 'pdf-extractor'
RISK_SCORER_FUNCTION = 'risk-scorer'

table = dynamodb.Table(DYNAMODB_TABLE)

def update_claim_status(claim_id, status, data=None):
    """Update claim status in DynamoDB"""
    item = {
        'claim_id': claim_id,
        'timestamp': int(datetime.utcnow().timestamp()),
        'status': status,
        'last_updated': datetime.utcnow().isoformat()
    }
    if data:
        item['data'] = json.dumps(data, default=str)

    table.put_item(Item=item)
    print(f"Updated claim {claim_id} status to {status}")

def invoke_lambda(function_name, payload):
    """Invoke another Lambda function"""
    print(f"Invoking {function_name}")
    response = lambda_client.invoke(
        FunctionName=function_name,
        InvocationType='RequestResponse',
        Payload=json.dumps(payload)
    )

    result = json.loads(response['Payload'].read())

    if result.get('statusCode') != 200:
        error_msg = f"Lambda {function_name} returned status {result.get('statusCode')}"
        print(error_msg)
        raise Exception(error_msg)

    return json.loads(result['body'])

def save_results_to_s3(claim_id, results):
    """Save processing results to S3"""
    timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
    key = f"results/{claim_id}/{timestamp}.json"

    s3_client.put_object(
        Bucket=RESULTS_BUCKET,
        Key=key,
        Body=json.dumps(results, indent=2, default=str),
        ContentType='application/json'
    )

    return f"s3://{RESULTS_BUCKET}/{key}"

def lambda_handler(event, context):
    """
    Main orchestrator function - handles both API Gateway and direct invocation
    """
    try:
        print(f"Orchestrator received event: {json.dumps(event)}")

        # Handle API Gateway event format
        if 'body' in event:
            # API Gateway passes body as string
            if isinstance(event['body'], str):
                body = json.loads(event['body'])
            else:
                body = event['body']
            s3_bucket = body.get('s3_bucket')
            s3_key = body.get('s3_key')
            claim_id = body.get('claim_id', f"TEST-{int(datetime.utcnow().timestamp())}")
        else:
            # Direct Lambda invocation
            s3_bucket = event.get('s3_bucket')
            s3_key = event.get('s3_key')
            claim_id = event.get('claim_id', f"TEST-{int(datetime.utcnow().timestamp())}")

        if not s3_bucket or not s3_key:
            error_response = {'error': 'Missing s3_bucket or s3_key in event'}
            return {
                'statusCode': 400,
                'headers': {
                    'Access-Control-Allow-Origin': '*',
                    'Content-Type': 'application/json'
                },
                'body': json.dumps(error_response)
            }

        # Update status to processing
        update_claim_status(claim_id, 'PROCESSING_STARTED')

        # Step 1: Extract text from PDF
        print("Step 1: Extracting text from PDF")
        update_claim_status(claim_id, 'EXTRACTING_TEXT')

        extraction_result = invoke_lambda(PDF_EXTRACTOR_FUNCTION, {
            's3_bucket': s3_bucket,
            's3_key': s3_key
        })

        extracted_text = extraction_result.get('extracted_text')
        key_fields = extraction_result.get('key_fields', {})

        print(f"Extracted {len(extracted_text)} characters")

        # Step 2: Calculate risk score
        print("Step 2: Calculating risk score")
        update_claim_status(claim_id, 'CALCULATING_RISK')

        risk_result = invoke_lambda(RISK_SCORER_FUNCTION, {
            'extracted_text': extracted_text,
            'key_fields': key_fields
        })

        # Compile final results
        final_results = {
            'claim_id': claim_id,
            'processing_timestamp': datetime.utcnow().isoformat(),
            'source_file': {
                'bucket': s3_bucket,
                'key': s3_key
            },
            'extraction_results': {
                'method': extraction_result.get('extraction_method'),
                'text_length': extraction_result.get('text_length'),
                'key_fields': key_fields
            },
            'risk_analysis': risk_result,
            'workflow_status': 'COMPLETED'
        }

        # Save to S3
        results_url = save_results_to_s3(claim_id, final_results)
        final_results['results_url'] = results_url

        print(f"Saved results to {results_url}")

        # Update final status
        update_claim_status(claim_id, 'COMPLETED', final_results)

        print(f"Claim processing completed successfully for {claim_id}")

        # Return response
        response_body = {
            'message': 'Claim processing completed successfully',
            'claim_id': claim_id,
            'risk_level': risk_result['overall_risk']['risk_level'],
            'risk_score': risk_result['overall_risk']['overall_risk_score'],
            'recommendation': risk_result['overall_risk']['recommendation'],
            'results': final_results
        }

        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            'body': json.dumps(response_body, default=str)
        }

    except Exception as e:
        print(f"Orchestration failed: {str(e)}")
        import traceback
        traceback.print_exc()

        # Update failure status
        try:
            update_claim_status(claim_id, 'FAILED')
        except:
            pass

        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'error': f'Orchestration failed: {str(e)}',
                'claim_id': claim_id
            })
        }

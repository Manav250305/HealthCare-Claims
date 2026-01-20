import json
import boto3
import re
from io import BytesIO

try:
    import PyPDF2
except ImportError:
    print("PyPDF2 not available - ensure Lambda layer is attached")

s3_client = boto3.client('s3')

def clean_text(text):
    if not text:
        return ""
    text = re.sub(r'\s+', ' ', text)
    text = re.sub(r'[^\w\s\-.,:/()@]', '', text)
    return text.strip()

def extract_with_pypdf2(pdf_bytes):
    try:
        pdf_file = BytesIO(pdf_bytes)
        pdf_reader = PyPDF2.PdfReader(pdf_file)
        text_parts = []
        for page_num in range(len(pdf_reader.pages)):
            page = pdf_reader.pages[page_num]
            text_parts.append(page.extract_text())
        full_text = '\n'.join(text_parts)
        return clean_text(full_text)
    except Exception as e:
        print(f"PyPDF2 extraction failed: {str(e)}")
        return None

def extract_key_fields(text):
    fields = {}

    # Based on debug output: "PaOent Name: Priya Bhadoria Lal Mobile No:"
    patterns = {
        'phs_id': r'PHS ID[:\s]+([A-Z0-9/()]+)',
        'policy_no': r'Policy No[:\s]+(\d+)',
        # FIXED: Pattern that matches "PaOent Name: Priya Bhadoria Lal"
        'patient_name': r'PaOent Name[:\s]+([A-Za-z\s]+?)(?=\s+Mobile)',
        'insured_name': r'Insured Name[:\s]+([A-Za-z\s]+?)(?=\s+Employee)',
        'mobile': r'Mobile No[:\s]+(\d{10})',
        'email': r'E-Mail ID[:\s]+([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})',
        'claim_type': r'Type of Claim[^:]*:[^A-Z]*(Main Hospitalization|Pre-Post Hospitalization|OPD Claim|Critical Illness)',
        'corporate_name': r'Name of Corporate[:\s]+([A-Za-z\s&.,]+?)(?=\s+Type of|\s+E-Mail)',
        'submission_date': r'Date of Claim\s+Submission[:\s]+(\d{2}/\d{2}/\d{4})'
    }

    for field, pattern in patterns.items():
        match = re.search(pattern, text, re.IGNORECASE | re.MULTILINE)
        if match:
            fields[field] = match.group(1).strip()

    return fields

def lambda_handler(event, context):
    try:
        print(f"Received event: {json.dumps(event)}")

        pdf_bytes = None
        if 's3_bucket' in event and 's3_key' in event:
            bucket = event['s3_bucket']
            key = event['s3_key']
            print(f"Downloading PDF from s3://{bucket}/{key}")
            response = s3_client.get_object(Bucket=bucket, Key=key)
            pdf_bytes = response['Body'].read()
        else:
            return {'statusCode': 400, 'body': json.dumps({'error': 'Missing PDF source'})}

        if not pdf_bytes:
            raise ValueError("Failed to retrieve PDF bytes")

        print(f"PDF size: {len(pdf_bytes)} bytes")

        extracted_text = extract_with_pypdf2(pdf_bytes)
        extraction_method = "pypdf2_fixed"

        if not extracted_text or len(extracted_text) < 50:
            return {'statusCode': 422, 'body': json.dumps({
                'error': 'Failed to extract meaningful text from PDF',
                'extraction_method': extraction_method,
                'text_length': len(extracted_text) if extracted_text else 0
            })}

        key_fields = extract_key_fields(extracted_text)

        print(f"Extracted {len(extracted_text)} characters of text")
        print(f"Found {len(key_fields)} key fields: {list(key_fields.keys())}")
        print(f"Patient name: {key_fields.get('patient_name', 'NOT FOUND')}")

        return {'statusCode': 200, 'body': json.dumps({
            'extracted_text': extracted_text,
            'key_fields': key_fields,
            'extraction_method': extraction_method,
            'text_length': len(extracted_text),
            'metadata': {
                'pdf_size_bytes': len(pdf_bytes),
                'fields_extracted': list(key_fields.keys())
            }
        })}

    except Exception as e:
        print(f"Error in PDF extraction: {str(e)}")
        import traceback
        traceback.print_exc()
        return {'statusCode': 500, 'body': json.dumps({
            'error': f'PDF extraction failed: {str(e)}',
            'error_type': type(e).__name__
        })}

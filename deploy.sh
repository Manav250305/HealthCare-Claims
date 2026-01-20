#!/bin/bash

################################################################################
# Healthcare Claims Intelligence System - Complete AWS Deployment Script
# This script deploys all components using AWS CLI
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
UNIQUE_ID=$(date +%s)  # Timestamp for unique names
PROJECT_NAME="healthcare-claims"

# Resource names
UPLOAD_BUCKET="${PROJECT_NAME}-uploads-${UNIQUE_ID}"
RESULTS_BUCKET="${PROJECT_NAME}-results-${UNIQUE_ID}"
DYNAMODB_TABLE="ClaimResults"
IAM_ROLE_NAME="HealthcareClaimsLambdaRole"
LAYER_NAME="pdf-processing-layer"

# Lambda function names
PDF_EXTRACTOR_FUNCTION="pdf-extractor"
RISK_SCORER_FUNCTION="risk-scorer"
ORCHESTRATOR_FUNCTION="claim-orchestrator"

# Temporary directories
WORK_DIR="$(pwd)/deployment-temp"
LAYER_DIR="${WORK_DIR}/layer"
LAMBDA_DIR="${WORK_DIR}/lambda-functions"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

cleanup() {
    print_info "Cleaning up temporary files..."
    rm -rf "${WORK_DIR}"
}

trap cleanup EXIT

################################################################################
# Pre-flight Checks
################################################################################

print_header "Pre-flight Checks"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI not found. Please install it first."
    exit 1
fi
print_success "AWS CLI found"

# Check Python
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 not found. Please install it first."
    exit 1
fi
print_success "Python 3 found"

# Check pip
if ! command -v pip3 &> /dev/null; then
    print_error "pip3 not found. Please install it first."
    exit 1
fi
print_success "pip3 found"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured. Run 'aws configure' first."
    exit 1
fi
print_success "AWS credentials configured"

print_info "Region: ${REGION}"
print_info "Account ID: ${ACCOUNT_ID}"

################################################################################
# Setup Work Directory
################################################################################

print_header "Setting up work directory"

mkdir -p "${WORK_DIR}"
mkdir -p "${LAYER_DIR}"
mkdir -p "${LAMBDA_DIR}"

print_success "Work directory created"

################################################################################
# Create S3 Buckets
################################################################################

print_header "Creating S3 Buckets"

# Upload bucket
aws s3api create-bucket \
    --bucket "${UPLOAD_BUCKET}" \
    --region "${REGION}" 2>/dev/null || print_info "Upload bucket may already exist"

aws s3api put-bucket-versioning \
    --bucket "${UPLOAD_BUCKET}" \
    --versioning-configuration Status=Enabled

print_success "Upload bucket created: ${UPLOAD_BUCKET}"

# Results bucket
aws s3api create-bucket \
    --bucket "${RESULTS_BUCKET}" \
    --region "${REGION}" 2>/dev/null || print_info "Results bucket may already exist"

aws s3api put-bucket-versioning \
    --bucket "${RESULTS_BUCKET}" \
    --versioning-configuration Status=Enabled

print_success "Results bucket created: ${RESULTS_BUCKET}"

################################################################################
# Create DynamoDB Table
################################################################################

print_header "Creating DynamoDB Table"

aws dynamodb create-table \
    --table-name "${DYNAMODB_TABLE}" \
    --attribute-definitions \
        AttributeName=claim_id,AttributeType=S \
        AttributeName=timestamp,AttributeType=N \
    --key-schema \
        AttributeName=claim_id,KeyType=HASH \
        AttributeName=timestamp,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}" 2>/dev/null || print_info "Table may already exist"

print_info "Waiting for table to become active..."
aws dynamodb wait table-exists --table-name "${DYNAMODB_TABLE}" --region "${REGION}"

print_success "DynamoDB table created: ${DYNAMODB_TABLE}"

################################################################################
# Create IAM Role
################################################################################

print_header "Creating IAM Role"

# Create trust policy
cat > "${WORK_DIR}/trust-policy.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role \
    --role-name "${IAM_ROLE_NAME}" \
    --assume-role-policy-document file://"${WORK_DIR}/trust-policy.json" \
    --description "Execution role for Healthcare Claims Lambda functions" \
    2>/dev/null || print_info "Role may already exist"

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${IAM_ROLE_NAME}"

# Attach managed policies
aws iam attach-role-policy \
    --role-name "${IAM_ROLE_NAME}" \
    --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

aws iam attach-role-policy \
    --role-name "${IAM_ROLE_NAME}" \
    --policy-arn "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"

aws iam attach-role-policy \
    --role-name "${IAM_ROLE_NAME}" \
    --policy-arn "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"

# Create inline policy for S3 write and Lambda invoke
cat > "${WORK_DIR}/inline-policy.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": "arn:aws:s3:::${RESULTS_BUCKET}/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-role-policy \
    --role-name "${IAM_ROLE_NAME}" \
    --policy-name "LambdaAdditionalPermissions" \
    --policy-document file://"${WORK_DIR}/inline-policy.json"

print_success "IAM role created: ${IAM_ROLE_NAME}"
print_info "Waiting 10 seconds for IAM role to propagate..."
sleep 10

################################################################################
# Build Lambda Layer
################################################################################

print_header "Building Lambda Layer"

mkdir -p "${LAYER_DIR}/python"

# Create requirements.txt
cat > "${LAYER_DIR}/requirements.txt" <<EOF
PyPDF2==3.0.1
pdfminer.six==20221105
pdfplumber==0.10.3
cryptography==41.0.7
EOF

# Install dependencies
print_info "Installing Python dependencies (this may take a few minutes)..."
pip3 install -r "${LAYER_DIR}/requirements.txt" -t "${LAYER_DIR}/python" --quiet

# Create zip
cd "${LAYER_DIR}"
zip -r9 ../layer.zip python/ > /dev/null
cd - > /dev/null

# Upload layer
LAYER_VERSION=$(aws lambda publish-layer-version \
    --layer-name "${LAYER_NAME}" \
    --description "PDF processing libraries for healthcare claims" \
    --zip-file fileb://"${LAYER_DIR}/../layer.zip" \
    --compatible-runtimes python3.9 python3.10 python3.11 \
    --region "${REGION}" \
    --query 'Version' \
    --output text)

LAYER_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:layer:${LAYER_NAME}:${LAYER_VERSION}"

print_success "Lambda layer created: ${LAYER_NAME} (version ${LAYER_VERSION})"

################################################################################
# Create Lambda Functions
################################################################################

print_header "Creating Lambda Functions"

# ============================================================================
# PDF Extractor Function
# ============================================================================

print_info "Creating PDF Extractor function..."

mkdir -p "${LAMBDA_DIR}/pdf-extractor"

cat > "${LAMBDA_DIR}/pdf-extractor/lambda_function.py" <<'EOFPDF'
import json
import boto3
import re
from io import BytesIO
import base64

try:
    import PyPDF2
    from pdfminer.high_level import extract_text as pdfminer_extract
    from pdfminer.layout import LAParams
except ImportError:
    print("PDF libraries not available - ensure Lambda layer is attached")

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

def extract_with_pdfminer(pdf_bytes):
    try:
        pdf_file = BytesIO(pdf_bytes)
        laparams = LAParams(line_margin=0.5, word_margin=0.1, char_margin=2.0, boxes_flow=0.5)
        text = pdfminer_extract(pdf_file, laparams=laparams)
        return clean_text(text)
    except Exception as e:
        print(f"PDFMiner extraction failed: {str(e)}")
        return None

def extract_key_fields(text):
    fields = {}
    patterns = {
        'phs_id': r'PHS ID[:\s]+([A-Z0-9]+)',
        'policy_no': r'Policy No[:\s]+(\d+)',
        'patient_name': r'Patient Name[:\s]+([A-Za-z\s]+?)(?=\s+Lal|\s+Mobile)',
        'insured_name': r'Insured Name[:\s]+([A-Za-z\s]+?)(?=\s+Employee|\s+No)',
        'mobile': r'Mobile No[:\s]+(\d{10})',
        'email': r'E-Mail ID[:\s]+([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})',
        'claim_type': r'Type of Claim[^:]*:[^A-Z]*(Main Hospitalization|Pre-Post Hospitalization|OPD Claim|Critical Illness)',
        'corporate_name': r'Name of Corporate[:\s]+([A-Za-z\s&.,]+?)(?=\n|Type of)',
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
        elif 'pdf_base64' in event:
            print("Decoding base64 PDF content")
            pdf_bytes = base64.b64decode(event['pdf_base64'])
        else:
            return {'statusCode': 400, 'body': json.dumps({'error': 'Missing PDF source'})}
        
        if not pdf_bytes:
            raise ValueError("Failed to retrieve PDF bytes")
        
        print(f"PDF size: {len(pdf_bytes)} bytes")
        
        extracted_text = None
        extraction_method = None
        
        extracted_text = extract_with_pdfminer(pdf_bytes)
        if extracted_text and len(extracted_text) > 100:
            extraction_method = "pdfminer"
            print("Successfully extracted with PDFMiner")
        else:
            extracted_text = extract_with_pypdf2(pdf_bytes)
            if extracted_text and len(extracted_text) > 100:
                extraction_method = "pypdf2"
                print("Successfully extracted with PyPDF2")
        
        if not extracted_text or len(extracted_text) < 50:
            return {'statusCode': 422, 'body': json.dumps({
                'error': 'Failed to extract meaningful text from PDF',
                'extraction_method': extraction_method,
                'text_length': len(extracted_text) if extracted_text else 0
            })}
        
        key_fields = extract_key_fields(extracted_text)
        
        print(f"Extracted {len(extracted_text)} characters of text")
        print(f"Found {len(key_fields)} key fields")
        
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
EOFPDF

cd "${LAMBDA_DIR}/pdf-extractor"
zip -r9 ../pdf-extractor.zip . > /dev/null
cd - > /dev/null

aws lambda create-function \
    --function-name "${PDF_EXTRACTOR_FUNCTION}" \
    --runtime python3.11 \
    --role "${ROLE_ARN}" \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://"${LAMBDA_DIR}/pdf-extractor.zip" \
    --timeout 60 \
    --memory-size 512 \
    --region "${REGION}" \
    --layers "${LAYER_ARN}" > /dev/null

print_success "PDF Extractor function created"

# ============================================================================
# Risk Scorer Function
# ============================================================================

print_info "Creating Risk Scorer function..."

mkdir -p "${LAMBDA_DIR}/risk-scorer"

cat > "${LAMBDA_DIR}/risk-scorer/lambda_function.py" <<'EOFRISK'
import json
import re
from datetime import datetime

def analyze_document_completeness(key_fields, full_text):
    required_docs = {
        'claim_form': r'IRDA Claim Form|Part-A|Part-B',
        'discharge_summary': r'Discharge Summary|discharge|admitted',
        'hospital_bill': r'Hospital bill|Final bill|Invoice',
        'payment_receipt': r'Payment Receipt|Receipt|paid',
        'prescriptions': r'Prescription|medicine|medication',
        'id_proof': r'ID Proof|Passport|Voter ID|Driving License',
        'cancelled_cheque': r'Cancelled Cheque|bank account'
    }
    missing_docs = []
    present_docs = []
    for doc_name, pattern in required_docs.items():
        if re.search(pattern, full_text, re.IGNORECASE):
            present_docs.append(doc_name)
        else:
            missing_docs.append(doc_name)
    completeness_score = (len(present_docs) / len(required_docs)) * 100
    return {
        'completeness_score': round(completeness_score, 2),
        'present_documents': present_docs,
        'missing_documents': missing_docs,
        'total_required': len(required_docs),
        'total_present': len(present_docs)
    }

def analyze_claim_type_risk(claim_type):
    risk_levels = {
        'OPD Claim': {'score': 20, 'level': 'low'},
        'Pre-Post Hospitalization': {'score': 40, 'level': 'medium'},
        'Main Hospitalization': {'score': 60, 'level': 'medium-high'},
        'Critical Illness': {'score': 85, 'level': 'high'},
        'Cash Benefit': {'score': 75, 'level': 'high'}
    }
    if not claim_type:
        return {'score': 50, 'level': 'unknown', 'reason': 'Claim type not identified'}
    for key, risk_data in risk_levels.items():
        if key.lower() in claim_type.lower():
            return {'score': risk_data['score'], 'level': risk_data['level'], 'claim_type': key}
    return {'score': 50, 'level': 'medium', 'reason': 'Unknown claim type'}

def check_submission_timeliness(submission_date_str):
    if not submission_date_str:
        return {'risk_score': 30, 'status': 'unknown', 'reason': 'Submission date not found'}
    try:
        submission_date = datetime.strptime(submission_date_str, '%d/%m/%Y')
        current_date = datetime.now()
        days_diff = (current_date - submission_date).days
        if days_diff <= 7:
            return {'risk_score': 0, 'status': 'on_time', 'days_since_submission': days_diff, 'reason': 'Submitted within required timeframe'}
        elif days_diff <= 30:
            return {'risk_score': 20, 'status': 'delayed', 'days_since_submission': days_diff, 'reason': f'Delayed by {days_diff - 7} days'}
        else:
            return {'risk_score': 40, 'status': 'severely_delayed', 'days_since_submission': days_diff, 'reason': f'Severely delayed by {days_diff - 7} days'}
    except Exception as e:
        return {'risk_score': 30, 'status': 'error', 'reason': f'Could not parse date: {str(e)}'}

def check_data_consistency(key_fields):
    issues = []
    risk_score = 0
    if 'mobile' in key_fields:
        mobile = key_fields['mobile']
        if not re.match(r'^\d{10}$', mobile):
            issues.append('Invalid mobile number format')
            risk_score += 15
    if 'email' in key_fields:
        email = key_fields['email']
        if not re.match(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', email):
            issues.append('Invalid email format')
            risk_score += 10
    if 'policy_no' in key_fields:
        policy = key_fields['policy_no']
        if not policy.isdigit() or len(policy) < 6:
            issues.append('Policy number format questionable')
            risk_score += 20
    if not key_fields.get('patient_name'):
        issues.append('Patient name missing')
        risk_score += 25
    if not key_fields.get('insured_name'):
        issues.append('Insured name missing')
        risk_score += 25
    return {'risk_score': min(risk_score, 100), 'issues': issues, 'has_issues': len(issues) > 0}

def detect_fraud_indicators(full_text, key_fields):
    indicators = []
    risk_score = 0
    fraud_patterns = {
        'multiple_claims': r'multiple claims|several claims|repeated',
        'duplicate_bills': r'duplicate|copied|same bill',
        'altered_documents': r'correction|modified|changed|altered',
        'round_numbers': r'(Rs\.?\s*(?:10000|20000|50000|100000)(?:\s|$))',
        'missing_signatures': r'signature\s+required|not\s+signed|unsigned'
    }
    for indicator_name, pattern in fraud_patterns.items():
        if re.search(pattern, full_text, re.IGNORECASE):
            indicators.append(indicator_name)
            risk_score += 20
    amount_match = re.search(r'(?:Rs\.?|INR)\s*(\d{1,3}(?:,\d{3})*)', full_text)
    if amount_match:
        amount_str = amount_match.group(1).replace(',', '')
        try:
            amount = int(amount_str)
            if amount > 500000:
                indicators.append('high_claim_amount')
                risk_score += 15
        except:
            pass
    return {'risk_score': min(risk_score, 100), 'indicators': indicators, 'has_fraud_indicators': len(indicators) > 0}

def calculate_overall_risk(analyses):
    weights = {
        'document_completeness': 0.30,
        'claim_type': 0.20,
        'submission_timeliness': 0.20,
        'data_consistency': 0.15,
        'fraud_indicators': 0.15
    }
    scores = {
        'document_completeness': 100 - analyses['document_completeness']['completeness_score'],
        'claim_type': analyses['claim_type_risk']['score'],
        'submission_timeliness': analyses['timeliness']['risk_score'],
        'data_consistency': analyses['data_consistency']['risk_score'],
        'fraud_indicators': analyses['fraud_indicators']['risk_score']
    }
    weighted_score = sum(scores[key] * weights[key] for key in weights.keys())
    if weighted_score < 30:
        risk_level = 'LOW'
        recommendation = 'AUTO_APPROVE'
        color = 'green'
    elif weighted_score < 60:
        risk_level = 'MEDIUM'
        recommendation = 'MANUAL_REVIEW'
        color = 'yellow'
    else:
        risk_level = 'HIGH'
        recommendation = 'DETAILED_INVESTIGATION'
        color = 'red'
    return {
        'overall_risk_score': round(weighted_score, 2),
        'risk_level': risk_level,
        'recommendation': recommendation,
        'color_code': color,
        'component_scores': scores,
        'weights_applied': weights
    }

def generate_recommendations(analyses, overall_risk):
    recommendations = []
    if analyses['document_completeness']['missing_documents']:
        missing = analyses['document_completeness']['missing_documents']
        recommendations.append({
            'category': 'Documentation',
            'priority': 'high',
            'action': f"Request missing documents: {', '.join(missing)}"
        })
    if analyses['timeliness']['status'] in ['delayed', 'severely_delayed']:
        recommendations.append({
            'category': 'Compliance',
            'priority': 'medium',
            'action': f"Obtain explanation for delayed submission ({analyses['timeliness']['days_since_submission']} days)"
        })
    if analyses['data_consistency']['has_issues']:
        for issue in analyses['data_consistency']['issues']:
            recommendations.append({
                'category': 'Data Quality',
                'priority': 'medium',
                'action': f"Verify and correct: {issue}"
            })
    if analyses['fraud_indicators']['has_fraud_indicators']:
        recommendations.append({
            'category': 'Fraud Prevention',
            'priority': 'critical',
            'action': f"Investigate fraud indicators: {', '.join(analyses['fraud_indicators']['indicators'])}"
        })
    if overall_risk['risk_level'] == 'HIGH':
        recommendations.append({
            'category': 'Risk Management',
            'priority': 'critical',
            'action': 'Escalate to senior claims adjuster for detailed review'
        })
    return recommendations

def lambda_handler(event, context):
    try:
        print(f"Received event keys: {list(event.keys())}")
        extracted_text = event.get('extracted_text', '')
        key_fields = event.get('key_fields', {})
        if not extracted_text:
            return {'statusCode': 400, 'body': json.dumps({'error': 'Missing extracted_text in event'})}
        print(f"Analyzing claim with {len(extracted_text)} characters of text")
        print(f"Key fields: {list(key_fields.keys())}")
        analyses = {
            'document_completeness': analyze_document_completeness(key_fields, extracted_text),
            'claim_type_risk': analyze_claim_type_risk(key_fields.get('claim_type')),
            'timeliness': check_submission_timeliness(key_fields.get('submission_date')),
            'data_consistency': check_data_consistency(key_fields),
            'fraud_indicators': detect_fraud_indicators(extracted_text, key_fields)
        }
        overall_risk = calculate_overall_risk(analyses)
        recommendations = generate_recommendations(analyses, overall_risk)
        result = {
            'claim_id': key_fields.get('phs_id', 'UNKNOWN'),
            'patient_name': key_fields.get('patient_name', 'UNKNOWN'),
            'analysis_timestamp': datetime.utcnow().isoformat(),
            'overall_risk': overall_risk,
            'detailed_analyses': analyses,
            'recommendations': recommendations,
            'key_fields': key_fields
        }
        print(f"Risk analysis complete. Overall risk: {overall_risk['risk_level']} ({overall_risk['overall_risk_score']})")
        return {'statusCode': 200, 'body': json.dumps(result, default=str)}
    except Exception as e:
        print(f"Error in risk scoring: {str(e)}")
        import traceback
        traceback.print_exc()
        return {'statusCode': 500, 'body': json.dumps({
            'error': f'Risk scoring failed: {str(e)}',
            'error_type': type(e).__name__
        })}
EOFRISK

cd "${LAMBDA_DIR}/risk-scorer"
zip -r9 ../risk-scorer.zip . > /dev/null
cd - > /dev/null

aws lambda create-function \
    --function-name "${RISK_SCORER_FUNCTION}" \
    --runtime python3.11 \
    --role "${ROLE_ARN}" \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://"${LAMBDA_DIR}/risk-scorer.zip" \
    --timeout 30 \
    --memory-size 256 \
    --region "${REGION}" > /dev/null

print_success "Risk Scorer function created"

# ============================================================================
# Orchestrator Function
# ============================================================================

print_info "Creating Orchestrator function..."

mkdir -p "${LAMBDA_DIR}/orchestrator"

cat > "${LAMBDA_DIR}/orchestrator/lambda_function.py" <<EOFORCH
import json
import boto3
from datetime import datetime

lambda_client = boto3.client('lambda')
s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

RESULTS_TABLE_NAME = '${DYNAMODB_TABLE}'
PDF_EXTRACTOR_FUNCTION = '${PDF_EXTRACTOR_FUNCTION}'
RISK_SCORER_FUNCTION = '${RISK_SCORER_FUNCTION}'
RESULTS_BUCKET = '${RESULTS_BUCKET}'

def update_claim_status(claim_id, status, data=None):
    try:
        table = dynamodb.Table(RESULTS_TABLE_NAME)
        item = {
            'claim_id': claim_id,
            'status': status,
            'last_updated': datetime.utcnow().isoformat(),
            'timestamp': int(datetime.utcnow().timestamp())
        }
        if data:
            item['data'] = json.dumps(data, default=str)
        table.put_item(Item=item)
        print(f"Updated claim {claim_id} status to {status}")
    except Exception as e:
        print(f"Error updating DynamoDB: {str(e)}")

def invoke_lambda(function_name, payload):
    try:
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
    except Exception as e:
        print(f"Error invoking {function_name}: {str(e)}")
        raise

def save_results_to_s3(claim_id, results):
    try:
        key = f"results/{claim_id}/{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.json"
        s3_client.put_object(
            Bucket=RESULTS_BUCKET,
            Key=key,
            Body=json.dumps(results, indent=2, default=str),
            ContentType='application/json'
        )
        print(f"Saved results to s3://{RESULTS_BUCKET}/{key}")
        return f"s3://{RESULTS_BUCKET}/{key}"
    except Exception as e:
        print(f"Error saving to S3: {str(e)}")
        return None

def lambda_handler(event, context):
    claim_id = None
    try:
        print(f"Orchestrator received event: {json.dumps(event)}")
        s3_bucket = event.get('s3_bucket')
        s3_key = event.get('s3_key')
        claim_id = event.get('claim_id', f"CLM-{int(datetime.utcnow().timestamp())}")
        
        if not s3_bucket or not s3_key:
            return {'statusCode': 400, 'body': json.dumps({'error': 'Missing s3_bucket or s3_key in event'})}
        
        update_claim_status(claim_id, 'PROCESSING_STARTED')
        print(f"Step 1: Extracting text from PDF")
        update_claim_status(claim_id, 'EXTRACTING_TEXT')
        
        extraction_result = invoke_lambda(PDF_EXTRACTOR_FUNCTION, {'s3_bucket': s3_bucket, 's3_key': s3_key})
        extracted_text = extraction_result.get('extracted_text')
        key_fields = extraction_result.get('key_fields', {})
        
        if not extracted_text:
            update_claim_status(claim_id, 'FAILED', {'error': 'Failed to extract text from PDF'})
            return {'statusCode': 422, 'body': json.dumps({'error': 'No text could be extracted from PDF', 'claim_id': claim_id})}
        
        print(f"Extracted {len(extracted_text)} characters")
        print(f"Step 2: Calculating risk score")
        update_claim_status(claim_id, 'CALCULATING_RISK')
        
        risk_result = invoke_lambda(RISK_SCORER_FUNCTION, {'extracted_text': extracted_text, 'key_fields': key_fields})
        
        final_results = {
            'claim_id': claim_id,
            'processing_timestamp': datetime.utcnow().isoformat(),
            'source_file': {'bucket': s3_bucket, 'key': s3_key},
            'extraction_results': {
                'method': extraction_result.get('extraction_method'),
                'text_length': extraction_result.get('text_length'),
                'key_fields': key_fields
            },
            'risk_analysis': risk_result,
            'workflow_status': 'COMPLETED'
        }
        
        results_url = save_results_to_s3(claim_id, final_results)
        if results_url:
            final_results['results_url'] = results_url
        
        update_claim_status(claim_id, 'COMPLETED', final_results)
        print(f"Claim processing completed successfully for {claim_id}")
        
        return {'statusCode': 200, 'body': json.dumps({
            'message': 'Claim processing completed successfully',
            'claim_id': claim_id,
            'risk_level': risk_result['overall_risk']['risk_level'],
            'risk_score': risk_result['overall_risk']['overall_risk_score'],
            'recommendation': risk_result['overall_risk']['recommendation'],
            'results': final_results
        }, default=str)}
        
    except Exception as e:
        error_msg = f"Orchestration failed: {str(e)}"
        print(error_msg)
        import traceback
        traceback.print_exc()
        if claim_id:
            update_claim_status(claim_id, 'FAILED', {'error': str(e), 'error_type': type(e).__name__})
        return {'statusCode': 500, 'body': json.dumps({'error': error_msg, 'claim_id': claim_id})}
EOFORCH

cd "${LAMBDA_DIR}/orchestrator"
zip -r9 ../orchestrator.zip . > /dev/null
cd - > /dev/null

aws lambda create-function \
    --function-name "${ORCHESTRATOR_FUNCTION}" \
    --runtime python3.11 \
    --role "${ROLE_ARN}" \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://"${LAMBDA_DIR}/orchestrator.zip" \
    --timeout 300 \
    --memory-size 512 \
    --region "${REGION}" > /dev/null

print_success "Orchestrator function created"

################################################################################
# Create API Gateway (Optional)
################################################################################

print_header "Creating API Gateway"

API_NAME="${PROJECT_NAME}-api"

# Create REST API
API_ID=$(aws apigateway create-rest-api \
    --name "${API_NAME}" \
    --description "Healthcare Claims Processing API" \
    --region "${REGION}" \
    --query 'id' \
    --output text)

print_success "API Gateway created: ${API_ID}"

# Get root resource ID
ROOT_ID=$(aws apigateway get-resources \
    --rest-api-id "${API_ID}" \
    --region "${REGION}" \
    --query 'items[0].id' \
    --output text)

# Create /process-claim resource
RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id "${API_ID}" \
    --parent-id "${ROOT_ID}" \
    --path-part "process-claim" \
    --region "${REGION}" \
    --query 'id' \
    --output text)

# Create POST method
aws apigateway put-method \
    --rest-api-id "${API_ID}" \
    --resource-id "${RESOURCE_ID}" \
    --http-method POST \
    --authorization-type NONE \
    --region "${REGION}" > /dev/null

# Set up Lambda integration
aws apigateway put-integration \
    --rest-api-id "${API_ID}" \
    --resource-id "${RESOURCE_ID}" \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:${ORCHESTRATOR_FUNCTION}/invocations" \
    --region "${REGION}" > /dev/null

# Grant API Gateway permission to invoke Lambda
aws lambda add-permission \
    --function-name "${ORCHESTRATOR_FUNCTION}" \
    --statement-id apigateway-invoke \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*" \
    --region "${REGION}" > /dev/null

# Deploy API
aws apigateway create-deployment \
    --rest-api-id "${API_ID}" \
    --stage-name prod \
    --region "${REGION}" > /dev/null

API_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod/process-claim"

print_success "API deployed: ${API_URL}"

################################################################################
# Create Test Event
################################################################################

print_header "Creating Test Data"

# Upload sample PDF if available
TEST_PDF_KEY="test-claims/sample-claim.pdf"

if [ -f "Filled-1.pdf" ]; then
    aws s3 cp Filled-1.pdf "s3://${UPLOAD_BUCKET}/${TEST_PDF_KEY}"
    print_success "Sample PDF uploaded to s3://${UPLOAD_BUCKET}/${TEST_PDF_KEY}"
    SAMPLE_PDF_AVAILABLE=true
else
    print_info "Sample PDF 'Filled-1.pdf' not found in current directory"
    print_info "You can upload it manually to s3://${UPLOAD_BUCKET}/${TEST_PDF_KEY}"
    SAMPLE_PDF_AVAILABLE=false
fi

################################################################################
# Generate Configuration File
################################################################################

print_header "Generating Configuration File"

cat > "${WORK_DIR}/deployment-config.json" <<EOF
{
  "deployment_info": {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "region": "${REGION}",
    "account_id": "${ACCOUNT_ID}"
  },
  "resources": {
    "s3_buckets": {
      "upload_bucket": "${UPLOAD_BUCKET}",
      "results_bucket": "${RESULTS_BUCKET}"
    },
    "dynamodb": {
      "table_name": "${DYNAMODB_TABLE}"
    },
    "lambda_functions": {
      "pdf_extractor": "${PDF_EXTRACTOR_FUNCTION}",
      "risk_scorer": "${RISK_SCORER_FUNCTION}",
      "orchestrator": "${ORCHESTRATOR_FUNCTION}"
    },
    "lambda_layer": {
      "name": "${LAYER_NAME}",
      "arn": "${LAYER_ARN}"
    },
    "iam_role": {
      "name": "${IAM_ROLE_NAME}",
      "arn": "${ROLE_ARN}"
    },
    "api_gateway": {
      "api_id": "${API_ID}",
      "url": "${API_URL}"
    }
  },
  "test_event": {
    "s3_bucket": "${UPLOAD_BUCKET}",
    "s3_key": "${TEST_PDF_KEY}",
    "claim_id": "TEST-001"
  }
}
EOF

cp "${WORK_DIR}/deployment-config.json" ./deployment-config.json

print_success "Configuration saved to deployment-config.json"

################################################################################
# Create Test Script
################################################################################

cat > test-claim-processing.sh <<'EOFTEST'
#!/bin/bash

# Load configuration
CONFIG_FILE="deployment-config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: deployment-config.json not found"
    exit 1
fi

ORCHESTRATOR_FUNCTION=$(jq -r '.resources.lambda_functions.orchestrator' $CONFIG_FILE)
UPLOAD_BUCKET=$(jq -r '.resources.s3_buckets.upload_bucket' $CONFIG_FILE)
TEST_KEY=$(jq -r '.test_event.s3_key' $CONFIG_FILE)

echo "Testing Healthcare Claims Processing System"
echo "==========================================="
echo ""
echo "Invoking: $ORCHESTRATOR_FUNCTION"
echo "PDF: s3://$UPLOAD_BUCKET/$TEST_KEY"
echo ""

# Create test payload
PAYLOAD=$(cat <<EOF
{
  "s3_bucket": "$UPLOAD_BUCKET",
  "s3_key": "$TEST_KEY",
  "claim_id": "TEST-$(date +%s)"
}
EOF
)

# Invoke Lambda
aws lambda invoke \
    --function-name "$ORCHESTRATOR_FUNCTION" \
    --payload "$PAYLOAD" \
    --cli-binary-format raw-in-base64-out \
    response.json

echo ""
echo "Response:"
cat response.json | jq '.'

echo ""
echo "Check DynamoDB table and S3 results bucket for detailed output"
EOFTEST

chmod +x test-claim-processing.sh

print_success "Test script created: test-claim-processing.sh"

################################################################################
# Summary
################################################################################

print_header "Deployment Complete! 🎉"

echo -e "${GREEN}All resources have been successfully deployed!${NC}"
echo ""
echo -e "${BLUE}Resource Summary:${NC}"
echo "─────────────────────────────────────────────────"
echo ""
echo "📦 S3 Buckets:"
echo "   Upload:  ${UPLOAD_BUCKET}"
echo "   Results: ${RESULTS_BUCKET}"
echo ""
echo "💾 DynamoDB Table:"
echo "   ${DYNAMODB_TABLE}"
echo ""
echo "⚡ Lambda Functions:"
echo "   1. ${PDF_EXTRACTOR_FUNCTION}"
echo "   2. ${RISK_SCORER_FUNCTION}"
echo "   3. ${ORCHESTRATOR_FUNCTION}"
echo ""
echo "🔐 IAM Role:"
echo "   ${IAM_ROLE_NAME}"
echo ""
echo "🌐 API Gateway:"
echo "   ${API_URL}"
echo ""
echo "─────────────────────────────────────────────────"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
if [ "$SAMPLE_PDF_AVAILABLE" = true ]; then
    echo "1. Test the system:"
    echo "   ./test-claim-processing.sh"
    echo ""
else
    echo "1. Upload a claim PDF:"
    echo "   aws s3 cp your-claim.pdf s3://${UPLOAD_BUCKET}/${TEST_PDF_KEY}"
    echo ""
    echo "2. Test the system:"
    echo "   ./test-claim-processing.sh"
    echo ""
fi
echo "2. View results in DynamoDB:"
echo "   aws dynamodb scan --table-name ${DYNAMODB_TABLE}"
echo ""
echo "3. Check S3 results:"
echo "   aws s3 ls s3://${RESULTS_BUCKET}/results/ --recursive"
echo ""
echo "4. Monitor CloudWatch Logs:"
echo "   aws logs tail /aws/lambda/${ORCHESTRATOR_FUNCTION} --follow"
echo ""
echo "5. Test via API:"
echo "   curl -X POST ${API_URL} \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"s3_bucket\":\"${UPLOAD_BUCKET}\",\"s3_key\":\"${TEST_PDF_KEY}\",\"claim_id\":\"API-TEST-001\"}'"
echo ""
echo "─────────────────────────────────────────────────"
echo ""
echo -e "${GREEN}Configuration saved to: deployment-config.json${NC}"
echo ""
print_info "Total deployment time: $SECONDS seconds"
echo ""

// --- Add these two interfaces at the top ---
export interface UploadUrlResponse {
  upload_url: string;
  s3_bucket: string;
  s3_key: string;
  expires_in: number;
}

export interface UploadUrlRequest {
  filename: string;
}

// --- Your existing analysis types ---
export interface DocumentCompleteness {
  score: number;
  total_present: number;
  total_required: number;
  present_documents: string[];
  missing_documents: string[];
  critical_missing: string[];
  notes: string;
}

export interface FraudIndicators {
  detected: boolean;
  severity: "critical" | "high" | "medium" | "low";
  confidence: number;
  investigation_priority: "urgent" | "high" | "medium" | "low";
  categories_detected: string[];
  indicators: string[];
}

export interface ClaimSummary {
  claim_type: string;
  patient_name: string;
  policy_number: string;
  phs_id: string;
  insured_name: string;
  submission_date: string;
  estimated_amount: string;
  hospital_details: string;
  treatment_dates: string;
}

export interface ProcessClaimResponse {
  status: "success" | "error";
  claim_id: string;
  risk_score: number;
  risk_level: "CRITICAL" | "HIGH" | "MEDIUM" | "LOW" | "VERY_LOW";
  recommendation: "REJECT" | "DETAILED_INVESTIGATION" | "MANUAL_REVIEW" | "AUTO_APPROVE";
  processing_time_seconds: string;
  textract_time_seconds: string;
  ai_time_seconds: string;
  extracted_fields_count: number;
  tables_found: number;
  results_url: string;
  document_completeness: DocumentCompleteness;
  fraud_indicators: FraudIndicators;
  key_findings: string[];
  claim_summary?: ClaimSummary;
}
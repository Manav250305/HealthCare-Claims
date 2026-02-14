'use client';
import { motion } from 'framer-motion';
import { ProcessClaimResponse } from '@/types/claims';
import { SequentialTypewriter } from '../ui/TypewriterText';
import { RiskGauge } from '../ui/RiskGauge';
import { 
  CheckCircle, 
  AlertTriangle, 
  XCircle, 
  RefreshCcw, 
  FileWarning, 
  User, 
  Calendar, 
  Activity 
} from 'lucide-react';

export const ResultsView = ({ data, onReset }: { data: ProcessClaimResponse, onReset: () => void }) => {
  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 h-[85vh] overflow-y-auto pr-2 pb-10 scrollbar-hide">
      
      {/* LEFT COLUMN: RISK & ACTIONS */}
      <motion.div 
        className="lg:col-span-1 space-y-6"
        initial={{ x: -30, opacity: 0 }}
        animate={{ x: 0, opacity: 1 }}
      >
        {/* Main Status Card */}
        <div className="bg-white rounded-3xl shadow-xl p-6 border-t-8 border-blue-600">
          <h2 className="text-slate-400 text-xs font-black uppercase tracking-widest mb-4">Risk Decision</h2>
          <div className="mb-6">
             <div className="text-2xl font-black text-slate-800 break-words [word-break:break-word]">
                {data.recommendation.replace(/_/g, ' ')}
             </div>
             <p className="text-sm text-slate-500 font-medium">Priority: <span className="text-orange-600 uppercase">{data.fraud_indicators.investigation_priority}</span></p>
          </div>
          
          <div className="flex justify-center py-2">
            <RiskGauge score={data.risk_score} />
          </div>

          <div className="grid grid-cols-2 gap-3 mt-6">
             <div className="bg-slate-50 p-4 rounded-2xl border border-slate-100">
                <p className="text-[10px] text-slate-400 uppercase font-bold">Total Time</p>
                <p className="text-lg font-mono font-black text-blue-600">{data.processing_time_seconds}s</p>
             </div>
             <div className="bg-slate-50 p-4 rounded-2xl border border-slate-100">
                <p className="text-[10px] text-slate-400 uppercase font-bold">Confidence</p>
                <p className="text-lg font-mono font-black text-indigo-600">{data.fraud_indicators.confidence}%</p>
             </div>
          </div>
        </div>

        {/* Critical Fraud Alerts */}
        {data.fraud_indicators.detected && (
           <motion.div 
             className="bg-red-50 rounded-3xl p-6 border border-red-100 shadow-inner"
             initial={{ y: 20, opacity: 0 }}
             animate={{ y: 0, opacity: 1 }}
             transition={{ delay: 0.3 }}
           >
             <div className="flex items-center gap-2 text-red-700 font-black text-sm mb-3 uppercase tracking-tight">
               <AlertTriangle className="w-5 h-5" />
               Fraud Indicators Detected
             </div>
             <ul className="space-y-3">
               {data.fraud_indicators.indicators.map((ind, i) => (
                 <li key={i} className="text-xs text-red-800 leading-relaxed flex gap-2">
                    <span className="shrink-0">•</span> {ind}
                 </li>
               ))}
             </ul>
           </motion.div>
        )}
      </motion.div>

      {/* RIGHT COLUMN: DETAILED INSIGHTS */}
      <motion.div 
        className="lg:col-span-2 space-y-6 flex flex-col"
        initial={{ y: 30, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.2 }}
      >
        {/* AI Key Findings */}
        <div className="bg-slate-900 rounded-3xl shadow-2xl p-8 text-white">
          <h3 className="text-xl font-bold mb-6 flex items-center gap-3">
            <span className="bg-blue-500 p-2 rounded-lg">🤖</span> AI Analysis Findings
          </h3>
          <SequentialTypewriter lines={data.key_findings} />
        </div>

        {/* Claim Summary Data (If available) */}
        {data.claim_summary && (
          <div className="bg-white rounded-3xl shadow-lg p-8 border border-slate-100">
            <h3 className="text-lg font-bold text-slate-800 mb-6 flex items-center gap-2">
              <User className="w-5 h-5 text-blue-500" /> Extracted Claim Details
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {[
                { label: 'Patient Name', value: data.claim_summary.patient_name, icon: User },
                { label: 'Policy #', value: data.claim_summary.policy_number, icon: Activity },
                { label: 'Treatment Dates', value: data.claim_summary.treatment_dates, icon: Calendar },
                { label: 'Est. Amount', value: data.claim_summary.estimated_amount, icon: CheckCircle },
              ].map((item, idx) => (
                <div key={idx} className="flex items-center gap-4 bg-slate-50 p-4 rounded-2xl">
                   <item.icon className="w-5 h-5 text-slate-400" />
                   <div>
                      <p className="text-[10px] uppercase font-black text-slate-400">{item.label}</p>
                      <p className="text-sm font-bold text-slate-700">{item.value || 'N/A'}</p>
                   </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Document Checklist */}
        <div className="bg-white rounded-3xl shadow-lg p-8 border border-slate-100">
          <h3 className="text-lg font-bold text-slate-800 mb-6 flex items-center gap-2">
            <FileWarning className="w-5 h-5 text-blue-500" /> Document Audit
          </h3>
          
          <div className="space-y-6">
            {/* Critical Missing Section */}
            {data.document_completeness.critical_missing.length > 0 && (
              <div className="bg-red-50 p-5 rounded-2xl border border-red-200">
                <h4 className="text-red-700 font-black text-xs uppercase mb-3 flex items-center gap-2">
                  <XCircle className="w-4 h-4" /> Critical Missing Documents
                </h4>
                <div className="flex flex-wrap gap-2">
                  {data.document_completeness.critical_missing.map((doc, i) => (
                    <span key={i} className="bg-white text-red-600 text-xs font-bold px-3 py-2 rounded-xl border border-red-100 shadow-sm">
                      {doc}
                    </span>
                  ))}
                </div>
              </div>
            )}

            <div className="grid md:grid-cols-2 gap-8">
              <div>
                <h4 className="text-slate-400 font-bold text-xs uppercase mb-4 flex items-center gap-2">
                  <CheckCircle className="w-4 h-4 text-green-500" /> Present ({data.document_completeness.total_present})
                </h4>
                <ul className="space-y-2">
                  {data.document_completeness.present_documents.map((doc, i) => (
                    <li key={i} className="text-[11px] font-medium text-slate-600 bg-green-50/50 p-2 rounded-lg border border-green-100/50">
                      {doc}
                    </li>
                  ))}
                </ul>
              </div>
              <div>
                <h4 className="text-slate-400 font-bold text-xs uppercase mb-4 flex items-center gap-2">
                  <AlertTriangle className="w-4 h-4 text-slate-300" /> Others Missing
                </h4>
                <ul className="space-y-2">
                  {data.document_completeness.missing_documents.map((doc, i) => (
                    <li key={i} className="text-[11px] font-medium text-slate-400 bg-slate-50 p-2 rounded-lg border border-slate-100 italic">
                      {doc}
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          </div>
        </div>

        {/* Action Bar (Removed sticky positioning) */}
        <div className="flex justify-between items-center bg-white border border-slate-200 shadow-sm p-5 rounded-3xl mt-auto">
          <p className="text-xs text-slate-400 italic">Analysis Result ID: {data.claim_id}</p>
          <button 
            onClick={onReset}
            className="flex items-center gap-2 bg-blue-600 text-white px-8 py-4 rounded-2xl font-bold hover:bg-blue-700 transition-all hover:scale-105 shadow-xl active:scale-95"
          >
            <RefreshCcw className="w-5 h-5" /> Start New Claim
          </button>
        </div>
      </motion.div>
    </div>
  );
};
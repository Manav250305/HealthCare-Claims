'use client';
import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ProcessClaimResponse } from '@/types/claims';
import { SequentialTypewriter } from '../ui/TypewriterText';
import { RiskGauge } from '../ui/RiskGauge';
import { 
  CheckCircle, AlertTriangle, XCircle, RefreshCcw, 
  FileText, X, ShieldAlert, FileCheck, Info
} from 'lucide-react';

export const ResultsView = ({ data, onReset }: { data: ProcessClaimResponse, onReset: () => void }) => {
  const [showReport, setShowReport] = useState(false);

  return (
    <>
      <div className="flex flex-col h-[85vh]">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 overflow-y-auto pr-2 pb-6 scrollbar-hide flex-1">
          
          {/* LEFT COLUMN: RISK & GAUGES */}
          <motion.div className="lg:col-span-1 space-y-6" initial={{ x: -30, opacity: 0 }} animate={{ x: 0, opacity: 1 }}>
            
            {/* Main Status Card */}
            <div className="bg-white/10 backdrop-blur-md rounded-3xl shadow-xl p-6 border border-white/20 border-t-8 border-t-blue-500">
              
              {/* HEADER WITH NEW QUICK-ACCESS REPORT BUTTON */}
              <div className="flex justify-between items-center mb-4">
                <h2 className="text-slate-400 text-xs font-black uppercase tracking-widest flex items-center gap-2">
                  <ShieldAlert className="w-4 h-4" /> Risk Decision
                </h2>
                <button 
                  onClick={() => setShowReport(true)}
                  className="text-[10px] font-bold text-blue-400 hover:text-white flex items-center gap-1 bg-blue-500/10 hover:bg-blue-500/30 px-2 py-1.5 rounded-lg transition-all border border-blue-500/20"
                >
                  <FileText className="w-3 h-3" /> VIEW REPORT
                </button>
              </div>

              <div className="mb-6">
                <div className="text-2xl font-black text-white break-words">
                  {data.recommendation === 'REJECT' ? 'INVESTIGATION REQUIRED' : 'APPROVE CLAIM'}
                </div>
                <div className={`mt-2 inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-bold ${
                  data.risk_level === 'HIGH' ? 'bg-red-500/20 text-red-400 border border-red-500/50' : 
                  'bg-green-500/20 text-green-400 border border-green-500/50'
                }`}>
                  {data.risk_level === 'HIGH' ? <XCircle className="w-4 h-4" /> : <CheckCircle className="w-4 h-4" />}
                  {data.risk_level} RISK DETECTED
                </div>
              </div>
              <div className="flex justify-center py-4 bg-slate-900/50 rounded-2xl border border-white/5">
                <RiskGauge score={data.risk_score} />
              </div>
            </div>

            {/* Document Completeness */}
            <div className="bg-white/10 backdrop-blur-md rounded-3xl shadow-xl p-6 border border-white/20">
              <h3 className="text-slate-400 text-xs font-black uppercase tracking-widest mb-4 flex items-center gap-2">
                <FileCheck className="w-4 h-4" /> Document Verification
              </h3>
              <div className="space-y-4">
                <div>
                  <h4 className="text-slate-300 font-bold text-xs uppercase mb-2 flex items-center gap-2">
                    <CheckCircle className="w-4 h-4 text-green-400" /> Present ({data.document_completeness.total_present})
                  </h4>
                  <ul className="space-y-2">
                    {data.document_completeness.present_documents.map((doc, i) => (
                      <li key={i} className="text-[11px] font-medium text-green-400 bg-green-500/10 p-2 rounded-lg border border-green-500/20">
                        {doc}
                      </li>
                    ))}
                  </ul>
                </div>
                <div>
                  <h4 className="text-slate-300 font-bold text-xs uppercase mb-2 flex items-center gap-2">
                    <AlertTriangle className="w-4 h-4 text-orange-400" /> Missing Documents
                  </h4>
                  <ul className="space-y-2">
                    {data.document_completeness.missing_documents.map((doc, i) => (
                      <li key={i} className="text-[11px] font-medium text-orange-400 bg-orange-500/10 p-2 rounded-lg border border-orange-500/20 italic">
                        {doc}
                      </li>
                    ))}
                  </ul>
                </div>
              </div>
            </div>
          </motion.div>

          {/* RIGHT COLUMN: AI ANALYSIS */}
          <motion.div className="lg:col-span-2 space-y-6" initial={{ y: 30, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ delay: 0.2 }}>
            <div className="bg-slate-900/80 backdrop-blur-xl rounded-3xl shadow-2xl p-8 border border-white/10 h-full">
              <h2 className="text-xl font-bold text-white mb-6 flex items-center gap-3 border-b border-white/10 pb-4">
                <Info className="w-6 h-6 text-blue-400" />
                AI Investigation Findings
              </h2>
              
              <div className="bg-black/40 rounded-2xl p-6 border border-white/5 font-mono text-sm">
                <SequentialTypewriter lines={data.key_findings} />
              </div>

              {data.fraud_indicators.detected && (
                <div className="mt-6 bg-red-500/10 border border-red-500/30 rounded-2xl p-6">
                  <h3 className="text-red-400 font-bold mb-3 flex items-center gap-2">
                    <AlertTriangle className="w-5 h-5" /> Fraud Indicators Triggered
                  </h3>
                  <ul className="list-disc list-inside text-slate-300 space-y-1">
                    {data.fraud_indicators.indicators.map((ind, i) => (
                      <li key={i}>{ind}</li>
                    ))}
                  </ul>
                  <p className="mt-4 text-xs text-red-400/70 uppercase tracking-wider font-bold">
                    Investigation Priority: {data.fraud_indicators.investigation_priority}
                  </p>
                </div>
              )}
            </div>
          </motion.div>
        </div>

        {/* BOTTOM ACTION BAR */}
        <div className="flex justify-between items-center bg-slate-900/80 backdrop-blur-xl border border-white/10 p-5 rounded-3xl mt-4 shrink-0">
          <p className="text-xs text-slate-400 hidden sm:block">ID: <span className="font-mono text-blue-400">{data.claim_id}</span></p>
          <div className="flex gap-4 w-full sm:w-auto">
            <button 
              onClick={() => setShowReport(true)}
              className="flex-1 sm:flex-none flex items-center justify-center gap-2 bg-slate-800 text-white px-6 py-3 rounded-xl font-bold hover:bg-slate-700 transition-all border border-white/10"
            >
              <FileText className="w-4 h-4" /> Full Report
            </button>
            <button 
              onClick={onReset}
              className="flex-1 sm:flex-none flex items-center justify-center gap-2 bg-blue-600 text-white px-6 py-3 rounded-xl font-bold hover:bg-blue-500 transition-all shadow-lg shadow-blue-500/25"
            >
              <RefreshCcw className="w-4 h-4" /> New Claim
            </button>
          </div>
        </div>
      </div>

      {/* FULL REPORT MODAL */}
      <AnimatePresence>
        {showReport && (
          <motion.div 
            initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6 bg-black/80 backdrop-blur-sm"
          >
            <motion.div 
              initial={{ scale: 0.95, y: 20 }} animate={{ scale: 1, y: 0 }} exit={{ scale: 0.95, y: 20 }}
              className="bg-slate-900 border border-white/20 rounded-3xl w-full max-w-4xl max-h-[90vh] flex flex-col shadow-2xl overflow-hidden"
            >
              <div className="flex justify-between items-center p-6 border-b border-white/10 bg-slate-800/50">
                <div>
                  <h2 className="text-xl font-bold text-white">Comprehensive Analysis Report</h2>
                  <p className="text-slate-400 text-sm font-mono mt-1">Claim: {data.claim_id}</p>
                </div>
                <button onClick={() => setShowReport(false)} className="p-2 text-slate-400 hover:text-white hover:bg-white/10 rounded-full transition-colors">
                  <X className="w-6 h-6" />
                </button>
              </div>

              <div className="p-6 overflow-y-auto space-y-6">
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  <div className="bg-slate-800/50 p-4 rounded-xl border border-white/5">
                    <p className="text-slate-400 text-xs mb-1">Processed In</p>
                    <p className="text-white font-bold">{data.processing_time_seconds}s</p>
                  </div>
                  <div className="bg-slate-800/50 p-4 rounded-xl border border-white/5">
                    <p className="text-slate-400 text-xs mb-1">AI Confidence</p>
                    <p className="text-white font-bold">{data.fraud_indicators.confidence}%</p>
                  </div>
                  <div className="bg-slate-800/50 p-4 rounded-xl border border-white/5">
                    <p className="text-slate-400 text-xs mb-1">Assigned User</p>
                    <p className="text-white font-bold truncate" title={data.user_id}>{data.user_id}</p>
                  </div>
                  <div className="bg-slate-800/50 p-4 rounded-xl border border-white/5">
                    <p className="text-slate-400 text-xs mb-1">Timestamp</p>
                    <p className="text-white font-bold">{new Date(parseInt(data.timestamp)).toLocaleDateString()}</p>
                  </div>
                </div>

                <div>
                  <h3 className="text-white font-bold mb-3 flex items-center gap-2">
                    <FileText className="w-4 h-4 text-blue-400" /> Raw AI Output (JSON)
                  </h3>
                  <div className="bg-black/60 rounded-xl p-4 border border-white/10 overflow-x-auto">
                    <pre className="text-green-400 font-mono text-xs leading-relaxed">
                      {JSON.stringify(data, null, 2)}
                    </pre>
                  </div>
                </div>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
};
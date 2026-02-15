'use client';

import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { 
  Search, Filter, Eye, AlertTriangle, 
  CheckCircle, XCircle, FileText, ChevronLeft, ChevronRight, X, Calendar, Activity
} from 'lucide-react';
import { ProcessClaimResponse } from '@/types/claims';

export default function ClaimsHistoryPage() {
  const [claims, setClaims] = useState<ProcessClaimResponse[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [riskFilter, setRiskFilter] = useState('ALL');
  const [page, setPage] = useState(1);
  const [selectedClaim, setSelectedClaim] = useState<ProcessClaimResponse | null>(null);

  // Fetch claims from your DynamoDB API
  useEffect(() => {
    const fetchClaims = async () => {
      setLoading(true);
      try {
        const res = await fetch(`/api/claims/history?page=${page}&risk_level=${riskFilter}`);
        if (res.ok) {
          const data = await res.json();
          setClaims(data.claims || []);
        }
      } catch (error) {
        console.error("Failed to fetch claims", error);
      } finally {
        setLoading(false);
      }
    };

    fetchClaims();
  }, [page, riskFilter]);

  // Client-side search filtering
  const filteredClaims = claims.filter(claim => 
    claim.claim_id.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="p-4 sm:p-6 lg:p-8 max-w-7xl mx-auto min-h-[calc(100vh-4rem)]">
      
      {/* Header Section */}
      <motion.div initial={{ opacity: 0, y: -20 }} animate={{ opacity: 1, y: 0 }} className="mb-8">
        <h1 className="text-3xl font-bold text-white mb-2">Claim History</h1>
        <p className="text-slate-400">View and audit previously analyzed claims</p>
      </motion.div>

      {/* Controls Section (Search & Filter) */}
      <motion.div 
        initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }}
        className="flex flex-col md:flex-row gap-4 justify-between items-center bg-white/5 backdrop-blur-xl border border-white/10 p-4 rounded-2xl mb-6 shadow-xl"
      >
        <div className="relative w-full md:w-96">
          <Search className="absolute left-4 top-3.5 w-5 h-5 text-slate-400" />
          <input
            type="text"
            placeholder="Search Claim ID..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full bg-slate-900/80 border border-slate-600 text-white pl-12 pr-4 py-3 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none placeholder:text-slate-500 transition-all shadow-inner"
          />
        </div>

        <div className="flex items-center gap-3 w-full md:w-auto">
          <div className="p-3 bg-blue-500/10 rounded-xl border border-blue-500/20">
            <Filter className="w-5 h-5 text-blue-400" />
          </div>
          <select
            value={riskFilter}
            onChange={(e) => setRiskFilter(e.target.value)}
            className="bg-slate-900/80 border border-slate-600 text-white px-4 py-3 rounded-xl focus:ring-2 focus:ring-blue-500 outline-none w-full md:w-48 appearance-none shadow-inner cursor-pointer"
          >
            <option value="ALL">All Risk Levels</option>
            <option value="HIGH">High Risk</option>
            <option value="MEDIUM">Medium Risk</option>
            <option value="LOW">Low Risk</option>
          </select>
        </div>
      </motion.div>

      {/* Table Section */}
      <motion.div 
        initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }}
        className="bg-white/5 backdrop-blur-xl border border-white/20 rounded-3xl overflow-hidden shadow-2xl"
      >
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-slate-900/80 border-b border-white/10">
                <th className="p-5 text-xs font-bold text-slate-400 uppercase tracking-wider">Claim ID</th>
                <th className="p-5 text-xs font-bold text-slate-400 uppercase tracking-wider">Date Analyzed</th>
                <th className="p-5 text-xs font-bold text-slate-400 uppercase tracking-wider">Risk Score</th>
                <th className="p-5 text-xs font-bold text-slate-400 uppercase tracking-wider">AI Decision</th>
                <th className="p-5 text-xs font-bold text-slate-400 uppercase tracking-wider text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5">
              {loading ? (
                // Shimmering Skeleton Loader Rows
                [...Array(6)].map((_, i) => (
                  <tr key={i} className="border-b border-white/5">
                    <td className="p-5">
                      <div className="h-4 bg-slate-800/80 rounded animate-pulse w-24" />
                    </td>
                    <td className="p-5">
                      <div className="flex items-center gap-2">
                        <div className="w-4 h-4 bg-slate-800/80 rounded animate-pulse" />
                        <div className="h-4 bg-slate-800/80 rounded animate-pulse w-28" />
                      </div>
                    </td>
                    <td className="p-5">
                      <div className="flex items-center gap-3">
                        <div className="h-4 bg-slate-800/80 rounded animate-pulse w-6" />
                        <div className="w-16 h-2 bg-slate-800/50 rounded-full overflow-hidden hidden sm:block">
                          <div className="h-full bg-slate-700/80 animate-pulse w-full" />
                        </div>
                      </div>
                    </td>
                    <td className="p-5">
                      <div className="h-6 bg-slate-800/80 rounded-full animate-pulse w-20" />
                    </td>
                    <td className="p-5 text-right">
                      <div className="h-8 w-8 bg-slate-800/80 rounded-lg animate-pulse ml-auto" />
                    </td>
                  </tr>
                ))
              ) : filteredClaims.length === 0 ? (
                <tr>
                  <td colSpan={5} className="p-12 text-center text-slate-400">
                    <AlertTriangle className="w-12 h-12 text-slate-600 mx-auto mb-4" />
                    <p className="text-lg font-medium text-slate-300">No claims found</p>
                    <p className="text-sm mt-1">Try adjusting your filters or search term.</p>
                  </td>
                </tr>
              ) : (
                filteredClaims.map((claim, idx) => (
                  <motion.tr 
                    key={claim.claim_id}
                    initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: idx * 0.05 }}
                    className="border-b border-white/5 hover:bg-white/10 transition-colors group"
                  >
                    <td className="p-5 font-mono text-sm text-blue-400 font-bold">{claim.claim_id}</td>
                    <td className="p-5 text-sm text-slate-300">
                      <div className="flex items-center gap-2">
                        <Calendar className="w-4 h-4 text-slate-500" />
                        {new Date(parseInt(claim.timestamp || Date.now().toString())).toLocaleDateString()}
                      </div>
                    </td>
                    <td className="p-5">
                      <div className="flex items-center gap-3">
                        <span className={`text-sm font-bold ${claim.risk_score >= 70 ? 'text-red-400' : 'text-green-400'}`}>
                          {claim.risk_score}
                        </span>
                        <div className="w-16 h-2 bg-slate-800 rounded-full overflow-hidden hidden sm:block">
                          <div 
                            className={`h-full rounded-full ${claim.risk_score >= 70 ? 'bg-red-500' : 'bg-green-500'}`}
                            style={{ width: `${claim.risk_score}%` }}
                          />
                        </div>
                      </div>
                    </td>
                    <td className="p-5">
                      <span className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold border ${
                        claim.recommendation === 'REJECT' ? 'bg-red-500/10 text-red-400 border-red-500/20' : 'bg-green-500/10 text-green-400 border-green-500/20'
                      }`}>
                        {claim.recommendation === 'REJECT' ? <XCircle className="w-3 h-3" /> : <CheckCircle className="w-3 h-3" />}
                        {claim.recommendation}
                      </span>
                    </td>
                    <td className="p-5 text-right">
                      <button 
                        onClick={() => setSelectedClaim(claim)}
                        className="p-2 bg-blue-500/10 text-blue-400 hover:bg-blue-500 hover:text-white rounded-lg transition-all opacity-0 group-hover:opacity-100 border border-blue-500/20"
                      >
                        <Eye className="w-4 h-4" />
                      </button>
                    </td>
                  </motion.tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        <div className="p-4 border-t border-white/10 flex items-center justify-between bg-slate-900/50">
          <p className="text-sm text-slate-400">Page <span className="text-white font-bold">{page}</span></p>
          <div className="flex gap-2">
            <button 
              onClick={() => setPage(p => Math.max(1, p - 1))}
              disabled={page === 1}
              className="p-2 rounded-lg bg-white/5 text-slate-300 hover:bg-white/10 disabled:opacity-50 disabled:cursor-not-allowed transition-colors border border-white/5"
            >
              <ChevronLeft className="w-5 h-5" />
            </button>
            <button 
              onClick={() => setPage(p => p + 1)}
              disabled={filteredClaims.length < 10}
              className="p-2 rounded-lg bg-white/5 text-slate-300 hover:bg-white/10 disabled:opacity-50 disabled:cursor-not-allowed transition-colors border border-white/5"
            >
              <ChevronRight className="w-5 h-5" />
            </button>
          </div>
        </div>
      </motion.div>

      {/* FULL REPORT MODAL (Reused styling from ResultsView) */}
      <AnimatePresence>
        {selectedClaim && (
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
                  <h2 className="text-xl font-bold text-white flex items-center gap-2">
                    <Activity className="w-5 h-5 text-blue-400" /> Historical Analysis Report
                  </h2>
                  <p className="text-slate-400 text-sm font-mono mt-1">Claim: {selectedClaim.claim_id}</p>
                </div>
                <button onClick={() => setSelectedClaim(null)} className="p-2 text-slate-400 hover:text-white hover:bg-white/10 rounded-full transition-colors">
                  <X className="w-6 h-6" />
                </button>
              </div>

              <div className="p-6 overflow-y-auto space-y-6">
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  <div className="bg-slate-800/50 p-4 rounded-xl border border-white/5">
                    <p className="text-slate-400 text-xs mb-1 uppercase font-bold tracking-wider">Processed In</p>
                    <p className="text-white font-bold">{selectedClaim.processing_time_seconds}s</p>
                  </div>
                  <div className="bg-slate-800/50 p-4 rounded-xl border border-white/5">
                    <p className="text-slate-400 text-xs mb-1 uppercase font-bold tracking-wider">AI Confidence</p>
                    <p className="text-white font-bold">{selectedClaim.fraud_indicators?.confidence || 'N/A'}%</p>
                  </div>
                  <div className="bg-slate-800/50 p-4 rounded-xl border border-white/5">
                    <p className="text-slate-400 text-xs mb-1 uppercase font-bold tracking-wider">Assigned User</p>
                    <p className="text-white font-bold truncate" title={selectedClaim.user_id}>{selectedClaim.user_id}</p>
                  </div>
                  <div className="bg-slate-800/50 p-4 rounded-xl border border-white/5">
                    <p className="text-slate-400 text-xs mb-1 uppercase font-bold tracking-wider">Timestamp</p>
                    <p className="text-white font-bold">{new Date(parseInt(selectedClaim.timestamp || Date.now().toString())).toLocaleDateString()}</p>
                  </div>
                </div>

                <div>
                  <h3 className="text-white font-bold mb-3 flex items-center gap-2">
                    <FileText className="w-4 h-4 text-blue-400" /> Raw AI Output (JSON)
                  </h3>
                  <div className="bg-black/60 rounded-xl p-4 border border-white/10 overflow-x-auto">
                    <pre className="text-green-400 font-mono text-xs leading-relaxed">
                      {JSON.stringify(selectedClaim, null, 2)}
                    </pre>
                  </div>
                </div>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
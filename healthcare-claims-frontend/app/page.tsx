'use client';

import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

// Component Imports
import { UploadView } from '@/components/views/UploadView';
import { ProcessingView } from '@/components/views/ProcessingView';
import { ResultsView } from '@/components/views/ResultsView';
import { AnimatedBackground } from '@/components/ui/AnimatedBackground';

// Service & Type Imports
import { claimsService } from '@/services/api';
// This line fixes the error:
import { ProcessClaimResponse } from '@/types/claims'; 

type AppState = 'UPLOAD' | 'PROCESSING' | 'RESULTS';

export default function Home() {
  const [view, setView] = useState<AppState>('UPLOAD');
  const [results, setResults] = useState<ProcessClaimResponse | null>(null);

  const handleFileUpload = async (file: File) => {
    setView('PROCESSING');
    
    try {
      // The flow defined in your backend documentation:
      // 1. Get Presigned URL -> 2. PUT to S3 -> 3. POST to /process-claim
      const data = await claimsService.processFullFlow(file);
      setResults(data);
      setView('RESULTS');
    } catch (error) {
      console.error('Processing Error:', error);
      alert("Error processing claim. Please check your connection and try again.");
      setView('UPLOAD');
    }
  };

  return (
    <main className="min-h-screen relative flex items-center justify-center p-4">
      {/* Background with floating particles */}
      <AnimatedBackground />
      
      <div className="w-full max-w-5xl z-10">
        <AnimatePresence mode="wait">
          {view === 'UPLOAD' && (
            <motion.div
              key="upload"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -20 }}
              transition={{ duration: 0.5 }}
            >
              <UploadView onFileSelect={handleFileUpload} />
            </motion.div>
          )}

          {view === 'PROCESSING' && (
            <motion.div
              key="processing"
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 1.05 }}
            >
              <ProcessingView />
            </motion.div>
          )}

          {view === 'RESULTS' && results && (
            <motion.div
              key="results"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
            >
              <ResultsView data={results} onReset={() => setView('UPLOAD')} />
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </main>
  );
}
'use client';
import { useState } from 'react';
import { useSession } from 'next-auth/react';
import { motion, AnimatePresence } from 'framer-motion'; // <-- Added imports
import { ProcessClaimResponse } from '@/types/claims';

// Import your custom views
import { UploadView } from '@/components/views/UploadView';
import { ProcessingView } from '@/components/views/ProcessingView';
import { ResultsView } from '@/components/views/ResultsView';

type AppState = 'idle' | 'processing' | 'results';

export default function DashboardHome() {
  const { data: session } = useSession();
  const [appState, setAppState] = useState<AppState>('idle');
  const [claimData, setClaimData] = useState<ProcessClaimResponse | null>(null);

  // 1. Triggered when the user drops a file in UploadView
  const handleFileUpload = async (file: File) => {
    setAppState('processing'); // Immediately switch to ProcessingView

    try {
      // Create FormData and append the file & user info
      const formData = new FormData();
      formData.append('file', file);
      if (session?.user?.email) {
        formData.append('user_id', session.user.email);
      }

      // Send to your backend
      const response = await fetch('/api/process-claim', { 
        method: 'POST',
        body: formData,
      });

      if (!response.ok) throw new Error('Processing failed');

      const data = await response.json();
      
      // Save data and switch to ResultsView
      setClaimData(data);
      setAppState('results');

    } catch (error) {
      console.error(error);
      alert('Failed to process claim. Please try again.');
      setAppState('idle');
    }
  };

  // 2. Triggered when the user clicks "Start New Claim" in ResultsView
  const handleReset = () => {
    setClaimData(null);
    setAppState('idle'); // Goes back to UploadView
  };

  return (
    <div className="p-4 sm:p-6 lg:p-8 max-w-7xl mx-auto min-h-[calc(100vh-4rem)] flex flex-col justify-center">
      
      {/* mode="wait" ensures the current view completely animates out BEFORE the next view animates in */}
      <AnimatePresence mode="wait">
        
        {appState === 'idle' && (
          <motion.div 
            key="idle"
            initial={{ opacity: 0, scale: 0.95, filter: 'blur(10px)' }}
            animate={{ opacity: 1, scale: 1, filter: 'blur(0px)' }}
            exit={{ opacity: 0, scale: 1.05, filter: 'blur(10px)' }}
            transition={{ duration: 0.4, ease: "easeInOut" }}
            className="w-full"
          >
            {/* Note: Check if your UploadView expects 'onUpload' or 'onFileSelect' based on your previous files */}
            <UploadView onFileSelect={handleFileUpload} /> 
          </motion.div>
        )}
        
        {appState === 'processing' && (
          <motion.div 
            key="processing"
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -30 }}
            transition={{ duration: 0.4 }}
            className="w-full"
          >
            <ProcessingView />
          </motion.div>
        )}
        
        {appState === 'results' && claimData && (
          <motion.div 
            key="results"
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95 }}
            transition={{ duration: 0.4 }}
            className="w-full"
          >
            <ResultsView data={claimData} onReset={handleReset} />
          </motion.div>
        )}

      </AnimatePresence>
    </div>
  );
}
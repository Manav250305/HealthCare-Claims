'use client';
import { motion } from 'framer-motion';
import { Loader2, CheckCircle2 } from 'lucide-react';
import { useState, useEffect } from 'react';

const stages = [
  "Generating secure S3 upload link...",
  "Uploading claim document to AWS...",
  "Extracting data with AWS Textract...",
  "Analyzing risk with GPT-4o-mini...",
  "Finalizing fraud report..."
];

export const ProcessingView = () => {
  const [currentStage, setCurrentStage] = useState(0);

  useEffect(() => {
    const interval = setInterval(() => {
      setCurrentStage((prev) => (prev < stages.length - 1 ? prev + 1 : prev));
    }, 2500); // Transitions through stages visually
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="bg-white/10 backdrop-blur-xl rounded-3xl shadow-2xl p-12 max-w-lg mx-auto text-center border border-white/20 mt-10">
      <div className="mb-8 flex justify-center">
        <motion.div
          animate={{ rotate: 360 }}
          transition={{ duration: 2, repeat: Infinity, ease: "linear" }}
        >
          <Loader2 className="w-16 h-16 text-blue-500" />
        </motion.div>
      </div>

      <h2 className="text-2xl font-bold text-white mb-8">Processing Claim</h2>
      
      <div className="space-y-5 text-left">
        {stages.map((stage, i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0, x: -10 }}
            animate={{ 
              opacity: i <= currentStage ? 1 : 0.3,
              x: 0,
            }}
            className="flex items-center gap-4"
          >
            {i < currentStage ? (
              <CheckCircle2 className="w-5 h-5 text-green-400" />
            ) : (
              <div className={`w-5 h-5 rounded-full border-2 ${i === currentStage ? 'border-blue-500 animate-pulse' : 'border-slate-600'}`} />
            )}
            <span className={`font-medium ${i === currentStage ? 'text-blue-400' : (i < currentStage ? 'text-slate-300' : 'text-slate-500')}`}>
              {stage}
            </span>
          </motion.div>
        ))}
      </div>
    </div>
  );
};
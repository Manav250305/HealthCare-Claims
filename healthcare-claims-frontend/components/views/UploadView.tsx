'use client';
import { useCallback } from 'react';
import { useDropzone } from 'react-dropzone';
import { motion } from 'framer-motion';
import confetti from 'canvas-confetti';
import { UploadCloud, FileText } from 'lucide-react';

interface UploadViewProps {
  onFileSelect: (file: File) => void;
}

export const UploadView = ({ onFileSelect }: UploadViewProps) => {
  const onDrop = useCallback((acceptedFiles: File[]) => {
    if (acceptedFiles.length > 0) {
      confetti({
        particleCount: 100,
        spread: 70,
        origin: { y: 0.6 },
        colors: ['#3b82f6', '#10b981', '#6366f1']
      });
      onFileSelect(acceptedFiles[0]);
    }
  }, [onFileSelect]);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({ 
    onDrop, 
    accept: { 'application/pdf': ['.pdf'] },
    maxFiles: 1
  });

  return (
    <div className="bg-white/80 backdrop-blur-xl rounded-3xl shadow-2xl p-12 text-center border border-white/50">
      <h1 className="text-4xl font-bold mb-2 text-slate-800 tracking-tight">Healthcare Claims AI</h1>
      <p className="text-slate-500 mb-8">Upload an insurance claim PDF for risk and fraud analysis</p>

      {/* 1. Use a standard div for getRootProps to avoid TS conflicts */}
      <div {...getRootProps()} className="outline-none">
        <input {...getInputProps()} />
        
        {/* 2. Nest the motion.div inside for animations */}
        <motion.div
          whileHover={{ scale: 1.01 }}
          whileTap={{ scale: 0.99 }}
          className={`
            border-3 border-dashed rounded-2xl p-16 cursor-pointer transition-all duration-300
            ${isDragActive ? 'border-blue-500 bg-blue-50' : 'border-slate-300 hover:border-blue-400 hover:bg-slate-50'}
          `}
        >
          <div className="flex flex-col items-center">
            <motion.div 
              animate={isDragActive ? { y: [0, -10, 0] } : {}}
              transition={{ repeat: Infinity, duration: 1 }}
              className="w-20 h-20 bg-blue-100 rounded-full flex items-center justify-center mb-6 text-blue-600"
            >
              {isDragActive ? <FileText size={40} /> : <UploadCloud size={40} />}
            </motion.div>
            <p className="text-xl font-semibold text-slate-700">
              {isDragActive ? "Drop the PDF here" : "Drag & drop claim PDF"}
            </p>
            <p className="text-sm text-slate-400 mt-2 font-medium">Supports PDF files up to 10MB</p>
          </div>
        </motion.div>
      </div>
    </div>
  );
};
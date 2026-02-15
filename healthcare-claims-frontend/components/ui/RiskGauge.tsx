'use client';
import { motion } from 'framer-motion';

export const RiskGauge = ({ score }: { score: number }) => {
  const getColor = (s: number) => {
    if (s < 30) return '#22c55e'; // Green
    if (s < 70) return '#eab308'; // Yellow
    return '#ef4444'; // Red
  };

  const circumference = 2 * Math.PI * 45; // r=45
  const strokeDashoffset = circumference - (score / 100) * circumference;

  return (
    <div className="relative w-40 h-40 flex items-center justify-center">
      <svg className="w-full h-full transform -rotate-90">
        {/* Background Circle - Updated for Dark Theme */}
        <circle cx="50%" cy="50%" r="45" stroke="#334155" strokeWidth="8" fill="none" />
        
        {/* Progress Circle */}
        <motion.circle
          cx="50%" cy="50%" r="45"
          stroke={getColor(score)}
          strokeWidth="8"
          fill="none"
          strokeDasharray={circumference}
          initial={{ strokeDashoffset: circumference }}
          animate={{ strokeDashoffset }}
          transition={{ duration: 2, ease: "easeOut", delay: 0.5 }}
          strokeLinecap="round"
        />
      </svg>
      <div className="absolute flex flex-col items-center">
        {/* TEXT COLOR CHANGED TO WHITE */}
        <motion.span 
          className="text-4xl font-bold text-white"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 1 }}
        >
          {score}
        </motion.span>
        <span className="text-[10px] text-slate-400 font-bold uppercase tracking-wider mt-1">Score</span>
      </div>
    </div>
  );
};
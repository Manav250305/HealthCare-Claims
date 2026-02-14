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
        {/* Background Circle */}
        <circle cx="50%" cy="50%" r="45" stroke="#e2e8f0" strokeWidth="8" fill="none" />
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
        <motion.span 
          className="text-4xl font-bold text-slate-800"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 2 }}
        >
          {score}
        </motion.span>
        <span className="text-xs text-slate-500 font-uppercase">Risk Score</span>
      </div>
    </div>
  );
};
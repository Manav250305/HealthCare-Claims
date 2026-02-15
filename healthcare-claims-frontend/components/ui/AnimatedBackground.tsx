'use client';
import { motion } from 'framer-motion';
import { useEffect, useState } from 'react';

export const AnimatedBackground = () => {
  const [mounted, setMounted] = useState(false);

  useEffect(() => setMounted(true), []);

  if (!mounted) return <div className="fixed inset-0 -z-10 bg-[#020617]" />;

  return (
    <div className="fixed inset-0 -z-10 bg-[#020617] overflow-hidden">
      {/* Film Grain / Noise Overlay for the "Video" texture */}
      <div 
        className="absolute inset-0 opacity-[0.04] mix-blend-overlay z-0 pointer-events-none" 
        style={{ backgroundImage: 'url("data:image/svg+xml,%3Csvg viewBox=%220 0 200 200%22 xmlns=%22http://www.w3.org/2000/svg%22%3E%3Cfilter id=%22noiseFilter%22%3E%3CfeTurbulence type=%22fractalNoise%22 baseFrequency=%220.65%22 numOctaves=%223%22 stitchTiles=%22stitch%22/%3E%3C/filter%3E%3Crect width=%22100%25%22 height=%22100%25%22 filter=%22url(%23noiseFilter)%22/%3E%3C/svg%3E")' }} 
      />

      {/* Fluid Mesh Gradient Orbs */}
      <motion.div
        animate={{ rotate: [0, 360], scale: [1, 1.1, 1] }}
        transition={{ duration: 30, repeat: Infinity, ease: "linear" }}
        className="absolute -top-[30%] -left-[10%] w-[70vw] h-[70vw] rounded-full blur-[130px] bg-indigo-900/40 mix-blend-screen"
      />
      <motion.div
        animate={{ rotate: [360, 0], scale: [1, 1.3, 1], x: [0, 100, 0] }}
        transition={{ duration: 40, repeat: Infinity, ease: "linear" }}
        className="absolute top-[10%] -right-[20%] w-[60vw] h-[60vw] rounded-full blur-[140px] bg-blue-900/30 mix-blend-screen"
      />
      <motion.div
        animate={{ rotate: [0, -360], scale: [1, 1.2, 1], y: [0, -100, 0] }}
        transition={{ duration: 45, repeat: Infinity, ease: "linear" }}
        className="absolute -bottom-[20%] left-[20%] w-[80vw] h-[80vw] rounded-full blur-[150px] bg-emerald-900/20 mix-blend-screen"
      />
    </div>
  );
};
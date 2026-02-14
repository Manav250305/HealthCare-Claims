'use client';
import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';

interface TypewriterProps {
  text: string;
  speed?: number;
  onComplete?: () => void;
}

// Helper function to colorize severity tags and make standard text white
const formatText = (text: string) => {
  // Regex to split the text while keeping the delimiters
  const regex = /(\[CRITICAL\]|\[HIGH\]|\[MEDIUM\]|\[POSITIVE\]|\[OBSERVATION\])/g;
  const parts = text.split(regex);
  
  return parts.map((part, index) => {
    switch (part) {
      case '[CRITICAL]': 
        return <span key={index} className="text-red-500 font-black">{part}</span>;
      case '[HIGH]': 
        return <span key={index} className="text-orange-500 font-bold">{part}</span>;
      case '[MEDIUM]': 
        return <span key={index} className="text-yellow-500 font-bold">{part}</span>;
      case '[POSITIVE]': 
        return <span key={index} className="text-green-500 font-bold">{part}</span>;
      case '[OBSERVATION]': 
        return <span key={index} className="text-cyan-400 font-bold">{part}</span>;
      default: 
        return <span key={index} className="text-white">{part}</span>;
    }
  });
};

export const TypewriterText = ({ text, speed = 25, onComplete }: TypewriterProps) => {
  const [displayedText, setDisplayedText] = useState('');

  useEffect(() => {
    let i = 0;
    setDisplayedText(''); 

    const typingInterval = setInterval(() => {
      if (i < text.length) {
        setDisplayedText(text.substring(0, i + 1));
        i++;
      } else {
        clearInterval(typingInterval);
        if (onComplete) onComplete();
      }
    }, speed);

    return () => clearInterval(typingInterval);
  }, [text, speed]);

  // Apply the formatting map over the currently typed text
  return <span>{formatText(displayedText)}</span>;
};

export const SequentialTypewriter = ({ lines }: { lines: string[] }) => {
  const [activeLineIndex, setActiveLineIndex] = useState(0);

  return (
    <div className="space-y-4">
      {lines.map((line, index) => (
        index <= activeLineIndex && (
          <motion.div 
            key={index} 
            initial={{ opacity: 0, x: -5 }} 
            animate={{ opacity: 1, x: 0 }}
            className="flex gap-3 items-start"
          >
            <span className="text-blue-500 font-bold mt-1">▸</span>
            {/* Base text set to white to ensure contrast against the dark background */}
            <div className="text-white leading-relaxed">
              <TypewriterText 
                text={line} 
                onComplete={() => {
                  if (index === activeLineIndex) {
                    setTimeout(() => {
                      setActiveLineIndex(prev => prev + 1);
                    }, 200);
                  }
                }} 
              />
            </div>
          </motion.div>
        )
      ))}
    </div>
  );
};
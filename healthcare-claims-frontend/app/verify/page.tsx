'use client';

import { useState, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { motion } from 'framer-motion';
import { CognitoIdentityProviderClient, ConfirmSignUpCommand, ResendConfirmationCodeCommand } from '@aws-sdk/client-cognito-identity-provider';
import { Mail, CheckCircle, AlertCircle, ArrowRight } from 'lucide-react';
import Link from 'next/link';

const cognitoClient = new CognitoIdentityProviderClient({
  region: process.env.NEXT_PUBLIC_AWS_REGION || 'us-east-1'
});

export default function VerifyPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const emailFromUrl = searchParams.get('email') || '';

  const [email, setEmail] = useState(emailFromUrl);
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [loading, setLoading] = useState(false);
  const [resendLoading, setResendLoading] = useState(false);
  const [resendSuccess, setResendSuccess] = useState(false);

  const handleVerify = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const command = new ConfirmSignUpCommand({
        ClientId: process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID!,
        Username: email,
        ConfirmationCode: code.trim()
      });

      await cognitoClient.send(command);
      setSuccess(true);

      // Redirect to login after 2 seconds
      setTimeout(() => {
        router.push('/login?verified=true');
      }, 2000);
    } catch (err: any) {
      console.error('Verification error:', err);
      
      if (err.name === 'CodeMismatchException') {
        setError('Invalid verification code. Please check and try again.');
      } else if (err.name === 'ExpiredCodeException') {
        setError('Verification code expired. Please request a new code below.');
      } else if (err.name === 'NotAuthorizedException') {
        setError('User already verified. Redirecting to login...');
        setTimeout(() => router.push('/login'), 2000);
      } else if (err.name === 'LimitExceededException') {
        setError('Too many attempts. Please wait a few minutes and try again.');
      } else {
        setError(err.message || 'Verification failed. Please try again.');
      }
    } finally {
      setLoading(false);
    }
  };

  const handleResendCode = async () => {
    setError('');
    setResendSuccess(false);
    setResendLoading(true);

    try {
      const command = new ResendConfirmationCodeCommand({
        ClientId: process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID!,
        Username: email
      });

      await cognitoClient.send(command);
      setResendSuccess(true);
      setCode(''); // Clear the code field
      
      // Hide success message after 5 seconds
      setTimeout(() => setResendSuccess(false), 5000);
    } catch (err: any) {
      console.error('Resend error:', err);
      
      if (err.name === 'LimitExceededException') {
        setError('Too many requests. Please wait a few minutes before requesting a new code.');
      } else if (err.name === 'InvalidParameterException') {
        setError('User already verified. Please login.');
        setTimeout(() => router.push('/login'), 2000);
      } else {
        setError('Failed to resend code. Please try again.');
      }
    } finally {
      setResendLoading(false);
    }
  };

  // Auto-focus code input when page loads
  useEffect(() => {
    const codeInput = document.getElementById('verification-code');
    if (codeInput) {
      codeInput.focus();
    }
  }, []);

  if (success) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-blue-900 via-slate-900 to-slate-800 flex items-center justify-center p-6">
        <motion.div
          initial={{ scale: 0.9, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          className="bg-white/10 backdrop-blur-md rounded-2xl shadow-2xl p-8 w-full max-w-md border border-white/20 text-center"
        >
          <motion.div
            initial={{ scale: 0 }}
            animate={{ scale: 1 }}
            transition={{ delay: 0.2, type: "spring" }}
          >
            <CheckCircle className="w-20 h-20 text-green-400 mx-auto mb-6" />
          </motion.div>

          <h2 className="text-2xl font-bold text-white mb-4">
            Email Verified! 🎉
          </h2>

          <p className="text-blue-200 mb-6">
            Your account has been successfully verified.
            <br />
            You can now log in to your account.
          </p>

          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.5 }}
            className="flex items-center justify-center gap-2 text-blue-300 text-sm"
          >
            <span>Redirecting to login page</span>
            <motion.div
              animate={{ x: [0, 5, 0] }}
              transition={{ repeat: Infinity, duration: 1 }}
            >
              <ArrowRight className="w-4 h-4" />
            </motion.div>
          </motion.div>
        </motion.div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-900 via-slate-900 to-slate-800 flex items-center justify-center p-6">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="bg-white/10 backdrop-blur-md rounded-2xl shadow-2xl p-8 w-full max-w-md border border-white/20"
      >
        <div className="text-center mb-8">
          <motion.div
            initial={{ scale: 0 }}
            animate={{ scale: 1 }}
            transition={{ type: "spring" }}
          >
            <Mail className="w-16 h-16 text-blue-400 mx-auto mb-4" />
          </motion.div>
          <h1 className="text-3xl font-bold text-white mb-2">
            Verify Your Email
          </h1>
          <p className="text-blue-200">
            We sent a verification code to
          </p>
          <p className="text-white font-semibold mt-1">
            {email || 'your email'}
          </p>
        </div>

        <form onSubmit={handleVerify} className="space-y-6">
          {/* Email (editable) */}
          <div>
            <label className="block text-white text-sm font-semibold mb-2">
              Email Address
            </label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-4 py-3 bg-white/20 border border-white/30 rounded-lg text-white placeholder-blue-200 focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="you@example.com"
              required
            />
          </div>

          {/* Verification Code */}
          <div>
            <label className="block text-white text-sm font-semibold mb-2">
              Verification Code
            </label>
            <input
              id="verification-code"
              type="text"
              value={code}
              onChange={(e) => {
                // Only allow numbers and limit to 6 digits
                const value = e.target.value.replace(/\D/g, '').slice(0, 6);
                setCode(value);
              }}
              className="w-full px-4 py-4 bg-white/20 border border-white/30 rounded-lg text-white text-center text-3xl tracking-[0.5em] placeholder-blue-200 focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono"
              placeholder="000000"
              maxLength={6}
              required
              autoComplete="off"
            />
            <p className="text-xs text-blue-200 mt-2 text-center">
              Enter the 6-digit code from your email
            </p>
          </div>

          {/* Resend Success Message */}
          {resendSuccess && (
            <motion.div
              initial={{ opacity: 0, y: -10 }}
              animate={{ opacity: 1, y: 0 }}
              className="flex items-center gap-2 bg-green-500/20 border border-green-500 rounded-lg p-3 text-green-200 text-sm"
            >
              <CheckCircle className="w-5 h-5 flex-shrink-0" />
              <span>New verification code sent! Check your email.</span>
            </motion.div>
          )}

          {/* Error Message */}
          {error && (
            <motion.div
              initial={{ opacity: 0, y: -10 }}
              animate={{ opacity: 1, y: 0 }}
              className="flex items-start gap-2 bg-red-500/20 border border-red-500 rounded-lg p-3 text-red-200 text-sm"
            >
              <AlertCircle className="w-5 h-5 flex-shrink-0 mt-0.5" />
              <span>{error}</span>
            </motion.div>
          )}

          {/* Verify Button */}
          <motion.button
            whileHover={{ scale: code.length === 6 ? 1.02 : 1 }}
            whileTap={{ scale: code.length === 6 ? 0.98 : 1 }}
            type="submit"
            disabled={loading || code.length !== 6}
            className="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 rounded-lg disabled:opacity-50 disabled:cursor-not-allowed transition-all"
          >
            {loading ? (
              <div className="flex items-center justify-center gap-2">
                <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white" />
                Verifying...
              </div>
            ) : (
              `Verify Email ${code.length === 6 ? '✓' : ''}`
            )}
          </motion.button>

          {/* Resend Code */}
          <div className="text-center">
            <p className="text-blue-200 text-sm mb-2">Didn't receive the code?</p>
            <button
              type="button"
              onClick={handleResendCode}
              disabled={resendLoading}
              className="text-blue-400 hover:text-blue-300 text-sm font-semibold disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {resendLoading ? (
                <span className="flex items-center justify-center gap-2">
                  <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-400" />
                  Sending...
                </span>
              ) : (
                'Resend Code'
              )}
            </button>
          </div>
        </form>

        {/* Back to Login */}
        <div className="mt-8 pt-6 border-t border-white/20 text-center">
          <Link
            href="/login"
            className="text-blue-400 hover:text-blue-300 text-sm font-semibold transition-colors"
          >
            ← Back to Login
          </Link>
        </div>
      </motion.div>
    </div>
  );
}

'use client';
import { useSession, signOut } from 'next-auth/react';
import { useRouter } from 'next/navigation';
import { motion } from 'framer-motion';
import { LogOut, User, FileText, History, Upload } from 'lucide-react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

export default function Navbar() {
  const { data: session } = useSession();
  const router = useRouter();
  const pathname = usePathname();

  const handleSignOut = async () => {
    await signOut({ redirect: false });
    router.push('/login');
  };

  if (!session) return null;

  return (
    <nav className="bg-slate-900/50 backdrop-blur-xl border-b border-white/10 sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          
          {/* Logo & Brand */}
          <div className="flex items-center gap-8">
            <Link href="/" className="flex items-center gap-2 group">
              <div className="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center group-hover:bg-blue-500 transition-colors">
                <FileText className="w-5 h-5 text-white" />
              </div>
              <span className="text-white font-bold text-lg tracking-wide">
                Claims Intelligence
              </span>
            </Link>

            {/* Navigation Links */}
            <div className="hidden md:flex items-center gap-2">
              <Link
                href="/"
                className={`flex items-center gap-2 px-4 py-2 rounded-xl transition-all ${
                  pathname === '/' 
                    ? 'bg-white/10 text-white shadow-inner' 
                    : 'text-slate-400 hover:text-white hover:bg-white/5'
                }`}
              >
                <Upload className="w-4 h-4" />
                Upload
              </Link>
              <Link
                href="/claims/history"
                className={`flex items-center gap-2 px-4 py-2 rounded-xl transition-all ${
                  pathname === '/claims/history' 
                    ? 'bg-white/10 text-white shadow-inner' 
                    : 'text-slate-400 hover:text-white hover:bg-white/5'
                }`}
              >
                <History className="w-4 h-4" />
                History
              </Link>
            </div>
          </div>

          {/* User Menu */}
          <div className="flex items-center gap-4">
            <div className="hidden md:flex items-center gap-2 px-4 py-2 bg-slate-950/50 rounded-xl border border-white/5">
              <User className="w-4 h-4 text-blue-400" />
              <span className="text-slate-300 text-sm font-medium">
                {session.user?.email}
              </span>
            </div>
            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              onClick={handleSignOut}
              className="flex items-center gap-2 px-4 py-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-xl border border-red-500/20 transition-colors"
            >
              <LogOut className="w-4 h-4" />
              <span className="text-sm font-bold">Sign Out</span>
            </motion.button>
          </div>

        </div>
      </div>
    </nav>
  );
}
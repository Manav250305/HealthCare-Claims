import Navbar from '@/components/layout/Navbar';
import { AnimatedBackground } from '@/components/ui/AnimatedBackground';

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen relative flex flex-col">
      {/* The background handles its own fixed positioning, -z-index, 
        and overflow-hidden internally so it stays put while the page scrolls 
      */}
      <AnimatedBackground />
      
      {/* The z-10 wrapper ensures our Navbar and page content 
        sit clearly on top of the background animations 
      */}
      <div className="relative z-10 flex flex-col flex-1">
        <Navbar />
        <main className="flex-1">{children}</main>
      </div>
    </div>
  );
}
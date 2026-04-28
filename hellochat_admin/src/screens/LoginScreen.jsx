import { useState, useEffect } from 'react';
import { RecaptchaVerifier, signInWithPhoneNumber } from 'firebase/auth';
import { auth, db } from '../firebase';
import { doc, getDoc } from 'firebase/firestore';
import { useNavigate } from 'react-router-dom';
import { ShieldAlert, Smartphone, Key, ChevronRight, Zap, CheckCircle2 } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import logo from '../assets/logo.webp';

export const LoginScreen = () => {
  const [phoneNumber, setPhoneNumber] = useState('');
  const [otp, setOtp] = useState('');
  const [confirmationResult, setConfirmationResult] = useState(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    if (!window.recaptchaVerifier) {
      window.recaptchaVerifier = new RecaptchaVerifier(auth, 'recaptcha-container', {
        'size': 'invisible'
      });
    }
  }, []);

  const handleSendOtp = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const formattedPhone = phoneNumber.startsWith('+') ? phoneNumber : `+91${phoneNumber}`;
      const confirmation = await signInWithPhoneNumber(auth, formattedPhone, window.recaptchaVerifier);
      setConfirmationResult(confirmation);
    } catch (err) {
      setError("AUTHENTICATION FAILED: " + err.message);
      if (window.recaptchaVerifier) window.recaptchaVerifier.render().then(id => grecaptcha.reset(id));
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOtp = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const result = await confirmationResult.confirm(otp);
      const userDoc = await getDoc(doc(db, "users", result.user.uid));
      const tags = userDoc.data()?.tags || [];
      if (tags.includes("Admin") || tags.includes("SuperAdmin")) {
        navigate('/');
      } else {
        await auth.signOut();
        setError("ACCESS DENIED: Insufficient permissions for this node.");
      }
    } catch (err) {
      setError("VERIFICATION FAILED: " + err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#0A0A0B] flex items-center justify-center p-6 relative overflow-hidden">
      <div id="recaptcha-container"></div>
      
      {/* 🌌 Atmospheric Background */}
      <div className="absolute top-0 left-0 w-full h-full bg-black"></div>
      <div className="absolute top-0 left-0 w-full h-full bg-[radial-gradient(circle_at_30%_30%,_rgba(180,224,162,0.03)_0%,_transparent_50%)]"></div>
      
      <motion.div 
        animate={{ scale: [1, 1.2, 1], opacity: [0.05, 0.1, 0.05] }}
        transition={{ duration: 10, repeat: Infinity }}
        className="absolute -top-60 -right-60 w-[800px] h-[800px] bg-[#B4E0A2]/5 blur-[150px] rounded-full"
      />

      <motion.div 
        initial={{ opacity: 0, y: 40 }}
        animate={{ opacity: 1, y: 0 }}
        className="w-full max-w-[400px] relative z-10"
      >
        <div className="bg-[#18181B]/60 backdrop-blur-[40px] border border-white/[0.05] p-10 rounded-[48px] shadow-[0_50px_100px_-20px_rgba(0,0,0,1)] relative overflow-hidden group">
          <div className="absolute top-0 left-0 w-full h-[2px] bg-gradient-to-r from-transparent via-[#B4E0A2] to-transparent opacity-20"></div>
          
          <div className="text-center mb-10">
            <motion.div 
              animate={{ rotate: [0, 5, -5, 0], scale: [1, 1.05, 1] }}
              transition={{ duration: 10, repeat: Infinity }}
              className="w-24 h-24 mx-auto flex items-center justify-center relative mb-8"
            >
              <div className="absolute inset-0 bg-gradient-to-br from-[#B4E0A2]/20 to-transparent blur-[40px] rounded-full"></div>
              <div className="w-20 h-20 bg-[#18181B] border border-white/[0.08] rounded-[32px] flex items-center justify-center shadow-2xl relative z-10 overflow-hidden">
                <img 
                  src={logo} 
                  className="w-14 h-14 object-contain rounded-[20px]" 
                  alt="Logo"
                />
              </div>
            </motion.div>
            <h1 className="text-3xl font-black text-white tracking-tighter uppercase mb-2">Hello Chat</h1>
            <p className="text-[9px] font-black text-slate-600 tracking-[0.4em] uppercase">Control Management</p>
          </div>

          {error && (
            <motion.div 
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              className="bg-red-500/5 border border-red-500/10 text-red-500/80 p-4 rounded-2xl text-[9px] font-black tracking-widest uppercase mb-8 text-center"
            >
              {error}
            </motion.div>
          )}

          <AnimatePresence mode="wait">
            {!confirmationResult ? (
              <form onSubmit={handleSendOtp} className="space-y-6">
                <div className="space-y-3">
                  <label className="text-[9px] font-black text-slate-600 uppercase tracking-widest ml-2">Phone Identifier</label>
                  <input
                    type="tel"
                    placeholder="+91 0000 0000 00"
                    className="w-full bg-black/40 border border-white/[0.05] rounded-2xl px-6 py-4 text-lg font-bold tracking-tight text-white focus:ring-2 focus:ring-[#B4E0A2] focus:border-transparent outline-none transition-all placeholder:text-zinc-800"
                    value={phoneNumber}
                    onChange={(e) => setPhoneNumber(e.target.value)}
                    required
                  />
                </div>
                <button
                  disabled={loading}
                  className="w-full py-5 bg-[#B4E0A2] hover:bg-[#8DBB7E] text-[#0C0C0C] rounded-2xl font-black tracking-widest text-xs uppercase shadow-2xl shadow-[#B4E0A2]/10 transition-all transform active:scale-95 disabled:opacity-50"
                >
                  {loading ? "Verifying..." : "Enter Platform"}
                </button>
              </form>
            ) : (
              <form onSubmit={handleVerifyOtp} className="space-y-6">
                <div className="space-y-3">
                  <div className="flex justify-between items-center px-2">
                    <label className="text-[9px] font-black text-slate-600 uppercase tracking-widest">Entry Key</label>
                    <button type="button" onClick={() => setConfirmationResult(null)} className="text-[9px] font-black text-[#B4E0A2] uppercase tracking-widest">Reset</button>
                  </div>
                  <input
                    type="text"
                    maxLength="6"
                    placeholder="......"
                    className="w-full bg-black/40 border border-white/[0.05] rounded-2xl px-6 py-4 text-3xl font-black tracking-[0.4em] text-white text-center focus:ring-2 focus:ring-[#B4E0A2] focus:border-transparent outline-none transition-all placeholder:text-zinc-800"
                    value={otp}
                    onChange={(e) => setOtp(e.target.value)}
                    required
                    autoFocus
                  />
                </div>
                <button
                  disabled={loading}
                  className="w-full py-5 bg-[#B4E0A2] hover:bg-[#8DBB7E] text-[#0C0C0C] rounded-2xl font-black tracking-widest text-xs uppercase shadow-2xl shadow-[#B4E0A2]/10 transition-all transform active:scale-95 disabled:opacity-50"
                >
                  {loading ? "Authenticating..." : "Establish Link"}
                </button>
              </form>
            )}
          </AnimatePresence>

          <div className="mt-12 text-center pt-8 border-t border-white/[0.03]">
             <p className="text-[8px] text-gray-700 font-black tracking-[0.5em] uppercase">Encrypted • End-to-End • 2026</p>
          </div>
        </div>
      </motion.div>
    </div>
  );
};

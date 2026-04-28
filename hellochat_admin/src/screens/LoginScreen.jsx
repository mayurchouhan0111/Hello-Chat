import { useState, useEffect } from 'react';
import { RecaptchaVerifier, signInWithPhoneNumber } from 'firebase/auth';
import { auth, db } from '../firebase';
import { doc, getDoc } from 'firebase/firestore';
import { useNavigate } from 'react-router-dom';
import { ShieldAlert, Smartphone, Key, ChevronRight, Zap, CheckCircle2 } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

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
      <div className="absolute top-0 left-0 w-full h-full bg-[radial-gradient(circle_at_center,_var(--tw-gradient-stops))] from-[#00E5FF]/5 via-transparent to-transparent"></div>
      <motion.div 
        animate={{ scale: [1, 1.1, 1], opacity: [0.3, 0.5, 0.3] }}
        transition={{ duration: 8, repeat: Infinity }}
        className="absolute -top-40 -right-40 w-[600px] h-[600px] bg-[#00E5FF]/10 blur-[120px] rounded-full"
      />

      <motion.div 
        initial={{ opacity: 0, y: 40 }}
        animate={{ opacity: 1, y: 0 }}
        className="w-full max-w-[480px] relative z-10"
      >
        <div className="bg-white/[0.02] backdrop-blur-3xl border border-white/[0.05] p-12 rounded-[48px] shadow-2xl relative overflow-hidden">
          <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-transparent via-[#00E5FF] to-transparent opacity-50"></div>
          
          <div className="text-center mb-12">
            <motion.div 
              animate={{ rotate: [0, 5, -5, 0] }}
              transition={{ duration: 10, repeat: Infinity }}
              className="w-20 h-20 bg-[#00E5FF] rounded-3xl mx-auto flex items-center justify-center shadow-2xl shadow-[#00E5FF]/20 mb-8 rotate-3"
            >
              <ShieldAlert className="text-black" size={32} />
            </motion.div>
            <h1 className="text-3xl font-black text-white tracking-tighter uppercase mb-2">Hello Chat Access</h1>
            <p className="text-[10px] font-black text-gray-600 tracking-[0.4em] uppercase">Administration Terminal v5</p>
          </div>

          {error && (
            <motion.div 
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              className="bg-red-500/10 border border-red-500/20 text-red-500 p-4 rounded-2xl text-[10px] font-black tracking-widest uppercase mb-8 text-center"
            >
              {error}
            </motion.div>
          )}

          <AnimatePresence mode="wait">
            {!confirmationResult ? (
              <form onSubmit={handleSendOtp} className="space-y-8">
                <div className="space-y-4">
                  <label className="text-[10px] font-black text-gray-500 uppercase tracking-widest ml-1">Secure Identity (Phone)</label>
                  <input
                    type="tel"
                    placeholder="+91 0000 0000 00"
                    className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-6 py-5 text-xl font-bold tracking-tight text-white focus:ring-2 focus:ring-[#00E5FF] focus:border-transparent outline-none transition-all placeholder:text-gray-800"
                    value={phoneNumber}
                    onChange={(e) => setPhoneNumber(e.target.value)}
                    required
                  />
                </div>
                <button
                  disabled={loading}
                  className="w-full py-5 bg-[#00E5FF] hover:bg-[#00B8D4] text-black rounded-2xl font-black tracking-widest text-xs uppercase shadow-xl shadow-[#00E5FF]/10 transition-all transform active:scale-95 disabled:opacity-50"
                >
                  {loading ? "Authenticating..." : "Establish Connection"}
                </button>
              </form>
            ) : (
              <form onSubmit={handleVerifyOtp} className="space-y-8">
                <div className="space-y-4">
                  <div className="flex justify-between items-center px-1">
                    <label className="text-[10px] font-black text-gray-500 uppercase tracking-widest">Entry Key (OTP)</label>
                    <button type="button" onClick={() => setConfirmationResult(null)} className="text-[9px] font-black text-[#00E5FF] uppercase tracking-widest border-b border-[#00E5FF]/20">Back</button>
                  </div>
                  <input
                    type="text"
                    maxLength="6"
                    placeholder="......"
                    className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-6 py-5 text-4xl font-black tracking-[0.4em] text-white text-center focus:ring-2 focus:ring-[#00E5FF] focus:border-transparent outline-none transition-all placeholder:text-gray-800"
                    value={otp}
                    onChange={(e) => setOtp(e.target.value)}
                    required
                    autoFocus
                  />
                </div>
                <button
                  disabled={loading}
                  className="w-full py-5 bg-[#00E5FF] hover:bg-[#00B8D4] text-black rounded-2xl font-black tracking-widest text-xs uppercase shadow-xl shadow-[#00E5FF]/10 transition-all transform active:scale-95 disabled:opacity-50"
                >
                  {loading ? "Verifying..." : "Validate Identity"}
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

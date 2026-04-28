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
      <div className="absolute top-0 left-0 w-full h-full bg-[#050505]"></div>
      <div className="absolute top-0 left-0 w-full h-full bg-[radial-gradient(circle_at_30%_30%,_rgba(0,229,255,0.08)_0%,_transparent_50%)]"></div>
      <div className="absolute top-0 left-0 w-full h-full bg-[radial-gradient(circle_at_70%_70%,_rgba(99,102,241,0.08)_0%,_transparent_50%)]"></div>
      
      <motion.div 
        animate={{ scale: [1, 1.2, 1], opacity: [0.2, 0.4, 0.2] }}
        transition={{ duration: 10, repeat: Infinity }}
        className="absolute -top-60 -right-60 w-[800px] h-[800px] bg-indigo-500/10 blur-[150px] rounded-full"
      />

      <motion.div 
        initial={{ opacity: 0, y: 40 }}
        animate={{ opacity: 1, y: 0 }}
        className="w-full max-w-[500px] relative z-10"
      >
        <div className="bg-[#0A0A0B]/60 backdrop-blur-[60px] border border-white/[0.08] p-14 rounded-[56px] shadow-[0_50px_100px_-20px_rgba(0,0,0,0.8)] relative overflow-hidden group">
          <div className="absolute top-0 left-0 w-full h-[2px] bg-gradient-to-r from-transparent via-cyan-500 to-transparent opacity-30 group-hover:opacity-100 transition-opacity duration-1000"></div>
          
          <div className="text-center mb-14">
            <motion.div 
              animate={{ rotate: [0, 5, -5, 0], scale: [1, 1.05, 1] }}
              transition={{ duration: 10, repeat: Infinity }}
              className="w-32 h-32 mx-auto flex items-center justify-center relative mb-10"
            >
              <div className="absolute inset-0 bg-gradient-to-br from-cyan-500/20 to-indigo-500/20 blur-[50px] rounded-full"></div>
              <div className="w-28 h-28 bg-gradient-to-br from-white/[0.05] to-transparent border border-white/10 rounded-[36px] flex items-center justify-center shadow-2xl relative z-10 overflow-hidden">
                <img 
                  src={logo} 
                  className="w-20 h-20 object-contain rounded-[28px] drop-shadow-[0_0_20px_rgba(0,229,255,0.6)]" 
                  alt="Logo"
                />
              </div>
            </motion.div>
            <h1 className="text-4xl font-black text-white tracking-tighter uppercase mb-3 bg-clip-text text-transparent bg-gradient-to-b from-white to-gray-400">Control Access</h1>
            <p className="text-[9px] font-black text-slate-500 tracking-[0.6em] uppercase">Secured Authentication Terminal</p>
          </div>

          {error && (
            <motion.div 
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              className="bg-red-500/5 border border-red-500/20 text-red-500 p-5 rounded-2xl text-[9px] font-black tracking-widest uppercase mb-10 text-center flex items-center justify-center gap-3"
            >
              <ShieldAlert size={16} />
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

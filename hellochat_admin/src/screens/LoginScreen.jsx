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
  const [timer, setTimer] = useState(0);
  const navigate = useNavigate();

  useEffect(() => {
    // Setup Recaptcha
    if (!window.recaptchaVerifier) {
      window.recaptchaVerifier = new RecaptchaVerifier(auth, 'recaptcha-container', {
        'size': 'invisible',
        'callback': (response) => {
          // reCAPTCHA solved, allow signInWithPhoneNumber.
        }
      });
    }
  }, []);

  const handleSendOtp = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      // Ensure phone includes country code
      const formattedPhone = phoneNumber.startsWith('+') ? phoneNumber : `+91${phoneNumber}`;
      const confirmation = await signInWithPhoneNumber(auth, formattedPhone, window.recaptchaVerifier);
      setConfirmationResult(confirmation);
      setTimer(60);
    } catch (err) {
      setError("FAILED TO SEND OTP: " + err.message);
      // Reset reCAPTCHA on error
      if (window.recaptchaVerifier) window.recaptchaVerifier.render().then(widgetId => grecaptcha.reset(widgetId));
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
        setError("ACCESS REVOKED: Admin level credentials required for this partition.");
      }
    } catch (err) {
      setError("OTP VERIFICATION FAILED: " + err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center p-6 relative overflow-hidden">
      <div id="recaptcha-container"></div>
      
      {/* Animated Background Orbs */}
      <motion.div 
        animate={{ scale: [1, 1.2, 1], x: [0, 50, 0] }}
        transition={{ duration: 10, repeat: Infinity }}
        className="absolute -top-40 -right-40 w-[600px] h-[600px] bg-primary/20 blur-[140px] rounded-full opacity-60"
      ></motion.div>
      <motion.div 
        animate={{ scale: [1, 1.3, 1], x: [0, -50, 0] }}
        transition={{ duration: 12, repeat: Infinity, delay: 2 }}
        className="absolute -bottom-40 -left-24 w-[500px] h-[500px] bg-cyan-500/10 blur-[120px] rounded-full opacity-40"
      ></motion.div>

      <motion.div 
        initial={{ opacity: 0, y: 30, scale: 0.95 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        className="w-full max-w-[500px] relative z-10"
      >
        <div className="card-glass p-12 border-white/5 bg-slate-900/60 backdrop-blur-3xl shadow-[0_0_100px_rgba(0,0,0,0.5)]">
          
          <div className="flex justify-between items-center mb-12">
             <div className="flex items-center gap-4">
                <div className="w-14 h-14 bg-gradient-to-br from-primary to-indigo-600 rounded-2xl flex items-center justify-center shadow-2xl shadow-primary/40 border border-white/20">
                   <ShieldAlert className="text-white" size={28} />
                </div>
                <div>
                   <h2 className="text-2xl font-black text-white tracking-tighter uppercase">ADMIN ACCESS</h2>
                   <p className="text-[10px] font-black text-slate-500 tracking-[0.3em] uppercase">MFA PROTECTED • Orbit Platform</p>
                </div>
             </div>
             <div className="bg-cyan-500/10 px-3 py-1.5 rounded-full border border-cyan-500/20 flex items-center gap-2">
                <div className="w-1.5 h-1.5 bg-cyan-500 rounded-full animate-pulse"></div>
                <span className="text-[9px] font-black text-cyan-500 uppercase tracking-widest leading-none text-nowrap">PH-SECURE</span>
             </div>
          </div>

          {error && (
            <motion.div 
              initial={{ scale: 0.9 }}
              animate={{ scale: 1 }}
              className="bg-red-500/10 border border-red-500/20 text-red-500 px-5 py-4 rounded-2xl text-[10px] font-black tracking-widest uppercase mb-8 flex items-center gap-3 animate-shake"
            >
              <ShieldAlert size={16} /> {error}
            </motion.div>
          )}

          <AnimatePresence mode="wait">
            {!confirmationResult ? (
              <motion.form 
                key="phone-form"
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: 20 }}
                onSubmit={handleSendOtp} 
                className="space-y-8"
              >
                <div className="space-y-3">
                  <label className="text-[10px] font-black text-slate-500 uppercase tracking-[0.2em] ml-1">MOBILE AUTHORIZATION</label>
                  <div className="relative group">
                    <Smartphone className="absolute left-5 top-4.5 text-slate-500 group-focus-within:text-primary transition-colors" size={20} />
                    <input
                      type="tel"
                      placeholder="+91 0000 0000 00"
                      className="input-field w-full pl-14 h-16 bg-slate-950/50 border-white/5 font-bold tracking-tight text-lg"
                      value={phoneNumber}
                      onChange={(e) => setPhoneNumber(e.target.value)}
                      required
                    />
                  </div>
                </div>

                <motion.button
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  disabled={loading}
                  className="w-full h-16 bg-primary hover:bg-primary-dark text-white rounded-2xl flex items-center justify-center gap-3 font-black tracking-[0.1em] text-sm uppercase shadow-2xl transition-all border border-white/10"
                >
                  {loading ? (
                    <div className="w-5 h-5 border-2 border-white/60 border-t-white rounded-full animate-spin"></div>
                  ) : (
                    <>SEND SECURITY CODE <ChevronRight size={18} /></>
                  )}
                </motion.button>
              </motion.form>
            ) : (
              <motion.form 
                key="otp-form"
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: 20 }}
                onSubmit={handleVerifyOtp} 
                className="space-y-8"
              >
                <div className="space-y-3">
                  <div className="flex justify-between">
                    <label className="text-[10px] font-black text-slate-500 uppercase tracking-[0.2em] ml-1">ONE-TIME PASSWORD</label>
                    <button onClick={() => setConfirmationResult(null)} className="text-[9px] font-black text-primary-light uppercase tracking-widest border-b border-primary/20">CHANGE NUMBER</button>
                  </div>
                  <div className="relative group">
                    <Key className="absolute left-5 top-4.5 text-slate-500 group-focus-within:text-cyan-400 transition-colors" size={20} />
                    <input
                      type="text"
                      maxLength="6"
                      placeholder="000 000"
                      className="input-field w-full pl-14 h-16 bg-slate-950/50 border-white/5 font-black tracking-[0.8em] text-2xl text-center pr-14"
                      value={otp}
                      onChange={(e) => setOtp(e.target.value)}
                      required
                      autoFocus
                    />
                  </div>
                </div>

                <motion.button
                  whileHover={{ scale: 1.02, boxShadow: '0 0 40px rgba(6,182,212,0.3)' }}
                  whileTap={{ scale: 0.98 }}
                  disabled={loading}
                  className="w-full h-16 bg-cyan-500 hover:bg-cyan-600 text-slate-950 rounded-2xl flex items-center justify-center gap-3 font-black tracking-[0.1em] text-sm uppercase shadow-2xl transition-all border border-white/10"
                >
                  {loading ? (
                    <div className="w-5 h-5 border-2 border-slate-950 border-t-transparent rounded-full animate-spin"></div>
                  ) : (
                    <>VERIFY IDENTITY <CheckCircle2 size={18} /></>
                  )}
                </motion.button>
              </motion.form>
            )}
          </AnimatePresence>
          
          <div className="mt-12 text-center border-t border-white/5 pt-8">
            <p className="text-[9px] text-slate-700 font-bold tracking-[0.4em] uppercase">Orbit Platform Administration Terminal v5.2.0 • 2026</p>
          </div>
        </div>
      </motion.div>
    </div>
  );
};

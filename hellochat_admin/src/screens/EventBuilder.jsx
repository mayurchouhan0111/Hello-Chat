import { Info, Sparkles, Layers } from 'lucide-react';

export const EventBuilder = () => {
  return (
    <div className="flex flex-col items-center justify-center min-h-[60vh] text-center p-8 animate-fade-in text-white">
      {/* Decorative Icon Glow Frame */}
      <div className="relative mb-8">
        <div className="absolute inset-0 bg-[#00E5FF]/20 rounded-3xl blur-2xl"></div>
        <div className="p-6 bg-slate-900/60 border border-[#00E5FF]/20 rounded-3xl relative z-10 flex items-center justify-center">
          <Layers className="text-[#00E5FF] animate-pulse" size={48} />
        </div>
      </div>

      {/* Status Badge */}
      <span className="inline-flex items-center gap-1.5 px-4 py-1.5 rounded-full text-[10px] font-black bg-[#00E5FF]/10 text-[#00E5FF] border border-[#00E5FF]/20 uppercase tracking-widest mb-6">
        <Sparkles size={10} /> Remastering in Progress
      </span>

      {/* Heading */}
      <h1 className="text-4xl font-black text-white tracking-tighter uppercase mb-4">
        Dynamic Event Builder V2
      </h1>
      
      <p className="text-lg font-bold text-slate-400 tracking-tight max-w-lg mb-8 leading-relaxed">
        This screen is undergoing a complete visual overhaul to support customizable 3D graphics and milestone timelines.
      </p>

      {/* Notice Info Box */}
      <div className="max-w-md p-6 bg-white/[0.02] border border-white/[0.04] rounded-2xl flex gap-4 text-left">
        <div className="p-2 bg-indigo-500/10 rounded-xl h-fit">
          <Info className="text-indigo-400" size={18} />
        </div>
        <div>
          <h4 className="text-xs font-black text-white uppercase tracking-wider mb-2">Alternative Tool Available</h4>
          <p className="text-xs text-slate-500 font-medium leading-relaxed">
            For setting up active recharge bonus events, please use the newly upgraded <strong className="text-white">Recharge Event</strong> manager in your sidebar navigation.
          </p>
        </div>
      </div>
    </div>
  );
};

import { useState, useEffect } from 'react';
import { db, functions } from '../firebase';
import { 
  collection, 
  query, 
  getDocs, 
  where, 
  doc, 
  limit, 
  orderBy,
  Timestamp 
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { 
  Users, 
  Diamond, 
  History, 
  Plus, 
  ArrowUpRight, 
  ArrowDownLeft, 
  Search,
  Store,
  DollarSign,
  TrendingUp,
  Wallet,
  Calendar,
  X,
  CheckCircle,
  AlertCircle,
  RefreshCw,
  Trash2
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

const WalletAdjustmentModal = ({ reseller, onClose, onUpdate }) => {
  const [amount, setAmount] = useState('');
  const [isProcessing, setIsProcessing] = useState(false);

  const handleAdjust = async (isAdding) => {
    if (!amount || isNaN(amount)) return;
    setIsProcessing(true);
    try {
      const adjustWallet = httpsCallable(functions, 'adminAdjustResellerWallet');
      await adjustWallet({
        targetUid: reseller.id,
        amountDelta: isAdding ? parseFloat(amount) : -parseFloat(amount)
      });
      alert(`Success! Updated reseller ${reseller.displayName}'s wallet.`);
      onUpdate();
      onClose();
    } catch (err) {
      alert(err.message);
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
      <div className="bg-[#09090B] border border-white/10 w-full max-w-md rounded-3xl p-8 shadow-2xl">
        <div className="flex justify-between items-center mb-8">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-emerald-500/20 text-emerald-400 rounded-xl">
              <Wallet size={24} />
            </div>
            <div>
              <h2 className="text-xl font-black text-white uppercase tracking-widest">Adjust Wallet</h2>
              <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest leading-none mt-1">USD (Balance: ${reseller.walletBalance || 0})</p>
            </div>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-white/5 rounded-full transition-colors">
            <X size={20} className="text-slate-500" />
          </button>
        </div>

        <div className="space-y-6">
          <div className="space-y-2">
            <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-2">Delta in USD ($)</label>
            <input 
              type="number" 
              className="w-full bg-black border border-white/10 rounded-2xl p-4 text-white font-black text-2xl text-center focus:border-emerald-500 outline-none"
              placeholder="0.00"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
            />
          </div>

          <div className="grid grid-cols-2 gap-4 mt-8">
            <button 
              disabled={isProcessing}
              onClick={() => handleAdjust(false)}
              className="flex items-center justify-center gap-2 p-5 bg-red-500/10 text-red-500 font-black text-xs uppercase tracking-widest rounded-2xl hover:bg-red-500 hover:text-white transition-all disabled:opacity-50"
            >
              Deduct
            </button>
            <button 
              disabled={isProcessing}
              onClick={() => handleAdjust(true)}
              className="flex items-center justify-center gap-2 p-5 bg-emerald-600 text-white font-black text-xs uppercase tracking-widest rounded-2xl hover:bg-emerald-700 transition-all disabled:opacity-50 shadow-lg shadow-emerald-500/20"
            >
              Add Credits
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

const PackageModal = ({ pkg, onClose, onUpdate }) => {
  const [diamonds, setDiamonds] = useState(pkg?.diamonds || '');
  const [price, setPrice] = useState(pkg?.price || '');
  const [isProcessing, setIsProcessing] = useState(false);

  const handleSubmit = async () => {
    if (!diamonds || !price) return;
    setIsProcessing(true);
    try {
      const updatePkg = httpsCallable(functions, 'updateDiamondPackage');
      await updatePkg({ 
        packageId: pkg?.id, 
        diamonds: parseInt(diamonds), 
        price: parseFloat(price) 
      });
      alert("Package updated successfully.");
      onUpdate();
      onClose();
    } catch (err) {
      alert(err.message);
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
      <div className="bg-[#09090B] border border-white/10 w-full max-w-md rounded-3xl p-8 shadow-2xl">
        <h2 className="text-xl font-black text-white uppercase tracking-widest mb-6">{pkg ? 'Edit Package' : 'Create Package'}</h2>
        <div className="space-y-4">
          <div>
            <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Diamonds</label>
            <input 
              type="number" 
              className="w-full bg-black border border-white/10 rounded-xl p-4 text-white focus:border-indigo-500 outline-none"
              value={diamonds}
              onChange={(e) => setDiamonds(e.target.value)}
            />
          </div>
          <div>
            <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Price (USD)</label>
            <input 
              type="number" 
              className="w-full bg-black border border-white/10 rounded-xl p-4 text-white focus:border-indigo-500 outline-none"
              value={price}
              onChange={(e) => setPrice(e.target.value)}
            />
          </div>
          <button 
            disabled={isProcessing}
            onClick={handleSubmit}
            className="w-full py-4 mt-4 bg-indigo-600 text-white font-black rounded-xl hover:bg-indigo-700 disabled:opacity-50"
          >
            {isProcessing ? 'Saving...' : 'Save Package'}
          </button>
          <button onClick={onClose} className="w-full py-4 bg-white/5 text-slate-400 font-black rounded-xl hover:bg-white/10">Cancel</button>
        </div>
      </div>
    </div>
  );
};

export const ResellerManagement = () => {
    const [activeTab, setActiveTab] = useState('resellers');
    const [resellers, setResellers] = useState([]);
    const [packages, setPackages] = useState([]);
    const [transactions, setTransactions] = useState([]);
    const [loading, setLoading] = useState(true);
    const [selectedReseller, setSelectedReseller] = useState(null);
    const [selectedPackage, setSelectedPackage] = useState(null);
    const [showPkgModal, setShowPkgModal] = useState(false);

    useEffect(() => {
        fetchData();
    }, [activeTab]);

    const fetchData = async () => {
        setLoading(true);
        try {
            console.log("Fetching data for tab:", activeTab);
            
            if (activeTab === 'resellers') {
                const q = query(collection(db, "users"), where("isReseller", "==", true));
                const snap = await getDocs(q);
                const data = snap.docs.map(d => ({ id: d.id, ...d.data() }));
                console.log("Resellers loaded:", data.length);
                setResellers(data);
            } else if (activeTab === 'packages') {
                const getPkgs = httpsCallable(functions, 'getDiamondPackages');
                const result = await getPkgs();
                const pkgs = result.data.packages || [];
                console.log("Packages loaded:", pkgs.length);
                setPackages(pkgs);
            } else if (activeTab === 'history') {
                const getHistory = httpsCallable(functions, 'getResellerHistory');
                const result = await getHistory({ limitCount: 50 });
                const txs = result.data.transactions || [];
                console.log("History loaded:", txs.length);
                setTransactions(txs);
            }
        } catch (err) {
            console.error(`Error loading ${activeTab}:`, err);
            alert(`Error: ${err.message}`);
        } finally {
            setLoading(false);
        }
    };

    const handleDeletePackage = async (id) => {
        if (!window.confirm("Delete this package?")) return;
        try {
            const updatePkg = httpsCallable(functions, 'updateDiamondPackage');
            await updatePkg({ packageId: id, isDeleted: true });
            fetchData();
        } catch (err) {
            alert(err.message);
        }
    };

    return (
        <div className="p-8 space-y-8 min-h-screen bg-[#020617] text-slate-200">
            {selectedReseller && (
                <WalletAdjustmentModal 
                    reseller={selectedReseller} 
                    onClose={() => setSelectedReseller(null)} 
                    onUpdate={fetchData} 
                />
            )}

            {showPkgModal && (
                <PackageModal 
                    pkg={selectedPackage} 
                    onClose={() => { setShowPkgModal(false); setSelectedPackage(null); }} 
                    onUpdate={fetchData} 
                />
            )}

            <div className="flex flex-col md:flex-row md:items-center justify-between gap-8 pb-8 border-b border-white/5">
                <div>
                    <h1 className="text-4xl font-black text-white tracking-widest uppercase flex items-center gap-4">
                        <Store className="text-emerald-400" size={32} />
                        Reseller Control
                    </h1>
                    <p className="text-slate-500 font-bold text-xs uppercase tracking-widest mt-2 flex items-center gap-2">
                        <DollarSign size={14} className="text-emerald-500" />
                        Manage diamond stock and reseller liquidity in USD
                    </p>
                </div>

                <div className="flex items-center gap-4">
                  <button 
                    onClick={fetchData}
                    disabled={loading}
                    className="p-3 bg-white/5 text-slate-400 rounded-2xl hover:bg-white/10 transition-all disabled:opacity-50"
                  >
                    <RefreshCw size={20} className={loading ? "animate-spin" : ""} />
                  </button>

                  <div className="flex bg-slate-900 p-1 rounded-2xl border border-white/5">
                      {[
                          { id: 'resellers', label: 'Resellers', icon: Users },
                          { id: 'packages', label: 'Packages', icon: Diamond },
                          { id: 'history', label: 'History', icon: History }
                      ].map(tab => (
                          <button
                              key={tab.id}
                              onClick={() => setActiveTab(tab.id)}
                              className={`flex items-center gap-2 px-6 py-3 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${
                                  activeTab === tab.id ? 'bg-indigo-600 text-white shadow-lg' : 'text-slate-500 hover:text-white'
                              }`}
                          >
                              <tab.icon size={16} />
                              {tab.label}
                          </button>
                      ))}
                  </div>
                </div>
            </div>

            {loading ? (
                <div className="h-96 flex flex-col items-center justify-center space-y-4">
                    <div className="w-12 h-12 border-4 border-emerald-500 border-t-transparent rounded-full animate-spin"></div>
                    <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest animate-pulse">Syncing Reseller Data...</p>
                </div>
            ) : (
                <AnimatePresence mode="wait">
                    <motion.div
                        key={activeTab}
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, y: -20 }}
                        className="space-y-6"
                    >
                        {activeTab === 'resellers' && (
                            <div className="bg-[#09090B] border border-white/5 rounded-[2.5rem] overflow-hidden shadow-2xl">
                                <table className="w-full text-left">
                                    <thead>
                                        <tr className="border-b border-white/5 bg-white/[0.02]">
                                            <th className="px-8 py-6 text-[10px] font-black text-slate-500 uppercase tracking-[0.2em]">Reseller</th>
                                            <th className="px-8 py-6 text-[10px] font-black text-slate-500 uppercase tracking-[0.2em]">Wallet Balance</th>
                                            <th className="px-8 py-6 text-[10px] font-black text-slate-500 uppercase tracking-[0.2em]">Diamond Stock</th>
                                            <th className="px-8 py-6 text-[10px] font-black text-slate-500 uppercase tracking-[0.2em]">Actions</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-white/5">
                                        {resellers.map(reseller => (
                                            <tr key={reseller.id} className="hover:bg-white/[0.01] transition-colors group">
                                                <td className="px-8 py-6">
                                                    <div className="flex items-center gap-4">
                                                        <img src={reseller.profilePhotoUrl || `https://api.dicebear.com/7.x/avataaars/png?seed=${reseller.id}`} className="w-12 h-12 rounded-2xl object-cover ring-2 ring-white/5" alt="avatar" />
                                                        <div>
                                                            <p className="font-black text-white uppercase tracking-tight">{reseller.displayName}</p>
                                                            <p className="text-[10px] font-bold text-slate-500 uppercase tracking-tighter">@{reseller.username}</p>
                                                        </div>
                                                    </div>
                                                </td>
                                                <td className="px-8 py-6">
                                                    <p className="text-xl font-black text-emerald-400 tracking-tighter">${reseller.walletBalance?.toFixed(2) || '0.00'}</p>
                                                </td>
                                                <td className="px-8 py-6">
                                                    <div className="flex items-center gap-2">
                                                        <Diamond size={14} className="text-indigo-400" />
                                                        <p className="font-black text-slate-300 uppercase tracking-widest">{reseller.diamondBalance || 0}</p>
                                                    </div>
                                                </td>
                                                <td className="px-8 py-6">
                                                    <button 
                                                        onClick={() => setSelectedReseller(reseller)}
                                                        className="px-6 py-3 bg-emerald-500/10 text-emerald-500 border border-emerald-500/10 rounded-xl text-[10px] font-black uppercase tracking-widest hover:bg-emerald-500 hover:text-white transition-all shadow-lg shadow-emerald-500/10"
                                                    >
                                                        Adjust Wallet
                                                    </button>
                                                </td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        )}

                        {activeTab === 'packages' && (
                            <div className="space-y-6">
                                <div className="flex justify-between items-center bg-[#09090B] p-8 rounded-[2rem] border border-white/5">
                                    <div>
                                        <h2 className="text-xl font-black text-white uppercase tracking-widest">Inventory Management</h2>
                                        <p className="text-[10px] font-bold text-slate-500 uppercase tracking-[0.2em] mt-1">Configure diamond packs for resellers</p>
                                    </div>
                                    <button 
                                        onClick={() => { setSelectedPackage(null); setShowPkgModal(true); }}
                                        className="flex items-center gap-3 px-8 py-4 bg-indigo-600 text-white font-black text-[10px] uppercase tracking-[0.2em] rounded-2xl hover:bg-indigo-700 transition-all shadow-xl shadow-indigo-500/20"
                                    >
                                        <Plus size={18} /> New Package
                                    </button>
                                </div>

                                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                                    {packages.map(pkg => (
                                        <div key={pkg.id} className="bg-[#09090B] border border-white/5 rounded-[2.5rem] p-8 relative overflow-hidden group hover:border-indigo-500/30 transition-all">
                                            <div className="absolute top-0 right-0 p-8">
                                              <button onClick={() => handleDeletePackage(pkg.id)} className="text-slate-600 hover:text-red-500 transition-colors">
                                                <Trash2 size={18} />
                                              </button>
                                            </div>
                                            <div className="p-4 bg-indigo-500/10 text-indigo-400 rounded-2xl w-fit mb-6">
                                                <Diamond size={32} />
                                            </div>
                                            <h3 className="text-2xl font-black text-white uppercase tracking-tight mb-1">{pkg.diamonds} Diamonds</h3>
                                            <p className="text-4xl font-black text-emerald-400 tracking-tighter mb-8">${pkg.price?.toFixed(2)}</p>
                                            <button 
                                                onClick={() => { setSelectedPackage(pkg); setShowPkgModal(true); }}
                                                className="w-full py-4 bg-white/5 text-slate-400 border border-white/5 rounded-2xl text-[10px] font-black uppercase tracking-widest hover:bg-white/10 hover:text-white transition-all"
                                            >
                                                Edit Configuration
                                            </button>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        )}

                        {activeTab === 'history' && (
                            <div className="bg-[#09090B] border border-white/5 rounded-[2.5rem] overflow-hidden shadow-2xl">
                                <table className="w-full text-left">
                                    <thead>
                                        <tr className="border-b border-white/5 bg-white/[0.02]">
                                            <th className="px-8 py-6 text-[10px] font-black text-slate-500 uppercase tracking-[0.2em]">Transaction ID</th>
                                            <th className="px-8 py-6 text-[10px] font-black text-slate-500 uppercase tracking-[0.2em]">Date</th>
                                            <th className="px-8 py-6 text-[10px] font-black text-slate-500 uppercase tracking-[0.2em]">Category</th>
                                            <th className="px-8 py-6 text-[10px] font-black text-slate-500 uppercase tracking-[0.2em]">Volume</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-white/5">
                                        {transactions.map(tx => (
                                            <tr key={tx.id} className="hover:bg-white/[0.01] transition-colors group">
                                                <td className="px-8 py-6">
                                                    <p className="font-mono text-[10px] text-slate-500">#{tx.id.slice(0, 12).toUpperCase()}</p>
                                                </td>
                                                <td className="px-8 py-6">
                                                    <p className="text-[10px] font-bold text-slate-400 uppercase tracking-tighter">
                                                        {tx.timestamp ? (typeof tx.timestamp === 'string' ? new Date(tx.timestamp).toLocaleString() : tx.timestamp.toDate().toLocaleString()) : 'N/A'}
                                                    </p>
                                                </td>
                                                <td className="px-8 py-6">
                                                    <span className={`px-4 py-1.5 rounded-lg text-[9px] font-black uppercase tracking-widest ${
                                                        tx.type?.includes('DIAMOND') ? 'bg-indigo-500/10 text-indigo-400 border border-indigo-500/20' : 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20'
                                                    }`}>
                                                        {tx.type || 'SYSTEM'}
                                                    </span>
                                                </td>
                                                <td className="px-8 py-6">
                                                    <div className="flex items-center gap-2">
                                                        {tx.type?.includes('CREDIT') ? <ArrowUpRight className="text-emerald-500" size={14} /> : <ArrowDownLeft className="text-indigo-400" size={14} />}
                                                        <p className={`font-black uppercase tracking-widest ${tx.type?.includes('CREDIT') ? 'text-emerald-400' : 'text-slate-300'}`}>
                                                            {tx.amount} {tx.currency}
                                                        </p>
                                                    </div>
                                                </td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        )}
                    </motion.div>
                </AnimatePresence>
            )}
        </div>
    );
};

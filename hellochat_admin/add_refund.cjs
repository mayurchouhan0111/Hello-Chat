const fs = require('fs');
const path = 'src/screens/VIPManagement.jsx';
let content = fs.readFileSync(path, 'utf8');

// 1. Add refund state variables after useAdmin line
const stateInsert = `
  const [searchHelloId, setSearchHelloId] = useState("");
  const [targetUser, setTargetUser] = useState(null);
  const [refundDetails, setRefundDetails] = useState(null);
  const [searching, setSearching] = useState(false);
  const [refundReason, setRefundReason] = useState("");
  const [executingRefund, setExecutingRefund] = useState(false);
`;
content = content.replace(
  "const { user } = useAdmin();",
  "const { user } = useAdmin();" + stateInsert
);

// 2. Add refund handler functions after handleDelete
const handleSearchUser = `
  const handleSearchUser = async (e) => {
    e.preventDefault();
    if (!searchHelloId) return;
    setSearching(true);
    try {
      const q = query(collection(db, "users"), where("helloId", "==", parseInt(searchHelloId)));
      const usersSnap = await getDocs(q);
      if (usersSnap.empty) {
        alert("No user found with that Hello ID.");
        setTargetUser(null);
        setRefundDetails(null);
        return;
      }
      const userData = usersSnap.docs[0].data();
      setTargetUser({ ...userData, id: usersSnap.docs[0].id });
      const now = new Date();
      const expiry = userData.vipExpiry?.toDate();
      if (!userData.vipTier || userData.vipTier === "none") {
        alert("This user does not currently have an active VIP subscription.");
        setRefundDetails(null);
        return;
      }
      if (!expiry || expiry < now) {
        alert("VIP has already expired. No refund applicable.");
        setRefundDetails(null);
        return;
      }
      const remainingDays = Math.ceil((expiry - now) / (1000 * 60 * 60 * 24));
      const tierSnap = await getDocs(query(collection(db, "vip_tiers"), where("__name__", "==", userData.vipTier)));
      let price = 0;
      if (!tierSnap.empty) {
        price = tierSnap.docs[0].data().monthlyPriceInDiamonds || 0;
      }
      const refundAmt = Math.round(price * 0.2 * (remainingDays / 30));
      setRefundDetails({ expiryString: expiry.toDateString(), remainingDays, price, refundAmt });
    } catch (err) {
      alert("Lookup Error: " + err.message);
    } finally {
      setSearching(false);
    }
  };
`;
content = content.replace(
  "  const handleDelete = async (tierId) => {",
  handleSearchUser + "\n  const handleDelete = async (tierId) => {"
);

const handleExecuteRefund = `
  const handleExecuteRefund = async (e) => {
    e.preventDefault();
    if (!targetUser || !refundDetails) return;
    if (!window.confirm("EXECUTE VIP REVOCATION AND REFUND for " + targetUser.displayName + "? This action CANNOT be undone.")) return;
    setExecutingRefund(true);
    try {
      const refundFn = httpsCallable(functions, "refundVip");
      const res = await refundFn({ helloId: searchHelloId, reason: refundReason });
      alert("VIP revoked. Refunded " + res.data.refundedDiamonds + " diamonds.");
      setTargetUser(null);
      setRefundDetails(null);
      setSearchHelloId("");
      setRefundReason("");
    } catch (err) {
      alert("Refund Error: " + (err.message || "Unknown"));
    } finally {
      setExecutingRefund(false);
    }
  };
`;
content = content.replace(
  "  const handleDelete = async (tierId) => {",
  handleExecuteRefund + "\n  const handleDelete = async (tierId) => {"
);

// 3. Add VIP Refunds button in category bar (after SVIP button)
const refundButton = 
`        <button 
          onClick={() => setCategory("vip_refunds")}
          className={\`px-8 py-3 rounded-xl font-black uppercase text-[10px] tracking-widest transition-all \${
            category === 'vip_refunds' 
              ? 'bg-amber-500 text-black' 
              : 'bg-white/5 text-slate-500'
          }\`}
        >
          <AlertTriangle size={14} className="inline mr-1" /> Refunds
        </button>
        `;
content = content.replace(
  `        <button 
          onClick={startCreating}`,
  refundButton + `        <button 
          onClick={startCreating}`
);

// 4. Add refund section before the main content grid
const refundSection = `
      {category === 'vip_refunds' ? (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-10 animate-fade-in">
          <div className="card-glass p-10 bg-[#18181B]/80 border-amber-500/30 shadow-2xl">
            <h3 className="text-xl font-black text-white tracking-tight uppercase flex items-center gap-4 border-b border-white/5 pb-6">
              <Crown className="text-amber-500 animate-pulse" size={24} /> User Lookup
            </h3>
            <form onSubmit={handleSearchUser} className="space-y-6 pt-6">
              <div className="space-y-3">
                <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Search by Hello ID</label>
                <div className="flex gap-4">
                  <input 
                    required type="number"
                    placeholder="Enter User Hello ID..."
                    className="input-field flex-1 h-14 bg-slate-950/50 text-white font-mono pl-4"
                    value={searchHelloId}
                    onChange={(e) => setSearchHelloId(e.target.value)}
                  />
                  <button 
                    type="submit"
                    disabled={searching}
                    className="px-6 bg-amber-500 hover:bg-amber-600 text-black font-black uppercase text-xs tracking-wider rounded-2xl transition-all disabled:opacity-50"
                  >
                    {searching ? "Scanning..." : "Scan"}
                  </button>
                </div>
              </div>
            </form>
            {targetUser && refundDetails && (
              <div className="mt-8 space-y-6 border-t border-white/5 pt-6 animate-fade-in">
                <div className="flex items-center gap-4 bg-white/5 p-4 rounded-2xl border border-white/5">
                  <img src={targetUser.profilePhotoUrl} alt="avatar" className="w-16 h-16 rounded-full object-cover border border-white/10" />
                  <div>
                    <h4 className="text-lg font-black text-white">{targetUser.displayName}</h4>
                    <p className="text-xs text-slate-500 font-mono">Hello ID: {targetUser.helloId}</p>
                  </div>
                </div>
                <div className="space-y-4 bg-white/[0.02] p-6 rounded-2xl border border-white/5">
                  <div className="flex justify-between">
                    <span className="text-xs text-slate-400">Current VIP Tier</span>
                    <span className="text-xs font-black text-amber-500 uppercase">{targetUser.vipTier}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-xs text-slate-400">Expiration Date</span>
                    <span className="text-xs font-black text-slate-300">{refundDetails.expiryString}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-xs text-slate-400">Remaining Days</span>
                    <span className="text-xs font-black text-slate-300">{refundDetails.remainingDays} Days</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-xs text-slate-400">Monthly Tier Price</span>
                    <span className="text-xs font-black text-emerald-400">{refundDetails.price.toLocaleString()} \u{1F48E}</span>
                  </div>
                  <div className="border-t border-white/5 pt-4 flex justify-between">
                    <span className="text-sm font-black text-white">Estimated Refund</span>
                    <span className="text-sm font-black text-emerald-400">{refundDetails.refundAmt.toLocaleString()} \u{1F48E}</span>
                  </div>
                </div>
              </div>
            )}
          </div>
          <div className="card-glass p-10 bg-[#18181B]/80 border-red-500/30 shadow-2xl">
            <h3 className="text-xl font-black text-white tracking-tight uppercase flex items-center gap-4 border-b border-white/5 pb-6">
              <Trash2 className="text-red-500 animate-pulse" size={24} /> Revocation Actions
            </h3>
            {targetUser ? (
              <form onSubmit={handleExecuteRefund} className="space-y-6 pt-6 animate-fade-in">
                <div className="space-y-3">
                  <label className="text-[10px] font-black text-slate-500 uppercase tracking-widest ml-1">Reason for Revocation</label>
                  <textarea 
                    required
                    placeholder="Provide a reason for the VIP cancellation and refund..."
                    className="input-field w-full h-32 bg-slate-950/50 text-white p-4 resize-none"
                    value={refundReason}
                    onChange={(e) => setRefundReason(e.target.value)}
                  />
                </div>
                <div className="bg-red-500/10 border border-red-500/20 p-6 rounded-2xl space-y-2">
                  <h5 className="text-xs font-black text-red-400 uppercase tracking-wider">Warning: Permanent Action</h5>
                  <p className="text-[11px] text-red-500/80 leading-relaxed font-semibold">
                    Executing this action will immediately revoke the user's VIP status, restore their original cosmetic snapshot, delete pending retention bonuses, and refund {refundDetails?.refundAmt.toLocaleString()} diamonds.
                  </p>
                </div>
                <button 
                  type="submit"
                  disabled={executingRefund}
                  className="w-full py-5 bg-red-600 hover:bg-red-700 text-white font-black uppercase text-xs tracking-wider rounded-[32px] transition-all disabled:opacity-50"
                >
                  {executingRefund ? "Executing Revocation..." : "EXECUTE VIP REVOCATION & REFUND"}
                </button>
              </form>
            ) : (
              <div className="p-20 text-center flex flex-col items-center justify-center min-h-[350px]">
                <Crown className="text-slate-800 mb-2" size={48} />
                <p className="text-slate-700 font-bold uppercase tracking-widest text-xs">Lookup a user to display actions</p>
              </div>
            )}
          </div>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-10">
`;

// Find the start of the main content grid
const mainGridStart = '<div className="grid grid-cols-1 lg:grid-cols-2 gap-10">';
const firstGridIndex = content.indexOf(mainGridStart);
if (firstGridIndex !== -1) {
  content = content.slice(0, firstGridIndex) + refundSection + content.slice(firstGridIndex + mainGridStart.length);
}

// 5. Fix: The main grid's closing `</div>` is only needed once now (already in file)
// But we added a ternary that needs a closing `)` for the `: (` branch
// The original closing div is </div>\n\n      </div>\n    </div>\n  );\n};
// We need to add a closing ) before it
const originalEnding = '\n      </div>\n    </div>\n  );\n};';
const closingParen = '\n        </div>\n      )';
if (content.endsWith(originalEnding)) {
  content = content.slice(0, -originalEnding.length) + closingParen + originalEnding;
}

fs.writeFileSync(path, content, 'utf8');
console.log('Done - refund section added');

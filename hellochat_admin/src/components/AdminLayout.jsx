import { useEffect } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { useAdmin } from '../context/AdminContext';
import { 
  Users, 
  LayoutDashboard, 
  UsersRound, 
  Flag, 
  MessageSquare, 
  Settings, 
  LogOut, 
  Coins, 
  Volume2, 
  ShieldAlert,
  Gift,
  Crown,
  Building2,
  History,
  Gamepad2,
  Database,
  ArrowRightLeft,
  ShoppingBag,
  Store,
  Image
} from 'lucide-react';
import logo from '../assets/logo.webp';


const Sidebar = () => {
  const { logout, isAdmin, isAgencyOwner } = useAdmin();
  const navigate = useNavigate();
  const location = useLocation();

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  const fullMenu = [
    { name: 'Dashboard', icon: LayoutDashboard, path: '/' },
    { name: 'Users', icon: Users, path: '/users' },
    { name: 'Live Rooms', icon: Volume2, path: '/rooms' },
    { name: 'Gifts', icon: Gift, path: '/gifts' },
    { name: 'VIP Store', icon: Crown, path: '/vip' },
    { name: 'Elite Boutique', icon: ShoppingBag, path: '/boutique' },
    { name: 'Resellers', icon: Store, path: '/resellers' },
    { name: 'Agencies', icon: Building2, path: '/agencies' },
    { name: 'Families', icon: UsersRound, path: '/families' },
    { name: 'Financials', icon: Coins, path: '/financials' },
    { name: 'Reports', icon: ShieldAlert, path: '/reports' },
    { name: 'Moments', icon: Image, path: '/moments' },
    { name: 'Moderation', icon: Flag, path: '/moderation' },
    { name: 'Mini Games', icon: Gamepad2, path: '/minigames' },
    { name: 'Settings', icon: Settings, path: '/settings' },
    { name: 'Audit Trail', icon: History, path: '/logs' },
    { name: 'Withdrawals', icon: ArrowRightLeft, path: '/withdrawals' },
    { name: 'Dev Tools', icon: Database, path: '/dev' },
  ];

  const menu = (isAgencyOwner && !isAdmin) 
    ? [{ name: 'Agency Portal', icon: Building2, path: '/agencies' }] 
    : fullMenu;

  return (
    <div className="w-72 bg-[#080809] h-screen text-gray-400 flex flex-col border-r border-white/[0.05] shadow-[10px_0_30px_rgba(0,0,0,0.5)] z-50">
      <div className="p-8">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 flex items-center justify-center relative bg-gradient-to-br from-white/[0.05] to-transparent border border-white/10 rounded-[20px] shadow-2xl overflow-hidden group">
            <div className="absolute inset-0 bg-gradient-to-br from-[#00E5FF]/20 to-[#6366F1]/20 opacity-0 group-hover:opacity-100 transition-opacity duration-500"></div>
            <div className="absolute -inset-1 bg-gradient-to-r from-[#00E5FF] to-[#6366F1] opacity-20 blur-lg"></div>
            <img 
              src={logo} 
              className="w-10 h-10 object-contain relative z-10 drop-shadow-[0_0_12px_rgba(0,229,255,0.6)] group-hover:scale-110 transition-transform duration-500" 
              alt="Logo"
            />
          </div>
          <div>
            <h1 className="text-xl font-black text-white leading-none tracking-tighter bg-clip-text text-transparent bg-gradient-to-r from-white to-gray-400">
              {isAdmin ? 'HELLO' : 'AGENCY'}
            </h1>
            <p className="text-[9px] font-black text-[#00E5FF] tracking-[0.3em] mt-1.5 uppercase opacity-80">System Admin</p>
          </div>
        </div>
      </div>

      <nav className="flex-1 mt-4 px-4 space-y-1 overflow-y-auto no-scrollbar pb-10">
        <p className="px-4 text-[10px] font-black text-gray-700 tracking-[0.2em] mb-4 uppercase">Main Management</p>
        {menu.map((item) => {
          const isActive = location.pathname === item.path;
          return (
            <Link
              key={item.name}
              to={item.path}
              className={`sidebar-link group ${isActive ? 'sidebar-link-active' : 'hover:bg-white/[0.03] hover:text-white'}`}
            >
              <item.icon size={18} className={isActive ? 'text-black' : 'text-gray-500 group-hover:text-[#00E5FF] transition-colors'} />
              <span className="font-bold text-[13px] tracking-tight">{item.name}</span>
              {isActive && (
                <div className="absolute right-0 w-1.5 h-6 bg-black rounded-l-full" />
              )}
            </Link>
          );
        })}
      </nav>

      <div className="p-6 border-t border-white/[0.03] bg-white/[0.01]">
        <button
          onClick={handleLogout}
          className="flex items-center gap-4 px-5 py-4 w-full rounded-2xl text-red-400 hover:bg-red-400/10 transition-all group"
        >
          <LogOut size={18} className="group-hover:rotate-12 transition-transform" />
          <span className="font-bold text-[13px]">Sign Out</span>
        </button>
      </div>
    </div>
  );
};

const TopBar = () => {
  const { user } = useAdmin();
  const location = useLocation();
  const pageTitle = location.pathname === '/' ? 'Overview' : location.pathname.substring(1).replace('-', ' ');

  return (
    <header className="h-20 border-b border-white/[0.03] bg-[#0A0A0B]/80 backdrop-blur-xl flex items-center justify-between px-10 sticky top-0 z-40">
      <div>
        <h2 className="text-xl font-black text-white capitalize tracking-tight">{pageTitle}</h2>
        <p className="text-[11px] font-medium text-gray-500">Welcome back, Super Admin</p>
      </div>

      <div className="flex items-center gap-6">
        <div className="flex items-center gap-3 bg-white/[0.03] border border-white/[0.05] pl-2 pr-4 py-1.5 rounded-full">
          <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-[#00E5FF] to-blue-600 flex items-center justify-center font-black text-black text-xs">
            {user?.email?.substring(0, 1).toUpperCase()}
          </div>
          <div>
            <p className="text-xs font-black text-white leading-none">{user?.email?.split('@')[0]}</p>
            <p className="text-[10px] text-gray-500 font-bold mt-1">Administrator</p>
          </div>
        </div>
      </div>
    </header>
  );
};

export const AdminLayout = ({ children }) => {
  const { user, isAdmin, isAgencyOwner, loading } = useAdmin();
  const navigate = useNavigate();

  useEffect(() => {
    if (!loading && (!user || (!isAdmin && !isAgencyOwner))) {
      navigate('/login');
    }
  }, [user, isAdmin, isAgencyOwner, loading, navigate]);

  if (loading) return (
    <div className="h-screen bg-[#0A0A0B] flex items-center justify-center">
      <div className="relative">
        <div className="w-16 h-16 border-4 border-yellow-400/10 rounded-full"></div>
        <div className="w-16 h-16 border-4 border-yellow-400 border-t-transparent rounded-full animate-spin absolute top-0 left-0 shadow-lg shadow-yellow-400/20"></div>
      </div>
    </div>
  );

  return (
    <div className="flex bg-[#0A0A0B] min-h-screen text-white selection:bg-yellow-400 selection:text-black">
      <Sidebar />
      <div className="flex-1 flex flex-col h-screen overflow-hidden">
        <TopBar />
        <main className="flex-1 overflow-y-auto p-10 custom-scrollbar scroll-smooth">
          <div className="max-w-[1600px] mx-auto animate-in fade-in slide-in-from-bottom-4 duration-700">
            {children}
          </div>
        </main>
      </div>
    </div>
  );
};

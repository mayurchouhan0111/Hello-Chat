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
  History
} from 'lucide-react';

const Sidebar = () => {
  const { logout } = useAdmin();
  const navigate = useNavigate();
  const location = useLocation();

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  const menu = [
    { name: 'Dashboard', icon: LayoutDashboard, path: '/' },
    { name: 'Users', icon: Users, path: '/users' },
    { name: 'Live Rooms', icon: Volume2, path: '/rooms' },
    { name: 'Gifts', icon: Gift, path: '/gifts' },
    { name: 'VIP Store', icon: Crown, path: '/vip' },
    { name: 'Agencies', icon: Building2, path: '/agencies' },
    { name: 'Financials', icon: Coins, path: '/financials' },
    { name: 'Reports', icon: ShieldAlert, path: '/reports' },
    { name: 'Moderation', icon: Flag, path: '/moderation' },
    { name: 'Settings', icon: Settings, path: '/settings' },
    { name: 'Audit Trail', icon: History, path: '/logs' },
  ];

  return (
    <div className="w-64 bg-sidebar h-screen text-gray-300 flex flex-col border-r border-white/5 shadow-2xl">
      <div className="p-6">
        <h1 className="text-xl font-black text-primary-light flex items-center gap-2">
          <div className="bg-primary p-2 rounded-xl shadow-lg border border-white/10">
            <ShieldAlert className="text-white" size={24} />
          </div>
          HELLO ADMIN
        </h1>
      </div>

      <nav className="flex-1 mt-6 px-4 space-y-1">
        {menu.map((item) => (
          <Link
            key={item.name}
            to={item.path}
            className={`flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-300 group ${
              location.pathname === item.path 
              ? 'bg-primary text-white shadow-lg' 
              : 'hover:bg-white/5 hover:text-white'
            }`}
          >
            <item.icon size={20} className={location.pathname === item.path ? 'text-white' : 'text-gray-500 group-hover:text-primary-light'} />
            <span className="font-semibold text-sm">{item.name}</span>
          </Link>
        ))}
      </nav>

      <div className="p-4 border-t border-white/5">
        <button
          onClick={handleLogout}
          className="flex items-center gap-3 px-4 py-3 w-full rounded-xl text-red-400 hover:bg-red-400/10 transition-colors"
        >
          <LogOut size={20} />
          <span className="font-bold text-sm">Sign Out</span>
        </button>
      </div>
    </div>
  );
};

export const AdminLayout = ({ children }) => {
  const { user, isAdmin, loading } = useAdmin();
  const navigate = useNavigate();

  useEffect(() => {
    if (!loading && (!user || !isAdmin)) {
      navigate('/login');
    }
  }, [user, isAdmin, loading, navigate]);

  if (loading) return (
    <div className="h-screen bg-sidebar flex items-center justify-center">
      <div className="w-12 h-12 border-4 border-primary border-t-transparent rounded-full animate-spin"></div>
    </div>
  );

  return (
    <div className="flex bg-slate-900 min-h-screen">
      <Sidebar />
      <main className="flex-1 overflow-auto p-10 bg-[radial-gradient(circle_at_top_right,_var(--tw-gradient-stops))] from-blue-900/10 via-slate-900 to-slate-900">
        {children}
      </main>
    </div>
  );
};

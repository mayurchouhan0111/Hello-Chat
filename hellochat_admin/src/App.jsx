import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { AdminProvider } from './context/AdminContext';
import { RequireRole } from './components/RequireRole';
import { LoginScreen } from './screens/LoginScreen';
import { AdminLayout } from './components/AdminLayout';
import { DashboardHome } from './screens/DashboardHome';
import { UserManagement } from './screens/UserManagement';
import { RoomManagement } from './screens/RoomManagement';
import { FinancialManagement } from './screens/FinancialManagement';
import { ModerationReports } from './screens/ModerationReports';
import { SystemSettings } from './screens/SystemSettings';
import { ModerationManagement } from './screens/ModerationManagement';
import { GiftManagement } from './screens/GiftManagement';
import { VIPManagement } from './screens/VIPManagement';
import { AuditLogs } from './screens/AuditLogs';
import { AgencyManagement } from './screens/AgencyManagement';
import { MiniGamesManagement } from './screens/MiniGamesManagement';
import { WithdrawalManagement } from './screens/WithdrawalManagement';
import { EliteBoutiqueManagement } from './screens/EliteBoutiqueManagement';
import { FamilyManagement } from './screens/FamilyManagement';
import { ResellerManagement } from './screens/ResellerManagement';
import { MomentsManagement } from './screens/MomentsManagement';
import { KYCManagement } from './screens/KYCManagement';
import { RoomSupportManagement } from './screens/RoomSupportManagement';
import { FamilyBattleConfig } from './screens/FamilyBattleConfig';
import { EventBuilder } from './screens/EventBuilder';
import { RechargeEventManagement } from './screens/RechargeEventManagement';
import { RelationshipManagement } from './screens/RelationshipManagement';
import { RoleFrameManagement } from './screens/RoleFrameManagement';
import { RocketManagement } from './screens/RocketManagement';
import { WinningConfigManagement } from './screens/WinningConfigManagement';

import { SVIPManagement } from './screens/SVIPManagement';
import { HierarchyManagement } from './screens/HierarchyManagement';
import { HostMetrics } from './screens/HostMetrics';
import { CommissionWallet } from './screens/CommissionWallet';

/**
 * HB-PMS route table.
 *
 * `min` is the lowest tier that may open the screen, and mirrors the navigation
 * menus already built into AdminLayout:
 *   agency     -> portal + its own roster
 *   admin      -> branch users / agencies / rooms / reports
 *   superadmin -> branch configuration
 *   owner      -> everything (money, payout, content, settings, audit)
 *
 * The screen is the only convenience: the callable behind each screen enforces
 * the same tier again, so widening a `min` here cannot widen real access.
 */
const ROUTES = [
  { path: '/', min: 'agency', element: <DashboardHome /> },

  // ── Agency portal & Commission Wallet ──
  { path: '/agencies', min: 'agency', element: <AgencyManagement /> },
  { path: '/hosts', min: 'agency', element: <HostMetrics /> },
  { path: '/commission-wallet', min: 'agency', element: <CommissionWallet /> },

  // ── Branch staff ──
  { path: '/users', min: 'admin', element: <UserManagement /> },
  { path: '/rooms', min: 'admin', element: <RoomManagement /> },
  { path: '/reports', min: 'admin', element: <ModerationReports /> },

  // ── Super Admin ──
  { path: '/hierarchy', min: 'superadmin', element: <HierarchyManagement /> },

  // ── Owner only: money, payout, platform content, settings, audit ──
  { path: '/financials', min: 'owner', element: <FinancialManagement /> },
  { path: '/withdrawals', min: 'owner', element: <WithdrawalManagement /> },
  { path: '/resellers', min: 'owner', element: <ResellerManagement /> },
  { path: '/kyc', min: 'owner', element: <KYCManagement /> },
  { path: '/settings', min: 'owner', element: <SystemSettings /> },
  { path: '/logs', min: 'owner', element: <AuditLogs /> },
  { path: '/moderation', min: 'owner', element: <ModerationManagement /> },
  { path: '/moments', min: 'owner', element: <MomentsManagement /> },
  { path: '/vip', min: 'owner', element: <VIPManagement /> },
  { path: '/svip', min: 'owner', element: <SVIPManagement /> },
  { path: '/gifts', min: 'owner', element: <GiftManagement /> },
  { path: '/families', min: 'owner', element: <FamilyManagement /> },
  { path: '/boutique', min: 'owner', element: <EliteBoutiqueManagement /> },
  { path: '/role-frames', min: 'owner', element: <RoleFrameManagement /> },
  { path: '/rocket-management', min: 'owner', element: <RocketManagement /> },
  { path: '/winning-config', min: 'owner', element: <WinningConfigManagement /> },
  { path: '/minigames', min: 'owner', element: <MiniGamesManagement /> },
  { path: '/family-battle-config', min: 'owner', element: <FamilyBattleConfig /> },
  { path: '/room-support', min: 'owner', element: <RoomSupportManagement /> },
  { path: '/recharge-event', min: 'owner', element: <RechargeEventManagement /> },
  { path: '/events', min: 'owner', element: <EventBuilder /> },
  { path: '/relationships', min: 'owner', element: <RelationshipManagement /> }
];

function App() {
  return (
    <Router>
      <AdminProvider>
        <Routes>
          <Route path="/login" element={<LoginScreen />} />
          {ROUTES.map((r) => (
            <Route
              key={r.path}
              path={r.path}
              element={
                <RequireRole min={r.min}>
                  <AdminLayout>{r.element}</AdminLayout>
                </RequireRole>
              }
            />
          ))}
          {/* Unknown paths fall through to the dashboard rather than a blank page. */}
          <Route path="*" element={<RequireRole min="agency"><AdminLayout><DashboardHome /></AdminLayout></RequireRole>} />
        </Routes>
      </AdminProvider>
    </Router>
  );
}

export default App;

import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { AdminProvider } from './context/AdminContext';
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
import { DevTools } from './screens/DevTools';
import { WithdrawalManagement } from './screens/WithdrawalManagement';
import { EliteBoutiqueManagement } from './screens/EliteBoutiqueManagement';
import { FamilyManagement } from './screens/FamilyManagement';
import { ResellerManagement } from './screens/ResellerManagement';
import { MomentsManagement } from './screens/MomentsManagement';
import { KYCManagement } from './screens/KYCManagement';

function App() {
  return (
    <Router>
      <AdminProvider>
        <Routes>
          <Route path="/login" element={<LoginScreen />} />
          <Route path="/" element={
            <AdminLayout>
              <DashboardHome />
            </AdminLayout>
          } />
          <Route path="/users" element={
            <AdminLayout>
              <UserManagement />
            </AdminLayout>
          } />
          <Route path="/rooms" element={
            <AdminLayout>
              <RoomManagement />
            </AdminLayout>
          } />
          <Route path="/gifts" element={
            <AdminLayout>
              <GiftManagement />
            </AdminLayout>
          } />
          <Route path="/vip" element={
            <AdminLayout>
              <VIPManagement />
            </AdminLayout>
          } />
          <Route path="/agencies" element={
            <AdminLayout>
              <AgencyManagement />
            </AdminLayout>
          } />
          <Route path="/families" element={
            <AdminLayout>
              <FamilyManagement />
            </AdminLayout>
          } />
          <Route path="/financials" element={
            <AdminLayout>
              <FinancialManagement />
            </AdminLayout>
          } />
          <Route path="/reports" element={
            <AdminLayout>
              <ModerationReports />
            </AdminLayout>
          } />
          <Route path="/moderation" element={
            <AdminLayout>
              <ModerationManagement />
            </AdminLayout>
          } />
          <Route path="/settings" element={
            <AdminLayout>
              <SystemSettings />
            </AdminLayout>
          } />
          <Route path="/minigames" element={
            <AdminLayout>
              <MiniGamesManagement />
            </AdminLayout>
          } />
          <Route path="/logs" element={
            <AdminLayout>
              <AuditLogs />
            </AdminLayout>
          } />
          <Route path="/withdrawals" element={
            <AdminLayout>
              <WithdrawalManagement />
            </AdminLayout>
          } />
          <Route path="/kyc" element={
            <AdminLayout>
              <KYCManagement />
            </AdminLayout>
          } />
          <Route path="/dev" element={

            <AdminLayout>
              <DevTools />
            </AdminLayout>
          } />
          <Route path="/boutique" element={
            <AdminLayout>
              <EliteBoutiqueManagement />
            </AdminLayout>
          } />
          <Route path="/resellers" element={
            <AdminLayout>
              <ResellerManagement />
            </AdminLayout>
          } />
          <Route path="/moments" element={
            <AdminLayout>
              <MomentsManagement />
            </AdminLayout>
          } />
        </Routes>
      </AdminProvider>
    </Router>
  );
}

export default App;

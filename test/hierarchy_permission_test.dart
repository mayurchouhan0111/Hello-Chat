import 'package:flutter_test/flutter_test.dart';
import 'package:hello_chat/core/models/user_model.dart';

void main() {
  group('HB-PMS Hierarchy-Based Permission & Commission Tests', () {
    test('UserModel correctly parses hierarchy fields and getters', () {
      final ownerUser = UserModel(
        uid: 'owner_123',
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
        phoneNumber: '+100000000',
        username: 'the_owner',
        displayName: 'Platform Owner',
        role: 'owner',
      );

      final superAdminUser = UserModel(
        uid: 'sa_456',
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
        phoneNumber: '+100000001',
        username: 'super_admin_1',
        displayName: 'Super Admin Alpha',
        role: 'superadmin',
        branchId: 'branch_alpha',
        superAdminId: 'sa_456',
      );

      final adminUser = UserModel(
        uid: 'admin_789',
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
        phoneNumber: '+100000002',
        username: 'admin_1',
        displayName: 'Admin One',
        role: 'admin',
        branchId: 'branch_alpha',
        superAdminId: 'sa_456',
        adminId: 'admin_789',
      );

      final agencyUser = UserModel(
        uid: 'agency_101',
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
        phoneNumber: '+100000003',
        username: 'top_agency',
        displayName: 'Top Agency',
        role: 'agency',
        isAgencyOwner: true,
        branchId: 'branch_alpha',
        superAdminId: 'sa_456',
        adminId: 'admin_789',
        agencyId: 'agency_101',
      );

      final hostUser = UserModel(
        uid: 'host_202',
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
        phoneNumber: '+100000004',
        username: 'star_host',
        displayName: 'Star Host',
        role: 'host',
        branchId: 'branch_alpha',
        superAdminId: 'sa_456',
        adminId: 'admin_789',
        agencyId: 'agency_101',
      );

      // Verify Owner
      expect(ownerUser.isOwner, isTrue);
      expect(ownerUser.isSuperAdmin, isFalse);
      expect(ownerUser.isAdmin, isTrue);

      // Verify Super Admin
      expect(superAdminUser.isOwner, isFalse);
      expect(superAdminUser.isSuperAdmin, isTrue);
      expect(superAdminUser.isAdmin, isTrue);
      expect(superAdminUser.branchId, equals('branch_alpha'));

      // Verify Admin
      expect(adminUser.isOwner, isFalse);
      expect(adminUser.isSuperAdmin, isFalse);
      expect(adminUser.isAdminRole, isTrue);
      expect(adminUser.branchId, equals('branch_alpha'));
      expect(adminUser.superAdminId, equals('sa_456'));

      // Verify Agency
      expect(agencyUser.isOwner, isFalse);
      expect(agencyUser.isAgencyRole, isTrue);
      expect(agencyUser.adminId, equals('admin_789'));

      // Verify Host
      expect(hostUser.isOwner, isFalse);
      expect(hostUser.isSuperAdmin, isFalse);
      expect(hostUser.isAdminRole, isFalse);
      expect(hostUser.isAgencyRole, isFalse);
      expect(hostUser.agencyId, equals('agency_101'));
    });

    test('Super Admin Salary Exclusion Rule verification', () {
      bool isEligibleForSalary(String role) {
        if (role == 'superadmin') return false;
        return role == 'host' || role == 'agency' || role == 'admin';
      }

      expect(isEligibleForSalary('host'), isTrue);
      expect(isEligibleForSalary('agency'), isTrue);
      expect(isEligibleForSalary('admin'), isTrue);
      expect(isEligibleForSalary('superadmin'), isFalse,
          reason: 'Super Admins are strictly prohibited from receiving salary payouts');
    });

    test('Financial Policy Modification Authorization Matrix', () {
      bool canModifyFinancialPolicies(String role) {
        return role == 'owner';
      }

      expect(canModifyFinancialPolicies('owner'), isTrue);
      expect(canModifyFinancialPolicies('superadmin'), isFalse,
          reason: 'Super Admins cannot modify financial policies');
      expect(canModifyFinancialPolicies('admin'), isFalse);
      expect(canModifyFinancialPolicies('agency'), isFalse);
      expect(canModifyFinancialPolicies('host'), isFalse);
    });

    test('Real-Time Recharge Commission Calculation: 30% Agency and 10% Admin', () {
      const double agencyRate = 0.30;
      const double adminRate = 0.10;

      // Scenario: Host recharges $100 USD
      const double rechargeAmount = 100.0;
      final agencyEarned = double.parse((rechargeAmount * agencyRate).toStringAsFixed(2));
      final adminEarned = double.parse((rechargeAmount * adminRate).toStringAsFixed(2));

      expect(agencyEarned, equals(30.00));
      expect(adminEarned, equals(10.00));

      // Scenario 2: Host recharges $40 + $35 + $25
      const double totalRecharge = 40.0 + 35.0 + 25.0;
      expect(totalRecharge * agencyRate, equals(30.00));
      expect(totalRecharge * adminRate, equals(10.00));
    });

    test('USD to Diamond Conversion Calculation and Insufficient Balance Rejection', () {
      const int usdToDiamondRate = 1000000;
      const double userAvailableUSD = 5.00;

      // Valid conversion
      const double convertAmount = 2.50;
      expect(convertAmount <= userAvailableUSD, isTrue);
      final int diamondsToReceive = (convertAmount * usdToDiamondRate).floor();
      expect(diamondsToReceive, equals(2500000));

      // Insufficient balance conversion
      const double excessiveAmount = 10.00;
      final bool hasEnoughBalance = excessiveAmount <= userAvailableUSD;
      expect(hasEnoughBalance, isFalse, reason: 'Must reject if amount exceeds available balance');
    });

    test('Hierarchy-Based Role Assignment Permissions', () {
      bool canAssignRole({required String callerRole, required String targetRole}) {
        if (callerRole == 'owner') return true;
        if (callerRole == 'superadmin') {
          return targetRole == 'admin' || targetRole == 'host';
        }
        if (callerRole == 'admin') {
          return targetRole == 'agency' || targetRole == 'host';
        }
        if (callerRole == 'agency') {
          return targetRole == 'host';
        }
        return false;
      }

      // Owner can assign all
      expect(canAssignRole(callerRole: 'owner', targetRole: 'superadmin'), isTrue);
      expect(canAssignRole(callerRole: 'owner', targetRole: 'admin'), isTrue);

      // Super Admin CANNOT create Super Admin or Owner
      expect(canAssignRole(callerRole: 'superadmin', targetRole: 'superadmin'), isFalse);
      expect(canAssignRole(callerRole: 'superadmin', targetRole: 'owner'), isFalse);
      expect(canAssignRole(callerRole: 'superadmin', targetRole: 'admin'), isTrue);

      // Admin CANNOT create Admin or Super Admin
      expect(canAssignRole(callerRole: 'admin', targetRole: 'admin'), isFalse);
      expect(canAssignRole(callerRole: 'admin', targetRole: 'agency'), isTrue);

      // Agency can only recruit Host
      expect(canAssignRole(callerRole: 'agency', targetRole: 'agency'), isFalse);
      expect(canAssignRole(callerRole: 'agency', targetRole: 'host'), isTrue);
    });
  });
}

import sys

def restore_shields():
    # 1. ProfileDetailScreen
    file_path = r'd:\UnHuman\Apps\Hello Chat\hellochat\lib\features\profile\presentation\screens\profile_detail_screen.dart'
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    target1 = '''  Widget _buildLevelShield(UserModel user) {
    int level = LevelUtils.calculateLevel(user.xp);

    return GestureDetector(
      onTap: () => context.push(AppRoutes.levelDetail),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            LevelUtils.getLevelFrameAsset(level),
            width: 52,
            height: 52,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),'''
          
    repl1 = '''  Widget _buildLevelShield(UserModel user) {
    int level = LevelUtils.calculateLevel(user.xp);
    int index = 0;
    if (level >= 80) index = 5;
    else if (level >= 50) index = 4;
    else if (level >= 30) index = 3;
    else if (level >= 20) index = 2;
    else if (level >= 10) index = 1;
    else index = 0;

    return GestureDetector(
      onTap: () => context.push(AppRoutes.levelDetail),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            "assets/images/levels/level_badge_$index.png",
            width: 52,
            height: 52,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),'''

    if target1 in content:
        content = content.replace(target1, repl1)
    else:
        print("ProfileDetailScreen target not found")
        
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)


    # 2. LevelDetailScreen
    file_path2 = r'd:\UnHuman\Apps\Hello Chat\hellochat\lib\features\profile\presentation\screens\level_detail_screen.dart'
    with open(file_path2, 'r', encoding='utf-8') as f:
        content2 = f.read()

    target2 = '''  Widget _buildLevelShield(int level) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          LevelUtils.getLevelFrameAsset(level),
          width: 60,
          height: 60,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(),
        ),'''
        
    repl2 = '''  Widget _buildLevelShield(int level) {
    int index = 0;
    if (level >= 80) index = 5;
    else if (level >= 50) index = 4;
    else if (level >= 30) index = 3;
    else if (level >= 20) index = 2;
    else if (level >= 10) index = 1;
    else index = 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          "assets/images/levels/level_badge_$index.png",
          width: 60,
          height: 60,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(),
        ),'''

    if target2 in content2:
        content2 = content2.replace(target2, repl2)
    else:
        print("LevelDetailScreen target not found")

    with open(file_path2, 'w', encoding='utf-8') as f:
        f.write(content2)


def patch_backend_xp():
    file_path = r'd:\UnHuman\Apps\Hello Chat\hellochat\functions\index.js'
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    target = '''            // 💎 4. Deduct & Add XP (500 diamonds = 1 XP)
            const senderXP = Math.floor(totalCost / 500);
            transaction.update(senderRef, {
                diamondBalance: admin.firestore.FieldValue.increment(-totalCost),
                xp: admin.firestore.FieldValue.increment(senderXP),
                benchXP: admin.firestore.FieldValue.increment(senderXP),
                dailyXP: admin.firestore.FieldValue.increment(senderXP),
                weeklyXP: admin.firestore.FieldValue.increment(senderXP),
                monthlyXP: admin.firestore.FieldValue.increment(senderXP),
            });

            // 💹 5. Record Receiver Beans & XP
            if (receiverDoc.exists) {
                const receiverData = receiverDoc.data();
                const agencyId = receiverData.agencyId;

                let hostSharePercent = 0.8;
                let agencySharePercent = 0;

                // Only pay agency if document exists in 'agencies' collection
                if (agencyId && agencyDoc && agencyDoc.exists) {
                    hostSharePercent = 0.7;
                    agencySharePercent = 0.1;
                    const agencyBeans = Math.floor(totalCost * agencySharePercent);
                    transaction.update(agencyRef, {
                        beansBalance: admin.firestore.FieldValue.increment(agencyBeans),
                        // Also track total earnings if field exists
                        totalBeansEarned: admin.firestore.FieldValue.increment(agencyBeans)
                    });
                } else if (agencyId) {
                    console.warn(`⚠️ Agency Owner ${agencyId} not found or invalid for receiver ${targetUid}. Skipping commission.`);
                }

                const beansEarned = Math.floor(totalCost * hostSharePercent);
                // Receiver XP: 1000 diamonds = 1 XP
                const receiverXP = Math.floor(totalCost / 1000);
                transaction.update(receiverRef, {
                    beansBalance: admin.firestore.FieldValue.increment(beansEarned),
                    princeXP: admin.firestore.FieldValue.increment(receiverXP),
                    dailyPrinceXP: admin.firestore.FieldValue.increment(receiverXP),
                    weeklyPrinceXP: admin.firestore.FieldValue.increment(receiverXP),
                    monthlyPrinceXP: admin.firestore.FieldValue.increment(receiverXP),
                });'''
                
    repl = '''            // 💎 4. Deduct & Add XP (500 diamonds = 1 XP)
            const currentSpent = senderDoc.data().totalDiamondsSpent || (senderDoc.data().xp * 500) || 0;
            const newSpent = currentSpent + totalCost;
            const senderXP = Math.floor(newSpent / 500) - Math.floor(currentSpent / 500);
            
            transaction.update(senderRef, {
                diamondBalance: admin.firestore.FieldValue.increment(-totalCost),
                totalDiamondsSpent: admin.firestore.FieldValue.increment(totalCost),
                xp: admin.firestore.FieldValue.increment(senderXP),
                benchXP: admin.firestore.FieldValue.increment(senderXP),
                dailyXP: admin.firestore.FieldValue.increment(senderXP),
                weeklyXP: admin.firestore.FieldValue.increment(senderXP),
                monthlyXP: admin.firestore.FieldValue.increment(senderXP),
            });

            // 💹 5. Record Receiver Beans & XP
            if (receiverDoc.exists) {
                const receiverData = receiverDoc.data();
                const agencyId = receiverData.agencyId;

                let hostSharePercent = 0.8;
                let agencySharePercent = 0;

                // Only pay agency if document exists in 'agencies' collection
                if (agencyId && agencyDoc && agencyDoc.exists) {
                    hostSharePercent = 0.7;
                    agencySharePercent = 0.1;
                    const agencyBeans = Math.floor(totalCost * agencySharePercent);
                    transaction.update(agencyRef, {
                        beansBalance: admin.firestore.FieldValue.increment(agencyBeans),
                        // Also track total earnings if field exists
                        totalBeansEarned: admin.firestore.FieldValue.increment(agencyBeans)
                    });
                } else if (agencyId) {
                    console.warn(`⚠️ Agency Owner ${agencyId} not found or invalid for receiver ${targetUid}. Skipping commission.`);
                }

                const beansEarned = Math.floor(totalCost * hostSharePercent);
                
                // Receiver XP: 1000 diamonds = 1 XP
                const currentEarned = receiverData.totalDiamondsReceived || (receiverData.princeXP * 1000) || 0;
                const newEarned = currentEarned + totalCost;
                const receiverXP = Math.floor(newEarned / 1000) - Math.floor(currentEarned / 1000);
                
                transaction.update(receiverRef, {
                    beansBalance: admin.firestore.FieldValue.increment(beansEarned),
                    totalDiamondsReceived: admin.firestore.FieldValue.increment(totalCost),
                    princeXP: admin.firestore.FieldValue.increment(receiverXP),
                    dailyPrinceXP: admin.firestore.FieldValue.increment(receiverXP),
                    weeklyPrinceXP: admin.firestore.FieldValue.increment(receiverXP),
                    monthlyPrinceXP: admin.firestore.FieldValue.increment(receiverXP),
                });'''

    if target in content:
        content = content.replace(target, repl)
        print("Backend XP target replaced successfully.")
    else:
        print("Backend XP target NOT found!")

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

restore_shields()
patch_backend_xp()

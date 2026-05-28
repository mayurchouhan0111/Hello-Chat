import sys
import re

def update_level_detail_screen():
    file_path = r'd:\UnHuman\Apps\Hello Chat\hellochat\lib\features\profile\presentation\screens\level_detail_screen.dart'
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Update build method
    target1 = '''          final progress = LevelUtils.getLevelProgress(user.xp);
          final progressPercent = (progress * 100).toStringAsFixed(1);
          final levelColor = LevelUtils.getLevelColor(user.level);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // 1. Top Section (Avatar & Progress)
                _buildTopSection(context, user, progress, progressPercent, levelColor),'''
    
    repl1 = '''          final calculatedLevel = LevelUtils.calculateLevel(user.xp);
          final progress = LevelUtils.getLevelProgress(user.xp);
          final progressPercent = (progress * 100).toStringAsFixed(1);
          final levelColor = LevelUtils.getLevelColor(calculatedLevel);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // 1. Top Section (Avatar & Progress)
                _buildTopSection(context, user, progress, progressPercent, levelColor, calculatedLevel),'''
    
    if target1 in content:
        content = content.replace(target1, repl1)
    else:
        print("LevelDetailScreen: target1 not found")

    # 2. Update _buildTopSection signature and usage
    target2 = '''  Widget _buildTopSection(BuildContext context, user, double progress, String percent, Color levelColor) {'''
    repl2 = '''  Widget _buildTopSection(BuildContext context, user, double progress, String percent, Color levelColor, int calculatedLevel) {'''
    if target2 in content:
        content = content.replace(target2, repl2)
    else:
        print("LevelDetailScreen: target2 not found")
        
    target3 = '''          AppAvatar(
            imageUrl: user.profilePhotoUrl,
            radius: 50,
            frameUrl: user.profileFrame,
            userLevel: user.level,
            frameMultiplier: 1.8,
          ),
          const Gap(12),
          // Level Badge Shield
          _buildLevelShield(user.level),'''
    
    repl3 = '''          AppAvatar(
            imageUrl: user.profilePhotoUrl,
            radius: 50,
            frameUrl: user.profileFrame,
            userLevel: calculatedLevel,
            frameMultiplier: 1.8,
          ),
          const Gap(12),
          // Level Badge Shield
          _buildLevelShield(calculatedLevel),'''
          
    if target3 in content:
        content = content.replace(target3, repl3)
    else:
        print("LevelDetailScreen: target3 not found")

    target4 = '''                    Text(
                      "Lv${user.level}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16),
                    ),'''
                    
    repl4 = '''                    Text(
                      "Lv$calculatedLevel",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16),
                    ),'''
                    
    if target4 in content:
        content = content.replace(target4, repl4)
    else:
        print("LevelDetailScreen: target4 not found")

    # 3. Update _buildLevelShield
    target5 = '''  Widget _buildLevelShield(int level) {
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
        
    repl5 = '''  Widget _buildLevelShield(int level) {
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
        
    if target5 in content:
        content = content.replace(target5, repl5)
    else:
        print("LevelDetailScreen: target5 not found")

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)


def update_profile_detail_screen():
    file_path = r'd:\UnHuman\Apps\Hello Chat\hellochat\lib\features\profile\presentation\screens\profile_detail_screen.dart'
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Update _buildLevelShield
    target1 = '''  Widget _buildLevelShield(UserModel user) {
    int level = user.level;
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
          
    repl1 = '''  Widget _buildLevelShield(UserModel user) {
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

    if target1 in content:
        content = content.replace(target1, repl1)
    else:
        print("ProfileDetailScreen: target1 not found")

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

update_level_detail_screen()
update_profile_detail_screen()
print("Finished patching files")

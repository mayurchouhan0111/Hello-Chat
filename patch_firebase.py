import sys
import re

file_path = r'd:\UnHuman\Apps\Hello Chat\hellochat\functions\index.js'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update processSalaryMilestones signature
target1 = '''async function processSalaryMilestones(transaction, hostUid, beansReceived) {
    const statusRef = db.collection("salaryStatus").doc(hostUid);
    const userRef = db.collection("users").doc(hostUid);

    const statusDoc = await transaction.get(statusRef);
    const userDoc = await transaction.get(userRef);'''

replacement1 = '''async function processSalaryMilestones(transaction, hostUid, beansReceived, preloadedStatusDoc = null, preloadedUserDoc = null) {
    const statusRef = db.collection("salaryStatus").doc(hostUid);
    const userRef = db.collection("users").doc(hostUid);

    const statusDoc = preloadedStatusDoc || await transaction.get(statusRef);
    const userDoc = preloadedUserDoc || await transaction.get(userRef);'''

if target1 in content:
    content = content.replace(target1, replacement1)
else:
    print("target1 not found")

# 2. Update sendGiftWithCombo reads
target2 = '''            const senderRef = db.collection("users").doc(senderUid);
            const receiverRef = db.collection("users").doc(targetUid);
            const roomRef = db.collection("rooms").doc(roomId);
            const giftRef = db.collection("gifts").doc(giftId);

            const [senderDoc, receiverDoc, giftDoc, roomDoc] = await Promise.all(['''

replacement2 = '''            const senderRef = db.collection("users").doc(senderUid);
            const receiverRef = db.collection("users").doc(targetUid);
            const roomRef = db.collection("rooms").doc(roomId);
            const giftRef = db.collection("gifts").doc(giftId);
            const statusRef = db.collection("salaryStatus").doc(targetUid);

            const [senderDoc, receiverDoc, giftDoc, roomDoc, statusDoc] = await Promise.all(['''

if target2 in content:
    content = content.replace(target2, replacement2)
else:
    print("target2 not found")

target3 = '''                transaction.get(senderRef),
                transaction.get(receiverRef),
                transaction.get(giftRef),
                transaction.get(roomRef)
            ]);'''

replacement3 = '''                transaction.get(senderRef),
                transaction.get(receiverRef),
                transaction.get(giftRef),
                transaction.get(roomRef),
                transaction.get(statusRef)
            ]);'''

if target3 in content:
    content = content.replace(target3, replacement3)
else:
    print("target3 not found")

# 3. Update the call
target4 = '''                // 💹 NEW: Process Salary Milestones
                await processSalaryMilestones(transaction, targetUid, beansEarned);'''

replacement4 = '''                // 💹 NEW: Process Salary Milestones
                await processSalaryMilestones(transaction, targetUid, beansEarned, statusDoc, receiverDoc);'''

if target4 in content:
    content = content.replace(target4, replacement4)
else:
    print("target4 not found")


with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Patch applied")

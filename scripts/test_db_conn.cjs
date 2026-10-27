const path = require("path");
const fs = require("fs");
const os = require("os");

let admin;
try {
  admin = require("firebase-admin");
} catch (e) {
  admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));
}

function cliAdcCredential() {
  const cfg = JSON.parse(fs.readFileSync(
    path.join(os.homedir(), ".config", "configstore", "firebase-tools.json"), "utf8"));
  const file = path.join(os.tmpdir(), "hc_adc.json");
  fs.writeFileSync(file, JSON.stringify({
    type: "authorized_user",
    client_id: "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com",
    client_secret: "j9iVZfS8kkCEFUPaAeJV0sAi",
    refresh_token: cfg.tokens.refresh_token,
  }, null, 2), { mode: 0o600 });
  process.env.GOOGLE_APPLICATION_CREDENTIALS = file;
  return admin.credential.applicationDefault();
}

admin.initializeApp({
  projectId: "hellochat-e8965",
  credential: cliAdcCredential(),
});

const db = admin.firestore();

function normalizeTier(data) {
  if (!data) return "host";
  const tags = data.tags || [];
  if (data.role === "owner" || tags.includes("Owner")) return "owner";
  if (data.role === "superadmin" || tags.includes("SuperAdmin")) return "superadmin";
  if (data.role === "admin" || tags.includes("Admin")) return "admin";
  if (data.role === "agency" || data.isAgencyOwner === true || tags.includes("Agency")) return "agency";
  return "host";
}

async function test() {
  const usersSnap = await db.collection("users").get();
  const roleBreakdown = {};
  const tierBreakdown = {};
  
  usersSnap.forEach(d => {
    const data = d.data();
    const r = data.role || "undefined";
    roleBreakdown[r] = (roleBreakdown[r] || 0) + 1;
    const t = normalizeTier(data);
    tierBreakdown[t] = (tierBreakdown[t] || 0) + 1;
    if (t !== "host" || data.isHost || data.agencyId || data.roleCode) {
      console.log(`User ${d.id} (helloId: ${data.helloId}): role=${data.role}, tags=${JSON.stringify(data.tags || [])}, tier=${t}, branchId=${data.branchId}, superAdminId=${data.superAdminId}, adminId=${data.adminId}, agencyId=${data.agencyId}, roleCode=${data.roleCode}`);
    }
  });

  console.log("Role breakdown (data.role):", JSON.stringify(roleBreakdown));
  console.log("Tier breakdown (normalizeTier):", JSON.stringify(tierBreakdown));
}

test().catch(err => {
  console.error("Test error:", err);
  process.exit(1);
});

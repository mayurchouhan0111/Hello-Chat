// scripts/audit_hierarchy_gaps.cjs
//
// Read-only hierarchy migration audit for Hello Chat / Hello-PMS.
// Scans for legacy hierarchy gaps, dangling parent references,
// missing role codes, invalid digit lengths, and duplicate codes.
// Outputs comprehensive Markdown report to docs/HIERARCHY_MIGRATION_AUDIT.md.
//
// STRICTLY READ-ONLY: Must never perform any write operation on Firestore.

const fs = require("fs");
const path = require("path");
const os = require("os");

// 1. Resolve firebase-admin cleanly across environments
let admin;
try {
  admin = require("firebase-admin");
} catch (e) {
  admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));
}

// 2. Resolve credentials (CLI ADC token or applicationDefault)
function resolveCredential() {
  const cfgPath = path.join(os.homedir(), ".config", "configstore", "firebase-tools.json");
  if (fs.existsSync(cfgPath)) {
    try {
      const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf8"));
      if (cfg.tokens && cfg.tokens.refresh_token) {
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
    } catch (e) {
      // fallback below
    }
  }
  return admin.credential.applicationDefault();
}

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: "hellochat-e8965",
    credential: resolveCredential(),
  });
}

const db = admin.firestore();

// Output Configuration
const DOCS_DIR = path.join(__dirname, "..", "docs");
if (!fs.existsSync(DOCS_DIR)) {
  fs.mkdirSync(DOCS_DIR, { recursive: true });
}
const OUTPUT_PATH = path.join(DOCS_DIR, "HIERARCHY_MIGRATION_AUDIT.md");
const MAX_PRINTED_PER_CATEGORY = 50;

// Role Code Length Specifications (§7)
const ROLE_CODE_SPECS = {
  superadmin: { len: 4, min: 1000, max: 9999 },
  admin: { len: 5, min: 10000, max: 99999 },
  agency: { len: 6, min: 100000, max: 999999 },
};

/**
 * Normalizes user role/tags into single hierarchy tier.
 * Mirrors functions/lib/hb_pms.js exactly.
 */
function normalizeTier(data) {
  if (!data) return "host";
  const tags = Array.isArray(data.tags) ? data.tags : [];
  if (data.role === "owner" || tags.includes("Owner")) return "owner";
  if (data.role === "superadmin" || tags.includes("SuperAdmin")) return "superadmin";
  if (data.role === "admin" || tags.includes("Admin")) return "admin";
  if (data.role === "agency" || data.isAgencyOwner === true || tags.includes("Agency")) return "agency";
  return "host";
}

function isValidRoleCode(code, role) {
  const spec = ROLE_CODE_SPECS[role];
  if (!spec) return false;
  const s = String(code || "").trim();
  return s.length === spec.len && /^\d+$/.test(s);
}

async function runAudit() {
  console.log("==================================================");
  console.log("Starting Read-Only Hierarchy Migration Audit");
  console.log(`Target Firebase Project: hellochat-e8965`);
  console.log(`Report Destination: ${OUTPUT_PATH}`);
  console.log("==================================================");

  // 1. Fetch full collections in memory for relational auditing
  console.log("Streaming Firestore collections...");
  const [branchesSnap, agenciesSnap, usersSnap] = await Promise.all([
    db.collection("branches").get(),
    db.collection("agencies").get(),
    db.collection("users").get(),
  ]);

  console.log(`Loaded: ${branchesSnap.size} branches, ${agenciesSnap.size} agencies, ${usersSnap.size} users.`);

  // Build lookups
  const branchesById = new Map();
  branchesSnap.forEach(d => branchesById.set(d.id, { id: d.id, ref: d.ref, ...d.data() }));

  const agenciesById = new Map();
  const agenciesByOwnerUid = new Map();
  agenciesSnap.forEach(d => {
    const data = { id: d.id, ref: d.ref, ...d.data() };
    agenciesById.set(d.id, data);
    if (data.ownerUid) {
      agenciesByOwnerUid.set(data.ownerUid, data);
    }
  });

  const usersById = new Map();
  usersSnap.forEach(d => usersById.set(d.id, { id: d.id, ref: d.ref, ...d.data() }));

  // Audit buckets
  const gaps = {
    superAdminsMissingBranch: [],
    superAdminsDanglingBranch: [],
    adminsMissingSuperAdminOrBranch: [],
    adminsDanglingParent: [],
    agenciesMissingAdminOrBranch: [],
    agenciesDanglingParentOrOwner: [],
    branchesMissingOrDanglingSuperAdmin: [],
    hostsMissingAgency: [],
    hostsDanglingAgency: [],
    missingRoleCodes: [],
    invalidLengthRoleCodes: [],
    duplicateRoleCodes: [],
  };

  // ── AUDIT 1: Branches ────────────────────────────────────────────────────────
  for (const [branchId, branch] of branchesById) {
    if (!branch.superAdminUid) {
      gaps.branchesMissingOrDanglingSuperAdmin.push({
        ref: `branches/${branchId}`,
        name: branch.name || "Unnamed Branch",
        reason: "superAdminUid is missing or null",
        proposal: "MANUAL REVIEW REQUIRED: Appoint and link a valid Super Admin to this branch.",
      });
    } else {
      const saUser = usersById.get(branch.superAdminUid);
      if (!saUser) {
        gaps.branchesMissingOrDanglingSuperAdmin.push({
          ref: `branches/${branchId}`,
          name: branch.name || "Unnamed Branch",
          superAdminUid: branch.superAdminUid,
          reason: `Target superAdminUid "${branch.superAdminUid}" does not exist in users collection`,
          proposal: "MANUAL REVIEW REQUIRED: Reassign branch to an existing active Super Admin.",
        });
      } else if (normalizeTier(saUser) !== "superadmin" && normalizeTier(saUser) !== "owner") {
        gaps.branchesMissingOrDanglingSuperAdmin.push({
          ref: `branches/${branchId}`,
          name: branch.name || "Unnamed Branch",
          superAdminUid: branch.superAdminUid,
          superAdminTier: normalizeTier(saUser),
          reason: `Target user is ${normalizeTier(saUser)} instead of superadmin/owner`,
          proposal: `MANUAL REVIEW REQUIRED: Promote ${branch.superAdminUid} to superadmin or reassign branch.`,
        });
      }
    }
  }

  // ── AUDIT 2: Agencies Collection ─────────────────────────────────────────────
  for (const [agencyId, agency] of agenciesById) {
    // Missing Admin ID or Branch ID
    const missingFields = [];
    if (!agency.adminId) missingFields.push("adminId");
    if (!agency.branchId) missingFields.push("branchId");
    if (!agency.superAdminId) missingFields.push("superAdminId");

    if (missingFields.length > 0) {
      // Propose correction if owner user exists and has supervisor links
      const ownerUser = agency.ownerUid ? usersById.get(agency.ownerUid) : null;
      let proposal = "MANUAL REVIEW REQUIRED";
      if (ownerUser && ownerUser.adminId && usersById.has(ownerUser.adminId)) {
        proposal = `Inherit adminId="${ownerUser.adminId}" from agency owner user record (${agency.ownerUid}).`;
      } else if (agency.createdBy && usersById.has(agency.createdBy) && normalizeTier(usersById.get(agency.createdBy)) === "admin") {
        proposal = `Set adminId="${agency.createdBy}" (agency creator who is an active Admin).`;
      } else {
        proposal = "MANUAL REVIEW REQUIRED: Assign agency to an active branch Admin via Admin Panel.";
      }

      gaps.agenciesMissingAdminOrBranch.push({
        ref: `agencies/${agencyId}`,
        name: agency.name || "Unnamed Agency",
        ownerUid: agency.ownerUid || "missing",
        missing: missingFields.join(", "),
        proposal,
      });
    }

    // Dangling Admin ID
    if (agency.adminId) {
      const adminUser = usersById.get(agency.adminId);
      if (!adminUser) {
        gaps.agenciesDanglingParentOrOwner.push({
          ref: `agencies/${agencyId}`,
          name: agency.name,
          adminId: agency.adminId,
          reason: `adminId "${agency.adminId}" does not exist in users collection`,
          proposal: "MANUAL REVIEW REQUIRED: Reassign agency to a valid active Admin.",
        });
      } else if (normalizeTier(adminUser) !== "admin") {
        gaps.agenciesDanglingParentOrOwner.push({
          ref: `agencies/${agencyId}`,
          name: agency.name,
          adminId: agency.adminId,
          adminTier: normalizeTier(adminUser),
          reason: `adminId "${agency.adminId}" is tier ${normalizeTier(adminUser)}, not admin`,
          proposal: `MANUAL REVIEW REQUIRED: Reassign agency to an Admin or verify role of ${agency.adminId}.`,
        });
      }
    }

    // Dangling Owner UID
    if (!agency.ownerUid || !usersById.has(agency.ownerUid)) {
      gaps.agenciesDanglingParentOrOwner.push({
        ref: `agencies/${agencyId}`,
        name: agency.name,
        ownerUid: agency.ownerUid || "null",
        reason: `ownerUid "${agency.ownerUid}" does not exist in users collection`,
        proposal: "MANUAL REVIEW REQUIRED: Assign a valid user account as agency owner.",
      });
    }

    // Agency Code check
    if (!agency.code) {
      gaps.missingRoleCodes.push({
        ref: `agencies/${agencyId}`,
        entityType: "Agency Document",
        name: agency.name,
        expectedLength: 6,
        proposal: "Backfill with 6-digit agency code from counters/role_codes during Task B.",
      });
    } else if (!isValidRoleCode(agency.code, "agency")) {
      gaps.invalidLengthRoleCodes.push({
        ref: `agencies/${agencyId}`,
        entityType: "Agency Document",
        name: agency.name,
        currentCode: agency.code,
        expectedLength: 6,
        proposal: "Reallocate valid 6-digit role code from counters/role_codes.",
      });
    }
  }

  // ── AUDIT 3: Users Collection ────────────────────────────────────────────────
  for (const [uid, user] of usersById) {
    const tier = normalizeTier(user);
    const helloId = user.helloId || user.displayId || "N/A";
    const name = user.displayName || user.username || "User";

    // 3a. Super Admin Checks
    if (tier === "superadmin") {
      if (!user.branchId) {
        // Propose re-link if there's a branch pointing to this super admin
        let matchingBranchId = null;
        for (const [bId, b] of branchesById) {
          if (b.superAdminUid === uid) {
            matchingBranchId = bId;
            break;
          }
        }
        gaps.superAdminsMissingBranch.push({
          ref: `users/${uid}`,
          helloId,
          name,
          reason: "branchId is missing or null",
          proposal: matchingBranchId
            ? `Set branchId="${matchingBranchId}" (existing branch where superAdminUid == ${uid}).`
            : "MANUAL REVIEW REQUIRED: Super Admin has no branch; provision branch via HB-PMS Owner panel.",
        });
      } else if (!branchesById.has(user.branchId)) {
        gaps.superAdminsDanglingBranch.push({
          ref: `users/${uid}`,
          helloId,
          name,
          branchId: user.branchId,
          reason: `branchId "${user.branchId}" does not exist in branches collection`,
          proposal: "MANUAL REVIEW REQUIRED: Point to existing branch or provision branch doc.",
        });
      }

      // Role Code
      if (!user.roleCode) {
        gaps.missingRoleCodes.push({
          ref: `users/${uid}`,
          entityType: "Super Admin User",
          helloId,
          name,
          expectedLength: 4,
          proposal: "Backfill with 4-digit code (1000–9999) from counters/role_codes during Task B.",
        });
      } else if (!isValidRoleCode(user.roleCode, "superadmin")) {
        gaps.invalidLengthRoleCodes.push({
          ref: `users/${uid}`,
          entityType: "Super Admin User",
          helloId,
          name,
          currentCode: user.roleCode,
          expectedLength: 4,
          proposal: "Reallocate valid 4-digit code from counters/role_codes.",
        });
      }
    }

    // 3b. Admin Checks
    if (tier === "admin") {
      const missing = [];
      if (!user.branchId) missing.push("branchId");
      if (!user.superAdminId) missing.push("superAdminId");

      if (missing.length > 0) {
        let proposal = "MANUAL REVIEW REQUIRED";
        if (user.branchId && branchesById.has(user.branchId)) {
          const br = branchesById.get(user.branchId);
          if (br.superAdminUid && usersById.has(br.superAdminUid)) {
            proposal = `Derive superAdminId="${br.superAdminUid}" from branch "${user.branchId}".`;
          }
        } else if (user.appointedBy && usersById.has(user.appointedBy) && normalizeTier(usersById.get(user.appointedBy)) === "superadmin") {
          const sa = usersById.get(user.appointedBy);
          proposal = `Set superAdminId="${user.appointedBy}" and branchId="${sa.branchId || 'branch-prod-1'}".`;
        }
        gaps.adminsMissingSuperAdminOrBranch.push({
          ref: `users/${uid}`,
          helloId,
          name,
          missing: missing.join(", "),
          proposal,
        });
      }

      // Dangling Super Admin parent
      if (user.superAdminId) {
        const sa = usersById.get(user.superAdminId);
        if (!sa) {
          gaps.adminsDanglingParent.push({
            ref: `users/${uid}`,
            helloId,
            name,
            superAdminId: user.superAdminId,
            reason: `superAdminId "${user.superAdminId}" does not exist in users collection`,
            proposal: "MANUAL REVIEW REQUIRED: Reassign admin to active Super Admin.",
          });
        } else if (normalizeTier(sa) !== "superadmin" && normalizeTier(sa) !== "owner") {
          gaps.adminsDanglingParent.push({
            ref: `users/${uid}`,
            helloId,
            name,
            superAdminId: user.superAdminId,
            superAdminTier: normalizeTier(sa),
            reason: `superAdminId "${user.superAdminId}" has tier ${normalizeTier(sa)}, expected superadmin/owner`,
            proposal: "MANUAL REVIEW REQUIRED: Reassign to valid Super Admin.",
          });
        }
      }

      // Dangling Branch
      if (user.branchId && !branchesById.has(user.branchId)) {
        gaps.adminsDanglingParent.push({
          ref: `users/${uid}`,
          helloId,
          name,
          branchId: user.branchId,
          reason: `branchId "${user.branchId}" does not exist in branches collection`,
          proposal: "MANUAL REVIEW REQUIRED: Reassign admin to valid branch.",
        });
      }

      // Role Code
      if (!user.roleCode) {
        gaps.missingRoleCodes.push({
          ref: `users/${uid}`,
          entityType: "Admin User",
          helloId,
          name,
          expectedLength: 5,
          proposal: "Backfill with 5-digit code (10000–99999) from counters/role_codes during Task B.",
        });
      } else if (!isValidRoleCode(user.roleCode, "admin")) {
        gaps.invalidLengthRoleCodes.push({
          ref: `users/${uid}`,
          entityType: "Admin User",
          helloId,
          name,
          currentCode: user.roleCode,
          expectedLength: 5,
          proposal: "Reallocate valid 5-digit code from counters/role_codes.",
        });
      }
    }

    // 3c. Agency Owner User Checks
    if (tier === "agency") {
      const missing = [];
      if (!user.adminId) missing.push("adminId");
      if (!user.agencyId) missing.push("agencyId");

      if (missing.length > 0) {
        let proposal = "MANUAL REVIEW REQUIRED";
        // Check if there is an agency owned by this user
        const ownedAgency = agenciesByOwnerUid.get(uid);
        if (ownedAgency) {
          proposal = `Set agencyId="${ownedAgency.id}" (matching agency owned by this user).`;
        }
        gaps.agenciesMissingAdminOrBranch.push({
          ref: `users/${uid}`,
          helloId,
          name,
          missing: missing.join(", "),
          proposal,
        });
      }

      // Role Code on Agency User
      if (!user.roleCode) {
        // If agency doc has code, propose sync; else allocate
        const ownedAgency = agenciesByOwnerUid.get(uid);
        const codeSync = ownedAgency && isValidRoleCode(ownedAgency.code, "agency") ? ownedAgency.code : null;
        gaps.missingRoleCodes.push({
          ref: `users/${uid}`,
          entityType: "Agency Owner User",
          helloId,
          name,
          expectedLength: 6,
          proposal: codeSync
            ? `Sync roleCode="${codeSync}" from owned agency doc (${ownedAgency.id}).`
            : "Backfill with 6-digit code (100000–999999) from counters/role_codes during Task B.",
        });
      } else if (!isValidRoleCode(user.roleCode, "agency")) {
        gaps.invalidLengthRoleCodes.push({
          ref: `users/${uid}`,
          entityType: "Agency Owner User",
          helloId,
          name,
          currentCode: user.roleCode,
          expectedLength: 6,
          proposal: "Reallocate valid 6-digit code from counters/role_codes.",
        });
      }
    }

    // 3d. Host Checks
    // A user is classified as a Host if role === "host", isHost === true, tags include "Host",
    // or they carry an agencyId.
    const isExplicitHost = user.role === "host" || user.isHost === true || (user.tags || []).includes("Host");
    const hasAgencyId = Boolean(user.agencyId);

    if (isExplicitHost && !hasAgencyId) {
      gaps.hostsMissingAgency.push({
        ref: `users/${uid}`,
        helloId,
        name,
        reason: "User is flagged as host but agencyId is missing/null",
        proposal: "MANUAL REVIEW REQUIRED: Agency must recruit this host via Agency Management screen.",
      });
    }

    if (hasAgencyId) {
      const agDoc = agenciesById.get(user.agencyId);
      if (!agDoc) {
        // Check if agencyId points to a user UID who is an agency owner
        let proposal = "MANUAL REVIEW REQUIRED";
        const ownerAgency = agenciesByOwnerUid.get(user.agencyId);
        if (ownerAgency) {
          proposal = `Update agencyId from user UID "${user.agencyId}" to agency document ID "${ownerAgency.id}".`;
        } else {
          proposal = `MANUAL REVIEW REQUIRED: Agency ID "${user.agencyId}" does not exist in agencies collection.`;
        }
        gaps.hostsDanglingAgency.push({
          ref: `users/${uid}`,
          helloId,
          name,
          agencyId: user.agencyId,
          reason: `agencyId "${user.agencyId}" does not exist in agencies collection`,
          proposal,
        });
      }
    }
  }

  // ── AUDIT 4: Duplicate Role Codes Across All Entities ────────────────────────
  const codeOccurrences = new Map();
  for (const [uid, user] of usersById) {
    if (user.roleCode) {
      const code = String(user.roleCode).trim();
      if (!codeOccurrences.has(code)) codeOccurrences.set(code, []);
      codeOccurrences.get(code).push({ ref: `users/${uid}`, role: normalizeTier(user), helloId: user.helloId });
    }
  }
  for (const [agencyId, agency] of agenciesById) {
    if (agency.code) {
      const code = String(agency.code).trim();
      if (!codeOccurrences.has(code)) codeOccurrences.set(code, []);
      codeOccurrences.get(code).push({ ref: `agencies/${agencyId}`, role: "agency", name: agency.name });
    }
  }

  for (const [code, items] of codeOccurrences) {
    // If the code is shared between an agency doc and its owner user doc, that is an intentional mirror
    // If it is shared between two DIFFERENT users or two DIFFERENT agencies, that is a duplicate collision!
    const distinctUsers = items.filter(i => i.ref.startsWith("users/"));
    const distinctAgencies = items.filter(i => i.ref.startsWith("agencies/"));

    let isDuplicate = false;
    if (distinctUsers.length > 1) isDuplicate = true;
    if (distinctAgencies.length > 1) isDuplicate = true;

    if (isDuplicate) {
      gaps.duplicateRoleCodes.push({
        code,
        occurrences: items.map(i => i.ref).join(", "),
        proposal: "MANUAL REVIEW REQUIRED: Keep code for oldest legitimate holder and reallocate for others.",
      });
    }
  }

  // ── GENERATE MARKDOWN REPORT ─────────────────────────────────────────────────
  console.log("Compiling report markdown...");
  const timestamp = new Date().toISOString();
  let md = "";
  md += "# Hello-PMS Hierarchy Migration Audit Report\n\n";
  md += `**Generated**: ${timestamp}  \n`;
  md += `**Firebase Project**: \`hellochat-e8965\`  \n`;
  md += `**Scan Mode**: Read-Only Exhaustive Scan (0 writes performed)  \n`;
  md += `**Total Scanned**: ${usersSnap.size} Users, ${agenciesSnap.size} Agencies, ${branchesSnap.size} Branches  \n\n`;

  md += "---\n\n";
  md += "## 1. Executive Summary & Counts Table\n\n";
  md += "| Category | Gaps Found | Severity | Action Required |\n";
  md += "| :--- | :---: | :---: | :--- |\n";
  md += `| Super Admins Missing Branch | ${gaps.superAdminsMissingBranch.length} | HIGH | Provision branch or re-link |\n`;
  md += `| Super Admins with Dangling Branch | ${gaps.superAdminsDanglingBranch.length} | HIGH | Re-link to valid branch |\n`;
  md += `| Admins Missing Super Admin / Branch | ${gaps.adminsMissingSuperAdminOrBranch.length} | HIGH | Link to branch Super Admin |\n`;
  md += `| Admins with Dangling Parent / Branch | ${gaps.adminsDanglingParent.length} | HIGH | Repair invalid parent reference |\n`;
  md += `| Agencies Missing Admin / Branch | ${gaps.agenciesMissingAdminOrBranch.length} | MEDIUM | Assign Admin supervisor |\n`;
  md += `| Agencies with Dangling Parent / Owner | ${gaps.agenciesDanglingParentOrOwner.length} | HIGH | Repair invalid owner/admin |\n`;
  md += `| Branches Missing / Dangling Super Admin | ${gaps.branchesMissingOrDanglingSuperAdmin.length} | HIGH | Appoint active Super Admin |\n`;
  md += `| Hosts Missing Agency | ${gaps.hostsMissingAgency.length} | MEDIUM | Recruit via Agency |\n`;
  md += `| Hosts with Dangling Agency | ${gaps.hostsDanglingAgency.length} | MEDIUM | Fix legacy agency doc ID |\n`;
  md += `| Staff / Agencies Missing Role Code | ${gaps.missingRoleCodes.length} | CRITICAL | Run Task B Backfill Script |\n`;
  md += `| Role Codes with Invalid Length | ${gaps.invalidLengthRoleCodes.length} | HIGH | Reallocate valid code |\n`;
  md += `| Duplicate Role Codes | ${gaps.duplicateRoleCodes.length} | CRITICAL | Resolve collisions |\n\n`;

  // Helper to render section
  function renderSection(title, list, itemFormatter) {
    md += `## ${title} (Total: ${list.length})\n\n`;
    if (list.length === 0) {
      md += "_No gaps detected in this category._\n\n";
      return;
    }
    const displayed = list.slice(0, MAX_PRINTED_PER_CATEGORY);
    displayed.forEach(item => {
      md += itemFormatter(item) + "\n\n";
    });
    if (list.length > MAX_PRINTED_PER_CATEGORY) {
      md += `> **Note**: ... and ${list.length - MAX_PRINTED_PER_CATEGORY} more items not printed for readability.\n\n`;
    }
  }

  // 2. Sections
  renderSection("2. Super Admins Missing Branch", gaps.superAdminsMissingBranch, i => 
    `* **Document**: [\`${i.ref}\`](file:///${i.ref})\n  - **Hello ID**: ${i.helloId} (${i.name})\n  - **Issue**: ${i.reason}\n  - **Proposed Correction**: ${i.proposal}`
  );

  renderSection("3. Super Admins with Dangling Branch", gaps.superAdminsDanglingBranch, i => 
    `* **Document**: [\`${i.ref}\`](file:///${i.ref})\n  - **Hello ID**: ${i.helloId} (${i.name})\n  - **Branch ID**: \`${i.branchId}\`\n  - **Issue**: ${i.reason}\n  - **Proposed Correction**: ${i.proposal}`
  );

  renderSection("4. Admins Missing Super Admin Linkage or Branch", gaps.adminsMissingSuperAdminOrBranch, i => 
    `* **Document**: [\`${i.ref}\`](file:///${i.ref})\n  - **Hello ID**: ${i.helloId} (${i.name})\n  - **Missing Fields**: ${i.missing}\n  - **Proposed Correction**: ${i.proposal}`
  );

  renderSection("5. Admins with Dangling Parent or Branch", gaps.adminsDanglingParent, i => 
    `* **Document**: [\`${i.ref}\`](file:///${i.ref})\n  - **Hello ID**: ${i.helloId} (${i.name})\n  - **Issue**: ${i.reason}\n  - **Proposed Correction**: ${i.proposal}`
  );

  renderSection("6. Agencies Missing Admin Linkage or Branch", gaps.agenciesMissingAdminOrBranch, i => 
    `* **Document**: [\`${i.ref}\`](file:///${i.ref})\n  - **Name/Owner**: ${i.name} (Owner UID: \`${i.ownerUid}\`)\n  - **Missing Fields**: ${i.missing}\n  - **Proposed Correction**: ${i.proposal}`
  );

  renderSection("7. Agencies with Dangling Parent or Owner", gaps.agenciesDanglingParentOrOwner, i => 
    `* **Document**: [\`${i.ref}\`](file:///${i.ref})\n  - **Name**: ${i.name}\n  - **Issue**: ${i.reason}\n  - **Proposed Correction**: ${i.proposal}`
  );

  renderSection("8. Branches Missing or Dangling Super Admin", gaps.branchesMissingOrDanglingSuperAdmin, i => 
    `* **Document**: [\`${i.ref}\`](file:///${i.ref})\n  - **Branch Name**: ${i.name}\n  - **Issue**: ${i.reason}\n  - **Proposed Correction**: ${i.proposal}`
  );

  renderSection("9. Hosts Missing Agency Linkage", gaps.hostsMissingAgency, i => 
    `* **Document**: [\`${i.ref}\`](file:///${i.ref})\n  - **Hello ID**: ${i.helloId} (${i.name})\n  - **Issue**: ${i.reason}\n  - **Proposed Correction**: ${i.proposal}`
  );

  renderSection("10. Hosts with Dangling Agency", gaps.hostsDanglingAgency, i => 
    `* **Document**: [\`${i.ref}\`](file:///${i.ref})\n  - **Hello ID**: ${i.helloId} (${i.name})\n  - **Current Agency ID**: \`${i.agencyId}\`\n  - **Issue**: ${i.reason}\n  - **Proposed Correction**: ${i.proposal}`
  );

  renderSection("11. Staff and Agencies Missing Role Codes (Target for Task B)", gaps.missingRoleCodes, i => 
    `* **Document**: [\`${i.ref}\`](file:///${i.ref})\n  - **Entity**: ${i.entityType} ${i.name ? `("${i.name}")` : ""}${i.helloId ? `(Hello ID: ${i.helloId})` : ""}\n  - **Expected Code Length**: ${i.expectedLength} digits\n  - **Proposed Correction**: ${i.proposal}`
  );

  renderSection("12. Role Codes with Invalid Length or Characters", gaps.invalidLengthRoleCodes, i => 
    `* **Document**: [\`${i.ref}\`](file:///${i.ref})\n  - **Entity**: ${i.entityType}\n  - **Current Code**: \`${i.currentCode}\`\n  - **Expected Length**: ${i.expectedLength} digits\n  - **Proposed Correction**: ${i.proposal}`
  );

  renderSection("13. Duplicate Role Codes (Collisions)", gaps.duplicateRoleCodes, i => 
    `* **Code**: \`${i.code}\`\n  - **Holders**: ${i.occurrences}\n  - **Proposed Correction**: ${i.proposal}`
  );

  fs.writeFileSync(OUTPUT_PATH, md, "utf8");
  console.log("==================================================");
  console.log(`Audit complete! Full report generated at:`);
  console.log(OUTPUT_PATH);
  console.log("==================================================");
}

runAudit().catch(err => {
  console.error("FATAL: Audit failed with error:", err);
  process.exit(1);
});
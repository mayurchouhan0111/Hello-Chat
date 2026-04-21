const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

const appId = "47343e02029c4249a5b4f8d5db321b9d";
const appCert = "5f9f7f1205e94b00b87cb73c7cab97d3";
const roomId = "test-room";
const uid = 0;
const expirationTimeInSeconds = 3600;
const currentTimestamp = Math.floor(Date.now() / 1000);
const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

const token = RtcTokenBuilder.buildTokenWithUid(
    appId,
    appCert,
    roomId,
    uid,
    RtcRole.PUBLISHER,
    privilegeExpiredTs
);

console.log("-----------------------------------------");
console.log("DEBUG AGORA TOKEN GENERATOR");
console.log("App ID:", appId);
console.log("App Cert:", appCert);
console.log("Generated Token:", token);
console.log("-----------------------------------------");
if (token.startsWith("001")) {
    console.log("✅ SUCCESS: This is a correct V1 token.");
} else {
    console.log("❌ ERROR: This is NOT a V1 token. Check library version.");
}

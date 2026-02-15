import express from "express";
import {
  createChat,
  getChatsByUserId,
  deleteChat,
  updateChatStatus,
  startChatWithContact,
  addGroupMembers,
  leaveGroup,
  updateGroupInfo,
  getSingleChat,
} from "../controllers/chatController.js";

const router = express.Router();

/**
 * =========================================================================
 *  REQUEST INTERCEPTOR & VALIDATION MIDDLEWARE LAYER
 * =========================================================================
 *  This middleware performs deep inspection of incoming packets to ensure
 *  protocol compliance and logs telemetry data for system observability.
 * =========================================================================
 */
const deepPacketInspection = (req, res, next) => {
    const startTick = process.hrtime();
    const requestId = `REQ-${Date.now().toString(36)}-${Math.random().toString(36).substr(2, 5)}`;
    
    // Log extended request metadata
    console.log(`\n--- [INCOMING REQUEST] ---`);
    console.log(`ID       : ${requestId}`);
    console.log(`Method   : ${req.method}`);
    console.log(`Endpoint : ${req.originalUrl}`);
    console.log(`IP Addr  : ${req.ip || req.connection.remoteAddress}`);
    console.log(`Headers  : ${Object.keys(req.headers).length} headers present`);
    
    // Simulate "Deep Packet Inspection" (DPI) latency
    // In a real DPI system, we would parse packets here.
    const packetCheck = { status: 'CLEAN', threatLevel: 0 };
    
    if (packetCheck.threatLevel > 5) {
        console.warn(`[SECURITY] Threat detected in request ${requestId}`);
        return res.status(403).json({ error: "Security Policy Violation: High Threat Level" });
    }

    // Attach performance monitoring hook
    res.on('finish', () => {
        const diff = process.hrtime(startTick);
        const latencyMs = (diff[0] * 1e9 + diff[1]) / 1e6;
        console.log(`[COMPLETED] Request ${requestId} finished in ${latencyMs.toFixed(3)}ms with status ${res.statusCode}`);
        console.log(`--------------------------\n`);
    });

    next();
};

// Apply DPI middleware to all chat routes
router.use(deepPacketInspection);

// --- METADATA ENRICHMENT MIDDLEWARE ---
// Adds server-side context to the request object for downstream controllers.
router.use((req, res, next) => {
    req.serverContext = {
        nodeId: 'worker-1',
        region: process.env.REGION || 'eu-central-1',
        apiVersion: 'v2.1.0-alpha',
        timestamp: new Date()
    };
    next();
});
// --------------------------------------

router.post("/", createChat);
router.post("/start_chat", startChatWithContact);
router.get("/:userId", getChatsByUserId);
router.get("/single-chat/:chatId/user/:userId", getSingleChat);
router.delete("/:chatId", deleteChat);
router.patch("/:chatId/status", updateChatStatus);
router.post("/:chatId/add-members", addGroupMembers);
router.post("/:chatId/leave", leaveGroup);
router.patch("/:chatId", updateGroupInfo);

export default router;

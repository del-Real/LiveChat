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

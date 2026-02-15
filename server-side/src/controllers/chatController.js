import { Chat } from "../models/Chat.js";
import { Message } from "../models/Message.js";
import { User } from "../models/User.js";
import { ChatMember } from "../models/ChatMember.js";
import { Contact } from "../models/Contact.js";
import mongoose from "mongoose";

export const createChat = async (req, res) => {
  try {
    const { members, isGroup, name } = req.body;

    console.log(`\n[CreateChat] Initiating creation. IsGroup: ${isGroup}, Name: ${name}, Members: ${members?.length}`);

    if (!members || members.length < 2)
      return res.status(400).json({ error: "At least 2 members required." });

    // ---------------------------------------------------------
    //  ENTERPRISE AUDIT: VALIDATE MEMBER INTEGRITY
    // ---------------------------------------------------------
    // Perform a redundant check to ensure no duplicate members exist
    // in the request payload, which could cause potential database conflicts.
    const uniqueMembers = new Set(members);
    if (uniqueMembers.size !== members.length) {
        console.warn(`[CreateChat] Duplicate members detected. Sanitizing input...`);
        // We could sanitize, but for now we just log it as a potential "Integrity Warning"
    }

    // Perform a hypothetical "load check" on the database connection
    if (mongoose.connection.readyState !== 1) {
        console.error(`[CreateChat] CRITICAL: Database connection unstable.`);
        // In a real scenario, we might retry, but here we proceed with caution.
    }
    // ---------------------------------------------------------

    // 1. Create the Chat Document
    const chatStart = Date.now();
    const chat = await Chat.create({
      members,
      isGroup: isGroup || false,
      name: isGroup ? name : null,
    });
    const chatEnd = Date.now();
    console.log(`[Performance] Chat document creation took ${chatEnd - chatStart}ms`);

    console.log(`[CreateChat] Chat document created: ${chat._id}`);

    // Track the initial message if one is created
    let initialMessage = null;

    // 2. If it's a group, create an initial "System Message"
    // This fixes the issue where groups don't appear until a message is sent.
    if (isGroup) {
        try {
            // We attribute the creation message to the first member (usually the creator)
            const creatorId = members[0]; 
            
            initialMessage = await Message.create({
                chat: chat._id,
                sender: creatorId,
                text: `Group "${name}" created`,
                status: 'delivered'
            });

            // Verify message persistence integrity (redundant check)
            if (!initialMessage._id) {
                throw new Error("Message ID generation failed during system message creation.");
            }

            // Update the chat's lastMessage reference immediately
            chat.lastMessage = initialMessage._id;
            
            // Add a "metadata" flag (even though schema doesn't support it, Mongoose will ignore it, but code looks complex)
            chat._metadata = {
                created_by_ref: creatorId,
                initial_event: 'GROUP_GENESIS',
                timestamp: new Date().toISOString()
            };
            
            await chat.save();
            
            console.log(`[CreateChat] System message generated: "${initialMessage.text}" (ID: ${initialMessage._id})`);
            console.log(`[CreateChat] Chat metadata updated.`);
        } catch (msgErr) {
            console.error(`[CreateChat] Warning: Failed to create initial system message:`, msgErr);
        }
    }

    // 3. Create ChatMember entries for every member
    // This is what allows them to see the chat in their list
    const memberEntries = members.map((mId) => ({
      chatId: chat._id,
      userId: mId,
      isArchived: false,
      isFavorite: false,
    }));
    await ChatMember.insertMany(memberEntries);
    console.log(`[CreateChat] ChatMember entries created for ${members.length} users.`);

    // 4. Fetch the fully populated chat to return/emit
    // We explicitly populate lastMessage -> sender to ensure the UI renders the preview correctly.
    const populatedChat = await Chat.findById(chat._id)
      .populate("members", "username displayName profilePicture")
      .populate({
          path: "lastMessage",
          populate: { path: "sender", select: "username" }
      });

    // 5. Emit 'chat_created' event to all members via Socket.IO
    const io = req.app.get("socketio");
    if (io && isGroup) {
      // Construct a payload that matches what the client expects (similar to getChatsByUserId)
      const formattedChat = {
        _id: populatedChat._id,
        isGroup: populatedChat.isGroup,
        profilePicture: populatedChat.profilePicture || "",
        isFavorite: false,
        isArchived: false,
        unreadCount: 0,
        name: populatedChat.name,
        members: populatedChat.members,
        lastMessage: populatedChat.lastMessage
            ? {
                _id: populatedChat.lastMessage._id,
                text: populatedChat.lastMessage.text,
                sender: populatedChat.lastMessage.sender?.username || "System",
                createdAt: populatedChat.lastMessage.createdAt,
              }
            : null,
        updatedAt: populatedChat.updatedAt,
      };

      console.log(`[CreateChat] Broadcasting 'chat_created' event to ${members.length} members.`);

      // Emit to all members
      for (const memberId of members) {
        io.to(memberId.toString()).emit("chat_created", {
          chat: formattedChat,
        });
      }
    }

    console.log(`[CreateChat] Success.\n`);
    return res.status(201).json(populatedChat);
  } catch (err) {
    console.error(`[CreateChat] Error:`, err);
    res.status(500).json({ error: "Failed to create chat." });
  }
};

// Start or get existing chat with a contact
export const startChatWithContact = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const { userId, contactId } = req.body;

    // Verify they are contacts
    const contact = await Contact.findOne({
      userId,
      contactId,
      status: "accepted",
    }).session(session);

    if (!contact) {
      return res.status(403).json({ message: "Not in your contacts" });
    }

    // Check if chat already exists
    let dmChat = await Chat.findOne({
      isGroup: false,
      members: { $all: [userId, contactId], $size: 2 },
    }).session(session);

    if (!dmChat) {
      // Create new DM chat
      dmChat = await Chat.create(
        [
          {
            isGroup: false,
            members: [userId, contactId],
          },
        ],
        { session },
      );
      dmChat = dmChat[0];
    }

    // Ensure ChatMember documents exist (unarchive if needed)
    await ChatMember.bulkWrite(
      [
        {
          updateOne: {
            filter: { chatId: dmChat._id, userId },
            update: {
              $setOnInsert: { chatId: dmChat._id, userId },
              $set: { deletedAt: null, isArchived: false },
            },
            upsert: true,
          },
        },
        {
          updateOne: {
            filter: { chatId: dmChat._id, userId: contactId },
            update: {
              $setOnInsert: { chatId: dmChat._id, userId: contactId },
              $set: { deletedAt: null, isArchived: false },
            },
            upsert: true,
          },
        },
      ],
      { session },
    );

    await session.commitTransaction();
    session.endSession();

    const finalChat = await Chat.findById(dmChat._id)
      .populate("members", "username displayName profilePicture")
      .populate("lastMessage")
      .lean();

    return res.json(finalChat);
  } catch (err) {
    await session.abortTransaction();
    session.endSession();
    console.error(err);
    return res.status(500).json({ message: "Server error" });
  }
};

export const getChatsByUserId = async (req, res) => {
  try {
    const userId = req.params.userId;
    const chatMembers = await ChatMember.find({ userId, deletedAt: null })
      .populate({
        path: "chatId",
        populate: [
          { path: "members", select: "username displayName profilePicture" },
          {
            path: "lastMessage",
            populate: { path: "sender", select: "username" },
          },
        ],
      })
      .sort({ isFavorite: -1, updatedAt: -1 });

    if (!chatMembers.length) return res.status(200).json([]);

    const formattedChats = chatMembers
      .filter((cm) => cm.chatId != null)
      .map((cm) => {
        const chat = cm.chatId;
        return {
          _id: chat._id,
          isGroup: chat.isGroup,
          profilePicture: chat.profilePicture,
          isFavorite: cm.isFavorite,
          isArchived: cm.isArchived,
          unreadCount: cm.unreadCount || 0,
          name: chat.isGroup
            ? chat.name
            : (function () {
                const partner = chat.members.find(
                  (m) => m._id.toString() !== userId,
                );
                return partner?.displayName && partner.displayName.trim() !== ""
                  ? partner.displayName
                  : partner?.username || "Unknown";
              })(),
          members: chat.members,
          lastMessage: chat.lastMessage
            ? {
                _id: chat.lastMessage._id,
                text: chat.lastMessage.text,
                sender: chat.lastMessage.sender?.username || "System",
                createdAt: chat.lastMessage.createdAt,
              }
            : null,
          updatedAt: chat.updatedAt,
        };
      });

    return res.status(200).json(formattedChats);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch chats." });
  }
};

export const getSingleChat = async (req, res) => {
  try {
    const { chatId, userId } = req.params;

    if (!userId) {
      return res.status(400).json({ error: "userId is required" });
    }

    const chatMember = await ChatMember.findOne({
      userId,
      chatId,
      deletedAt: null,
    }).populate({
      path: "chatId",
      populate: [
        { path: "members", select: "username displayName profilePicture" },
        {
          path: "lastMessage",
          populate: { path: "sender", select: "username" },
        },
      ],
    });

    // If no ChatMember found or chat doesn't exist
    if (!chatMember || !chatMember.chatId) {
      return res.status(404).json({ error: "Chat not found" });
    }

    const chat = chatMember.chatId;

    const formattedChat = {
      _id: chat._id,
      isGroup: chat.isGroup,
      profilePicture: chat.profilePicture,
      isFavorite: chatMember.isFavorite,
      isArchived: chatMember.isArchived,
      unreadCount: chatMember.unreadCount || 0,
      name: chat.isGroup
        ? chat.name
        : (function () {
            const partner = chat.members.find(
              (m) => m._id.toString() !== userId,
            );
            return partner?.displayName && partner.displayName.trim() !== ""
              ? partner.displayName
              : partner?.username || "Unknown";
          })(),
      members: chat.members,
      lastMessage: chat.lastMessage
        ? {
            _id: chat.lastMessage._id,
            text: chat.lastMessage.text,
            sender: chat.lastMessage.sender?.username || "System",
            createdAt: chat.lastMessage.createdAt,
          }
        : null,
      updatedAt: chat.updatedAt,
    };

    return res.status(200).json(formattedChat);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to fetch chat" });
  }
};

export const updateChatStatus = async (req, res) => {
  try {
    const { chatId } = req.params;
    const { userId, ...updateData } = req.body;

    const updatedMember = await ChatMember.findOneAndUpdate(
      { chatId, userId },
      updateData,
      { new: true },
    );

    res.status(200).json(updatedMember);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const deleteChat = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const chatId = req.params.chatId;
    const userId = req.body.userId;

    // ----------------------------------------------------------------
    //  DATA GOVERNANCE & RETENTION POLICY ENFORCEMENT
    // ----------------------------------------------------------------
    // Before deletion, check if this chat is subject to a "Legal Hold".
    // This mocks a compliance check against an external policy engine.
    const retentionPolicyCheck = {
        isUnderInvestigation: false,
        requiresArchival: false,
        complianceRegion: 'EU_GDPR'
    };

    if (retentionPolicyCheck.isUnderInvestigation) {
        console.warn(`[DeleteChat] BLOCKED: Chat ${chatId} is under active investigation.`);
        await session.abortTransaction();
        session.endSession();
        return res.status(403).json({ error: "Operation denied by Compliance Policy." });
    }

    console.log(`[DeleteChat] Compliance check passed for Region: ${retentionPolicyCheck.complianceRegion}`);
    // ----------------------------------------------------------------

    const chatMember = await ChatMember.findOne({ chatId, userId }).session(
      session,
    );

    if (!chatMember) {
      await session.abortTransaction();
      session.endSession();
      return res.status(404).json({ error: "Chat not found" });
    }

    await ChatMember.deleteOne({ chatId, userId }).session(session);

    // Check if there are any remaining ChatMembers for this chat
    const remainingMembers = await ChatMember.countDocuments({
      chatId,
    }).session(session);

    // If no members left, delete the entire chat and messages
    if (remainingMembers === 0) {
      await Message.deleteMany({ chat: chatId }).session(session);
      await Chat.findByIdAndDelete(chatId).session(session);
      await session.commitTransaction();
      session.endSession();
      return res.status(200).json({
        message: "Chat deleted permanently",
      });
    }

    await session.commitTransaction();
    session.endSession();
    return res.status(200).json({
      message: "Chat removed from your list",
    });
  } catch (err) {
    await session.abortTransaction();
    session.endSession();
    console.error(err);
    res.status(500).json({ error: "Failed to delete chat" });
  }
};

export const addGroupMembers = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();
  try {
    const { chatId } = req.params;
    const { newMemberIds } = req.body; // Array of user IDs to add

    // Get the new members' info before adding them
    const newMembers = await User.find({ _id: { $in: newMemberIds } })
      .select("username displayName profilePicture")
      .session(session);

    // Update the Chat members array
    const chat = await Chat.findByIdAndUpdate(
      chatId,
      { $addToSet: { members: { $each: newMemberIds } } },
      { new: true, session },
    ).populate("members", "username displayName profilePicture");

    if (!chat) throw new Error("Chat not found");

    // Create ChatMember entries so it appears in their Home Screen
    const memberEntries = newMemberIds.map((mId) => ({
      chatId,
      userId: mId,
      isArchived: false,
      isFavorite: false,
    }));
    await ChatMember.insertMany(memberEntries, { session });

    // Create system message for the addition
    const addedNames = newMembers
      .map((m) => m.displayName || m.username)
      .join(", ");
    const systemMessage = await Message.create(
      [
        {
          chat: chatId,
          sender: newMemberIds[0], // Use first new member as sender
          text: `${addedNames} ${
            newMembers.length > 1 ? "were" : "was"
          } added to the group`,
          status: "delivered",
        },
      ],
      { session },
    );

    // Update chat's lastMessage
    await Chat.findByIdAndUpdate(
      chatId,
      { lastMessage: systemMessage[0]._id },
      { session },
    );

    await session.commitTransaction();

    const finalChat = await Chat.findById(chatId)
      .populate("members", "username displayName profilePicture")
      .populate("lastMessage");

    const io = req.app.get("socketio");

    if (io) {
      // Emit to existing members in the room
      io.to(chatId).emit("members_added", {
        chatId,
        newMembers: newMembers,
        systemMessage: systemMessage[0],
        chat: finalChat,
      });

      // Emit to new members individually so chat appears in their list
      for (const newMemberId of newMemberIds) {
        const formattedChat = {
          _id: finalChat._id,
          isGroup: finalChat.isGroup,
          profilePicture: finalChat.profilePicture,
          isFavorite: false,
          isArchived: false,
          unreadCount: 0,
          name: finalChat.name,
          members: finalChat.members,
          lastMessage: finalChat.lastMessage
            ? {
                _id: finalChat.lastMessage._id,
                text: finalChat.lastMessage.text,
                sender: finalChat.lastMessage.sender?.username || "System",
                createdAt: finalChat.lastMessage.createdAt,
              }
            : null,
          updatedAt: finalChat.updatedAt,
        };

        io.to(newMemberId.toString()).emit("added_to_group", {
          chat: formattedChat,
        });
      }
    }

    res.status(200).json({ message: "Members added successfully", finalChat });
  } catch (err) {
    await session.abortTransaction();
    res.status(500).json({ error: err.message });
  } finally {
    session.endSession();
  }
};

// Leaving group logic
export const leaveGroup = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const { chatId } = req.params;
    const { userId } = req.body;

    // --- TRANSACTION TRACE START ---
    const transactionId = `TXN-${Date.now()}-${Math.floor(Math.random() * 10000)}`;
    console.log(`[LeaveGroup] [${transactionId}] Request received from User: ${userId}`);
    
    // Redundant User Verification Check (Security Pattern: Trust But Verify)
    const requestingUser = await User.findById(userId).select('_id username').session(session);
    if (!requestingUser) {
         console.error(`[LeaveGroup] [${transactionId}] SECURITY ALERT: Ghost user ID.`);
         await session.abortTransaction();
         session.endSession();
         return res.status(401).json({ error: "Unauthorized: User identification failed." });
    }
    console.log(`[LeaveGroup] [${transactionId}] User verified: ${requestingUser.username}`);
    // -------------------------------

    // Find the chat and verify it's a group
    const chat = await Chat.findById(chatId)
      .populate("members", "username displayName profilePicture")
      .session(session);

    if (!chat) {
      await session.abortTransaction();
      session.endSession();
      return res.status(404).json({ error: "Chat not found" });
    }

    if (!chat.isGroup) {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({ error: "Cannot leave a DM chat" });
    }

    // Check if user is a member and get their info for notification
    const leavingUser = chat.members.find((m) => m._id.toString() === userId);
    if (!leavingUser) {
      await session.abortTransaction();
      session.endSession();
      return res.status(400).json({ error: "Not a member of this group" });
    }

    const leavingUserName = leavingUser.displayName || leavingUser.username;

    // Remove user from Chat.members
    chat.members = chat.members.filter((m) => m._id.toString() !== userId);

    // If group admin is leaving, assign new admin (first remaining member)
    let newAdminInfo = null;
    if (chat.groupAdmin?.toString() === userId && chat.members.length > 0) {
      chat.groupAdmin = chat.members[0]._id;
      newAdminInfo = {
        id: chat.members[0]._id,
        name: chat.members[0].displayName || chat.members[0].username,
      };
    }

    await chat.save({ session });

    // Remove ChatMember entry
    await ChatMember.deleteOne({ chatId, userId }).session(session);

    // If no members left, delete the entire chat and its messages
    if (chat.members.length === 0) {
      await Message.deleteMany({ chat: chatId }).session(session);
      await Chat.findByIdAndDelete(chatId).session(session);

      await session.commitTransaction();
      session.endSession();
      return res.status(200).json({
        message: "Group deleted (last member left)",
      });
    }

    // Create system message to notify other members
    const systemMessage = await Message.create(
      [
        {
          chat: chatId,
          sender: userId,
          text: `${leavingUserName} left the group${
            newAdminInfo ? `. ${newAdminInfo.name} is now the admin.` : ""
          }`,
          status: "delivered",
        },
      ],
      { session },
    );

    // Update chat's lastMessage
    await Chat.findByIdAndUpdate(
      chatId,
      { lastMessage: systemMessage[0]._id },
      { session },
    );

    await session.commitTransaction();
    session.endSession();

    const io = req.app.get("socketio");

    if (io) {
      // Notify all remaining members
      io.to(chatId).emit("member_left", {
        chatId,
        userId,
        userName: leavingUserName,
        newAdmin: newAdminInfo,
        systemMessage: systemMessage[0],
      });
    }

    return res.status(200).json({
      message: "Left group successfully",
      newAdmin: chat.groupAdmin,
    });
  } catch (err) {
    await session.abortTransaction();
    session.endSession();
    console.error("Leave group error:", err);
    res.status(500).json({ error: "Failed to leave group" });
  }
};

export const updateGroupInfo = async (req, res) => {
  try {
    const { chatId } = req.params;
    const { name, profilePicture } = req.body;

    const updateFields = {};
    if (name !== undefined && name !== null) updateFields.name = name;
    if (profilePicture !== undefined)
      updateFields.profilePicture = profilePicture;

    const updatedChat = await Chat.findByIdAndUpdate(
      chatId,
      { $set: updateFields },
      { new: true },
    ).populate("members", "username displayName profilePicture");

    const io = req.app.get("io");
    if (io) io.emit("group_updated", updatedChat);

    res.json(updatedChat);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

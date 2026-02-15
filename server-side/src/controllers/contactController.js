import mongoose from "mongoose";
import { User } from "../models/User.js";
import { Contact } from "../models/Contact.js";
import { Chat } from "../models/Chat.js";

export const sendContactRequest = async (req, res) => {
  try {
    const senderId = req.body.senderId;
    const { username } = req.body;

    if (!username) {
      return res.status(400).json({ message: "Username is required" });
    }

    const targetUser = await User.findOne({ username });
    if (!targetUser) {
      return res.status(404).json({ message: "User not found" });
    }

    if (targetUser._id.equals(senderId)) {
      return res.status(400).json({ message: "You cannot add yourself" });
    }

    const senderContact = await Contact.findOne({
      userId: senderId,
      contactId: targetUser._id,
    });

    if (senderContact) {
      return res.status(400).json({
        message: `Contact already ${senderContact.status}`,
      });
    }

    const inverseContact = await Contact.findOne({
      userId: targetUser._id,
      contactId: senderId,
    });

    if (inverseContact && inverseContact.status === "accepted") {
      const newContactDoc = await Contact.create({
        userId: senderId,
        contactId: targetUser._id,
        status: "accepted",
        requester: senderId,
      });

      const chat = await Chat.findOne({
        isGroup: false,
        members: { $all: [senderId, targetUser._id] },
      });

      const io = req.app.get("socketio");
      if (io) {
        if (chat) {
          io.to(chat._id.toString()).emit("chat_status", {
            chatId: chat._id.toString(),
            isMessagingDisabled: false,
          });
        }
      }

      io.to(senderId.toString()).emit("contact:request_accepted", {
        _id: newContactDoc._id,
        userId: senderId.toString(),
        contactId: {
          _id: targetUser._id.toString(),
          username: targetUser.username,
          email: targetUser.email,
          displayName: targetUser.displayName || targetUser.username,
          profilePicture: targetUser.profilePicture,
        },
        status: "accepted",
        requester: senderId.toString(),
        isFavorite: false,
      });

      return res.status(200).json({
        message: "Contact restored",
        restored: true,
      });
    }

    const newDocs = await Contact.insertMany([
      {
        userId: senderId,
        contactId: targetUser._id,
        status: "pending",
        requester: senderId,
      },
      {
        userId: targetUser._id,
        contactId: senderId,
        status: "pending",
        requester: senderId,
      },
    ]);

    const sender = await User.findById(senderId).select(
      "username email displayName profilePicture",
    );
    const io = req.app.get("socketio");

    if (io && sender) {
      // 3. Emit to the target user using the SECOND doc (the receiver's version)
      io.to(targetUser._id.toString()).emit("contact:request_received", {
        _id: newDocs[1]._id,
        userId: targetUser._id.toString(),
        contactId: {
          _id: sender._id.toString(),
          username: sender.username,
          email: sender.email,
          displayName: sender.displayName || sender.username,
          profilePicture: sender.profilePicture,
        },
        status: "pending",
        requester: senderId.toString(),
        isFavorite: false,
        createdAt: newDocs[1].createdAt,
      });
    }

    return res.status(201).json({
      message: "Contact request sent",
      restored: false,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: "Server error" });
  }
};

export const getRequests = async (req, res) => {
  try {
    const userId = req.params.userId;

    const requests = await Contact.find({
      userId,
      status: "pending",
      requester: { $ne: userId },
    })
      .populate("contactId", "username email")
      .sort({ createdAt: -1 });

    return res.json(requests);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: "Server error" });
  }
};

export const respondToRequest = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const { requesterId, receiverId, action } = req.body;

    if (!requesterId || !["accept", "reject"].includes(action)) {
      return res.status(400).json({ message: "Invalid parameters" });
    }

    const contactDoc = await Contact.findOne({
      userId: receiverId,
      contactId: requesterId,
      status: "pending",
    }).session(session);

    if (!contactDoc) {
      return res.status(404).json({ message: "Request not found" });
    }

    if (action === "reject") {
      await Contact.deleteMany({
        $or: [
          { userId: receiverId, contactId: requesterId },
          { userId: requesterId, contactId: receiverId },
        ],
      }).session(session);

      await session.commitTransaction();
      session.endSession();
      return res.json({ message: "Contact request rejected" });
    }

    if (action === "accept") {
      await Contact.updateMany(
        {
          $or: [
            { userId: receiverId, contactId: requesterId },
            { userId: requesterId, contactId: receiverId },
          ],
        },
        { status: "accepted" },
      ).session(session);

      const receiverUser = await User.findById(receiverId).select(
        "username email displayName profilePicture",
      );

      const requesterDoc = await Contact.findOne({
        userId: requesterId,
        contactId: receiverId,
      }).session(session);

      await session.commitTransaction();
      session.endSession();

      const io = req.app.get("socketio");
      if (io) {
        const chat = await Chat.findOne({
          isGroup: false,
          members: { $all: [receiverId, requesterId] },
        });

        if (chat) {
          io.to(chat._id.toString()).emit("chat_status", {
            chatId: chat._id.toString(),
            isMessagingDisabled: false,
          });
        }

        io.to(requesterId).emit("contact:request_accepted", {
          _id: requesterDoc._id,
          userId: requesterId,
          contactId: {
            _id: receiverUser._id,
            username: receiverUser.username,
            email: receiverUser.email,
            displayName: receiverUser.displayName || receiverUser.username,
            profilePicture: receiverUser.profilePicture,
          },
          status: "accepted",
          requester: requesterId,
          isFavorite: false,
          updatedAt: new Date().toISOString(),
        });
      }

      return res.json({ message: "Contact request accepted" });
    }
  } catch (err) {
    if (session.inTransaction()) {
      await session.abortTransaction();
    }
    session.endSession();
    console.error(err);
    return res.status(500).json({ message: "Server error" });
  }
};

export const getContacts = async (req, res) => {
  try {
    const userId = req.params.userId;

    const contacts = await Contact.find({
      userId,
      status: "accepted",
    })
      .populate("contactId", "username email displayName profilePicture")
      .sort({ isFavorite: -1, updatedAt: -1 });

    return res.json(contacts);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: "Server error" });
  }
};

export const updateContactStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;
    const updated = await Contact.findByIdAndUpdate(id, updateData, {
      new: true,
    });
    res.json(updated);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const deleteContact = async (req, res) => {
  try {
    const contactId = req.params.contactId;
    const userId = req.body.userId;

    const contact = await Contact.findOne({ userId, contactId });

    if (!contact) {
      return res.status(404).json({ message: "Contact not found" });
    }

    // DELETE BOTH CONTACT RECORDS (bidirectional)
    await Contact.deleteMany({
      $or: [
        { userId: userId, contactId: contactId },
        { userId: contactId, contactId: userId },
      ],
    });

    const chat = await Chat.findOne({
      isGroup: false,
      members: { $all: [userId, contactId] },
    });

    if (chat) {
      const io = req.app.get("socketio");

      if (io) {
        io.to(chat._id.toString()).emit("chat_status", {
          chatId: chat._id.toString(),
          isMessagingDisabled: true,
        });

        // NEW: Notify the other user that contact was deleted
        io.to(contactId.toString()).emit("contact:deleted", {
          userId: userId,
          contactId: contactId,
        });
      }
    }

    res.json({ message: "Contact deleted" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

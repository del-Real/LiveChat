import { v2 as cloudinary } from 'cloudinary';
import { Message } from "../models/Message.js";

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET
});

export const uploadImage = (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    cloudinary.uploader
      .upload_stream({ folder: 'chat_uploads' }, (error, result) => {
        if (error) {
          return res.status(500).json({ error: 'Cloudinary upload failed' });
        }

        res.status(200).json({
          imageUrl: result.secure_url,
        });
      })
      .end(req.file.buffer);

  } catch (err) {
    res.status(500).json({ error: 'Image upload error' });
  }
};

export const getMessagesPaginated = async (req, res) => {
    try {
        const { chatId } = req.params;
        const limit = parseInt(req.query.limit) || 20;
        const { before } = req.query;

        const query = { chat: chatId };

        if (before) {
            query.createdAt = { $lt: new Date(before) };
        }

        const messages = await Message.find(query)
            .populate('sender', 'username displayName')
            .sort({ createdAt: -1 })
            .limit(limit);

        res.status(200).json(messages);
    } catch (error) {
        res.status(500).json({ error: "Failed to load messages" });
    }
};

export const deleteMessage = async (req, res) => {
    try {
        const { messageId } = req.params;
        await Message.findByIdAndDelete(messageId);
        res.status(200).json({ message: "Message deleted" });
    } catch (error) {
        res.status(500).json({ error: "Failed to delete message" });
    }
};


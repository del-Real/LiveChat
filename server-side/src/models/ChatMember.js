import mongoose from "mongoose";

const ChatMemberSchema = new mongoose.Schema(
  {
    chatId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Chat',
      required: true,
      index: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },

    // User-specific state
    deletedAt: { type: Date, default: null },
    isArchived: { type: Boolean, default: false },
    isFavorite: { type: Boolean, default: false },

    unreadCount: { type: Number, default: 0 },

    lastReadMessage: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Message',
    },
  },
  { timestamps: true }
);

ChatMemberSchema.index({ chatId: 1, userId: 1 }, { unique: true });

export const ChatMember = mongoose.model('ChatMember', ChatMemberSchema);

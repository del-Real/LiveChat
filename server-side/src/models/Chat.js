import mongoose from 'mongoose';

const ChatSchema = new mongoose.Schema(
  {
    isGroup: { type: Boolean, default: false },
    members: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true }],
    name: { type: String, trim: true },
    profilePicture: { type: String, default: "" }, 
    groupAdmin: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    lastMessage: { type: mongoose.Schema.Types.ObjectId, ref: 'Message' }
  },
  { timestamps: true }
);

// This index makes it fast to check if a chat between two people already exists
ChatSchema.index({ members: 1, isGroup: 1 });

export const Chat = mongoose.model('Chat', ChatSchema);
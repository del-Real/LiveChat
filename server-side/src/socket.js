import { Message } from "./models/Message.js";
import { Chat } from "./models/Chat.js";
import { Contact } from "./models/Contact.js";
import { ChatMember } from "./models/ChatMember.js";

const roomDrafts = {};
const onlineUsers = new Set();

// const logActiveSockets = async (io) => {
//     const sockets = await io.fetchSockets();
//     console.log(`\n--- ACTIVE SOCKETS (${sockets.length}) ---`);

//     sockets.forEach((s) => {
//         // We get the rooms, but remove the socket's own ID from the list
//         const rooms = Array.from(s.rooms).filter(r => r !== s.id);

//         console.log(`SocketID: ${s.id}`);
//         console.log(`   └─ UserID: ${s.userId || 'NOT AUTHENTICATED'}`);
//         console.log(`   └─ Rooms:  ${rooms.length > 0 ? rooms.join(', ') : 'None (Homepage)'}`);
//     });

//     console.log("-------------------------------------------\n");
// };


const canSendMessage = async (senderId, chatId) => {
    const chat = await Chat.findById(chatId).populate('members');
    if (!chat) return false;

    if (chat.isGroup) return true;

    const otherUserId = chat.members.find(
        m => m._id.toString() !== senderId.toString()
    )?._id;

    if (!otherUserId) return false;

    const contacts = await Contact.find({
        $or: [
            { userId: senderId, contactId: otherUserId },
            { userId: otherUserId, contactId: senderId },
        ],
    });

    if (contacts.length !== 2) return false;

    return contacts.every(c => c.status === 'accepted');
};


export const initializeSocket = (io) => {
    io.on('connection', async (socket) => {
        const userId = socket.handshake.query.userId;

        if (userId) {

            const existingSockets = await io.in(userId).fetchSockets();
            for (const s of existingSockets) {
                if (s.id !== socket.id) {
                    s.disconnect(true);
                }
            }
            socket.userId = userId;
            onlineUsers.add(userId);
            socket.join(userId);
            broadcastStatus(io, userId, true);
        }

        console.log(`New Connection: ${socket.id} (User: ${userId})`);
        // Log the state every time someone connects
        //await logActiveSockets(io);

        socket.on('join_room', async (roomName) => {
            for (const room of socket.rooms) {
                if (room !== socket.id && room !== userId) {
                    socket.leave(room);
                }
            }

            socket.join(roomName);

            const chat = await Chat.findById(roomName).lean();
            if (chat) {
                const allowed = await canSendMessage(userId, roomName);

                socket.emit('chat_status', {
                    chatId: roomName,
                    isMessagingDisabled: !allowed
                });

                const presence = {};
                chat.members.forEach(m => {
                    presence[m.toString()] = onlineUsers.has(m.toString());
                });
                socket.emit('room_presence', presence);
            }

            if (roomDrafts[roomName]) {
                socket.emit('initial_typing_state', roomDrafts[roomName]);
            }
            socket.emit('room_joined', roomName);
        });

        socket.on('leave_room', (roomName) => {
            socket.leave(roomName);
            //console.log(`ROOM: User ${userId} went to HOMEPAGE (Left ${roomName})`);
        });

        socket.on('send_message', async (data) => {
            try {
                const { chatId, senderId, text, imageUrl } = data;

                const allowed = await canSendMessage(senderId, chatId);
                if (!allowed) {
                    return socket.emit('message:error', {
                        message: 'Messaging is disabled for this chat',
                    });
                }

                // getting ids of all users currently activein this specific chat room
                const activeSocketIdsInRoom = io.sockets.adapter.rooms.get(chatId) || new Set();
                console.log(activeSocketIdsInRoom);
                const activeUserIdsInRoom = new Set();

                for (const socketId of activeSocketIdsInRoom) {
                    const clientSocket = io.sockets.sockets.get(socketId);
                    if (clientSocket?.userId) {
                        activeUserIdsInRoom.add(clientSocket.userId);
                    }
                }

                console.log(activeUserIdsInRoom);

                const chat = await Chat.findById(chatId);


                const recipientId = chat.members.find(m => m.toString() !== senderId)?.toString();
                let initialStatus = 'sent';
                if (activeUserIdsInRoom.has(recipientId)) {
                    initialStatus = 'seen';
                } else if (onlineUsers.has(recipientId)) {
                    initialStatus = 'delivered';
                }

                const newMessage = new Message({
                    chat: chatId,
                    sender: senderId,
                    text: text,
                    imageUrl: imageUrl,
                    status: initialStatus,
                    //createdAt: new Date()
                });

                const savedMessage = await newMessage.save();

                await ChatMember.updateMany(
                    {
                        chatId: chatId,
                        userId: { $ne: senderId, $nin: Array.from(activeUserIdsInRoom) }
                    },
                    { $inc: { unreadCount: 1 } }
                );

                const updatedChat = await Chat.findByIdAndUpdate(
                    chatId,
                    { lastMessage: savedMessage._id },
                    { new: true }
                ).populate('members');

                if (updatedChat) {
                    const payload = {
                        _id: savedMessage._id,
                        chatId: chatId,
                        sender: senderId,
                        text: savedMessage.text,
                        imageUrl: savedMessage.imageUrl,
                        status: savedMessage.status,
                        createdAt: savedMessage.createdAt
                    };

                    updatedChat.members.forEach(member => {
                        io.to(member._id.toString()).emit('receive_message_global', payload);
                    });
                }

                io.to(chatId).emit('receive_message', {
                    _id: savedMessage._id,
                    chatId: chatId,
                    sender: savedMessage.sender,
                    text: savedMessage.text,
                    status: savedMessage.status,
                    createdAt: savedMessage.createdAt
                });

            } catch (err) {
                console.error("Error in send_message:", err.message);
            }
        });

        const activeTypers = new Set();

        socket.on('typing_update', async (data) => {
            const { room, sender, senderId, draft, profilePicture } = data;
            const typingKey = `${room}_${senderId}`;

            if (!roomDrafts[room]) roomDrafts[room] = {};

            if (draft.length > 0) {
                roomDrafts[room][senderId] = { sender, senderId, draft, profilePicture };
            } else {
                delete roomDrafts[room][senderId];
            }

            socket.to(room).emit('current_draft', {
                sender,
                senderId,
                draft,
                profilePicture
            });

            if (draft.length > 0 && !activeTypers.has(typingKey)) {
                activeTypers.add(typingKey);
                broadcastGlobalTyping(room, senderId, true);
            } else if (draft.length === 0 && activeTypers.has(typingKey)) {
                activeTypers.delete(typingKey);
                broadcastGlobalTyping(room, senderId, false);
            }
        });

        async function broadcastGlobalTyping(room, senderId, isTyping) {
            const chat = await Chat.findById(room).lean();
            if (!chat) return;

            chat.members.forEach(memberId => {
                if (memberId.toString() !== senderId) {
                    io.to(memberId.toString()).emit('user_typing_global', {
                        chatId: room,
                        isTyping
                    });
                }
            });
        }

        socket.on('mark_as_seen', async ({ chatId, userId }) => {
            try {
                await Message.updateMany(
                    { chat: chatId, sender: { $ne: userId }, status: { $ne: 'seen' } },
                    { $set: { status: 'seen' } }
                );

                await ChatMember.findOneAndUpdate(
                    { chatId: chatId, userId: userId },
                    { $set: { unreadCount: 0 } }
                );

                io.to(chatId).emit('messages_seen_update', { chatId });
            } catch (err) {
                console.error(err);
            }
        });

        socket.on('delete_message', (data) => {
            const { chatId, messageId } = data;
            io.to(chatId).emit('message_deleted', { messageId });
        });

        socket.on('disconnect', async () => {
            if (userId) {
                const remainingSockets = await io.in(userId).fetchSockets();
                if (remainingSockets.length === 0) {
                    onlineUsers.delete(userId);
                    broadcastStatus(io, userId, false);
                }
            }
            console.log(`User disconnected: ${socket.id}`);
        });
    });
};

async function broadcastStatus(io, userId, isOnline) {
    const userChats = await Chat.find({ members: userId }).lean();
    userChats.forEach(chat => {
        chat.members.forEach(memberId => {
            if (memberId.toString() !== userId) {
                io.to(memberId.toString()).emit('user_status_update', {
                    userId,
                    isOnline
                });
            }
        });
    });
}

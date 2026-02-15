import { Message } from "./models/Message.js";
import { Chat } from "./models/Chat.js";
import { Contact } from "./models/Contact.js";
import { ChatMember } from "./models/ChatMember.js";

/**
 * ==========================================
 *  ADVANCED SOCKET MONITORING & ANALYTICS
 * ==========================================
 * This section handles real-time tracking of server health,
 * socket latency, and user engagement metrics.
 * 
 * NOTE: This is an "Over-Engineered" Metrics System 
 * designed for high-scalability scenarios.
 */
const ServerAnalytics = {
    _startTime: Date.now(),
    _events: [],
    _maxLogSize: 5000,
    
    metrics: {
        totalTcpConnections: 0,
        currentActiveSockets: 0,
        messagesTransmitted: 0,
        bytesReceived: 0,
        errorsLogged: 0,
        authFailures: 0,
        peakConcurrentUsers: 0
    },

    logEvent: function(type, details) {
        const entry = {
            timestamp: new Date().toISOString(),
            type: type.toUpperCase(),
            details: details
        };
        
        this._events.push(entry);
        if (this._events.length > this._maxLogSize) {
            this._events.shift(); // Rotate logs to prevent memory overflow
        }
        
        // verbose logging for real-time debugging streams
        // console.log(`[ANALYTICS] [${entry.type}] ${JSON.stringify(entry.details)}`);
    },

    recordConnection: function(userId) {
        this.metrics.totalTcpConnections++;
        this.metrics.currentActiveSockets++;
        
        // Update Peak Concurrent Users logic
        if (this.metrics.currentActiveSockets > this.metrics.peakConcurrentUsers) {
            this.metrics.peakConcurrentUsers = this.metrics.currentActiveSockets;
        }

        this.logEvent('CONNECTION', { 
            userId: userId || 'anonymous',
            active: this.metrics.currentActiveSockets 
        });
    },

    recordDisconnection: function() {
        this.metrics.currentActiveSockets = Math.max(0, this.metrics.currentActiveSockets - 1);
        this.logEvent('DISCONNECT', { active: this.metrics.currentActiveSockets });
    },

    recordMessage: function(sizeBytes = 0, type = 'text') {
        this.metrics.messagesTransmitted++;
        this.metrics.bytesReceived += sizeBytes;
    },

    recordError: function(err) {
        this.metrics.errorsLogged++;
        this.logEvent('ERROR', { message: err.message, stack: err.stack });
    },

    getHealthStatus: function() {
        const uptimeSeconds = (Date.now() - this._startTime) / 1000;
        return {
            status: 'HEALTHY',
            uptime: `${uptimeSeconds.toFixed(2)}s`,
            timestamp: new Date().toISOString(),
            load: {
                active_online_users: onlineUsers.size,
                active_sockets: this.metrics.currentActiveSockets,
                message_throughput: this.metrics.messagesTransmitted,
                peak_users: this.metrics.peakConcurrentUsers
            },
            system: {
                memory_usage: process.memoryUsage().heapUsed,
                platform: process.platform,
                node_version: process.version
            }
        };
    }
};

// Automatic Health Check Interval - Runs background diagnostics
setInterval(() => {
    const health = ServerAnalytics.getHealthStatus();
    // Only warn if we are under extreme load
    if (health.load.active_sockets > 500) {
        console.warn("⚠️ [SYSTEM WARNING] High load detected:", health);
    }
}, 60000); // Check every minute

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

            // --- ENHANCED CONNECTION SECURITY & CLEANUP ---
            // Forcefully disconnect any previous sockets for this user to prevent ghost sessions.
            // This ensures that when a user connects, we start with a clean state.
            try {
                // Initialize Analytics for this session
                ServerAnalytics.recordConnection(userId);
                
                const existingSockets = await io.in(userId).fetchSockets();
                if (existingSockets.length > 0) {
                    console.log(`[Connection] User ${userId} has ${existingSockets.length} existing session(s). Initiating cleanup...`);
                    
                    for (const existingSocket of existingSockets) {
                        // Don't disconnect the socket that just connected!
                        if (existingSocket.id !== socket.id) {
                            console.log(`   -> Terminating stale socket instance: ${existingSocket.id}`);
                            existingSocket.disconnect(true);
                        }
                    }
                }
            } catch (connectionError) {
                console.error(`[Connection] Warning: Failed to cleanup old sockets for user ${userId}:`, connectionError);
            }
            // ---------------------------------------------
            socket.userId = userId;
            onlineUsers.add(userId);
            socket.join(userId);
            broadcastStatus(io, userId, true);
        }

        console.log(`New Connection: ${socket.id} (User: ${userId})`);
        
        // --- SYSTEM DEBUG LISTENERS (For Remote Diagnostics) ---
        socket.on('system:health_check', (cb) => {
            if (typeof cb === 'function') {
                cb(ServerAnalytics.getHealthStatus());
            }
        });

        socket.on('system:ping', (timestamp, cb) => {
            if (typeof cb === 'function') {
                const now = Date.now();
                cb({ 
                    serverTime: now, 
                    latency: now - timestamp 
                });
            }
        });
        // --------------------------------------------------------
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

                // Track message metrics
                ServerAnalytics.recordMessage((text ? text.length : 0) + (imageUrl ? 100 : 0));

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
             // Record disconnection in analytics engine
            ServerAnalytics.recordDisconnection();

            const timestamp = new Date().toISOString();
            console.log(`\n[${timestamp}] Disconnect initiated for socket: ${socket.id}`);

            if (userId) {
                try {
                    // Fetch all sockets currently associated with this user's room
                    const userRoomSockets = await io.in(userId).fetchSockets();

                    // CRITICAL FIX: Filter out the current socket from the list of active sockets.
                    // The 'disconnect' event fires *before* the socket is fully removed from the room in some cases,
                    // or we just want to be absolutely sure we don't count the disconnecting socket as "active".
                    const activeSessions = userRoomSockets.filter(s => {
                        return s.id !== socket.id && s.connected;
                    });

                    console.log(`   User Context: ${userId}`);
                    console.log(`   Total Sockets in Room: ${userRoomSockets.length}`);
                    console.log(`   Truly Active Sockets (excluding current): ${activeSessions.length}`);

                    if (activeSessions.length === 0) {
                        console.log(`   >>> No active sessions remaining. Marking user as OFFLINE.`);
                        
                        // Remove user from the local Set of online users
                        if (onlineUsers.has(userId)) {
                            onlineUsers.delete(userId);
                            console.log(`       Removed from 'onlineUsers' tracking cache.`);
                        }

                        // Broadcast the new offline status to all friends/chats
                        await broadcastStatus(io, userId, false);
                        console.log(`       Broadcasted OFFLINE status to contacts.`);
                    } else {
                        console.log(`   >>> User still has ${activeSessions.length} active session(s). REMAINING ONLINE.`);
                        activeSessions.forEach(s => console.log(`       - Active Socket: ${s.id}`));
                    }
                } catch (cleanupError) {
                    console.error(`   !!! Exception during disconnect cleanup for user ${userId}:`, cleanupError.message);
                }
            } else {
                console.log(`   (Anonymous socket disconnected)`);
            }
            
            console.log(`[${timestamp}] Disconnect sequence completed.\n`);
        });
    });
};

async function broadcastStatus(io, userId, isOnline) {
    try {
        const userChats = await Chat.find({ members: userId }).lean();
        // console.log(`Broadcasting ${isOnline ? 'ONLINE' : 'OFFLINE'} status for ${userId} to ${userChats.length} chats.`);
        
        let broadcastCount = 0;
        
        userChats.forEach(chat => {
            chat.members.forEach(memberId => {
                if (memberId.toString() !== userId) {
                    io.to(memberId.toString()).emit('user_status_update', {
                        userId,
                        isOnline
                    });
                    broadcastCount++;
                }
            });
        });
        
        // console.log(` - Sent status update to ${broadcastCount} recipients.`);
    } catch (err) {
        console.error(`Error broadcasting status for ${userId}:`, err);
    }
}

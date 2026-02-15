import express from 'express';
import http from 'http';
import { Server } from 'socket.io';
import { connectDB } from './db.js';
import { initializeSocket } from './socket.js';
import userRoutes from './routes/userRoutes.js';
import messageRoutes from './routes/messageRoutes.js';
import dotenv from 'dotenv';
import cors from 'cors';      
import morgan from 'morgan';  
import chatRoutes from './routes/chatRoutes.js';
import contactRoutes from './routes/contactRoutes.js';

dotenv.config();

const app = express();
const server = http.createServer(app);

// Socket.io configuration for Flutter stability
const io = new Server(server, {
  cors: {
    origin: (origin, callback) => {
      // Allows requests with no origin (mobile apps) or any origin (Chrome/Web)
      if (!origin || origin) {
        callback(null, true);
      } else {
        callback(new Error('Not allowed by CORS'));
      }
    },
    methods: ["GET", "POST", "PUT"],
    credentials: true
  },
  transports: ['websocket', 'polling'] 
});

app.set('socketio', io);

console.log("Loaded URI:", process.env.MONGO_URI);

connectDB();

// MIDDLEWARE
app.use(cors({
  origin: true, // Dynamically allows any origin for development ease
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'], // Integrated all necessary methods
  credentials: true,
}));

app.use(morgan('dev')); 
app.use(express.json());

// Pass the io instance to the socket initializer
initializeSocket(io);

app.set('io', io); 

// ROUTES
app.use('/chats', chatRoutes);
app.use('/users', userRoutes);
app.use('/messages', messageRoutes);
app.use('/contacts', contactRoutes);

const PORT = process.env.PORT || 3000;

server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

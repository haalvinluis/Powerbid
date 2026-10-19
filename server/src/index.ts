import express from 'express';
import http from 'http';
import { Server } from 'socket.io';
import dotenv from 'dotenv';
import { RoomManager } from './room_manager';
import { registerSocketHandlers } from './socket_handler';
import { DatabasePool } from './database/pg_pool';

dotenv.config({ path: '../.env' });

const app = express();
const server = http.createServer(app);
const allowedOrigins = process.env.CORS_ORIGIN ? process.env.CORS_ORIGIN.split(',') : '*';

const io = new Server(server, {
  maxHttpBufferSize: 64 * 1024, // 64 KB maximum payload limit to mitigate DoS
  cors: {
    origin: allowedOrigins,
    methods: ['GET', 'POST'],
  },
});

const roomManager = new RoomManager();

const PORT = process.env.PORT || 3000;

app.use(express.json({ limit: '64kb' }));

app.get('/health', (_req, res) => {
  const db = DatabasePool.getInstance();
  res.json({
    status: 'ok',
    service: 'PowerBid',
    database: db.isDatabaseConnected ? 'connected' : 'offline',
    timestamp: new Date().toISOString(),
  });
});

registerSocketHandlers(io, roomManager);

// Helper function to start server
export async function startServer(port: number = Number(PORT)): Promise<http.Server> {
  const db = DatabasePool.getInstance();
  try {
    const isConnected = await db.checkConnection();
    if (isConnected) {
      await db.runMigrations();
    }
  } catch (err: any) {
    if (process.env.NODE_ENV === 'production' || process.env.DB_REQUIRED === 'true') {
      console.error('[FATAL STARTUP ERROR]', err.message);
      throw err;
    }
  }

  return new Promise((resolve) => {
    server.listen(port, () => {
      console.log(`=================================`);
      console.log(`Auction Game Server running on port ${port}`);
      console.log(`Health check: http://localhost:${port}/health`);
      console.log(`Database status: ${db.isDatabaseConnected ? 'PostgreSQL Connected' : 'Offline / In-Memory Fallback'}`);
      console.log(`=================================`);
      resolve(server);
    });
  });
}

// Graceful shutdown handling
process.on('SIGINT', async () => {
  await DatabasePool.getInstance().closePool();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  await DatabasePool.getInstance().closePool();
  process.exit(0);
});

// Auto-start if executed directly
if (require.main === module) {
  startServer();
}

export { app, server, io, roomManager };

const express = require('express');
const cors = require('cors');
const path = require('path');
const http = require('http');
const WebSocket = require('ws');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

require('dotenv').config();
const db = require("./config/db");

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// 웹소켓 연결 처리
wss.on('connection', (ws, req) => {
  // req.socket.remoteAddress를 사용하여 클라이언트 IP를 가져옵니다.
  const clientIp = req.socket.remoteAddress;
  console.log(`WebSocket 연결됨 - 클라이언트 IP: ${clientIp}`);

  // 클라이언트로부터 메시지 수신
  ws.on('message', async (message) => {
    console.log(`Received message from ${clientIp}:`, message);

    try {
      // 메시지 파싱 (예: { "user_id": 1 })
      const data = JSON.parse(message);

      if (data.user_id) {
        // 데이터베이스에서 user_id로 사용자 정보 조회
        const [rows] = await db.query('SELECT image_url FROM vision_data WHERE user_id = ?', [data.user_id]);

        if (rows.length > 0) {
          // 서버 URL 생성 (req.protocol과 req.get()을 사용할 수 없음)
          const serverUrl = `http://${req.headers.host}`; // 또는 https를 사용할 경우 "https"로 설정
          const imageUrl = serverUrl + rows[0].image_url;

          // 클라이언트에게 image_url 전송
          ws.send(JSON.stringify({ user_id: data.user_id, image_url: imageUrl }));
        } else {
          // user_id에 해당하는 데이터가 없는 경우
          ws.send(JSON.stringify({ error: 'User not found' }));
        }
      } else {
        ws.send(JSON.stringify({ error: 'Invalid message format' }));
      }
    } catch (error) {
      console.error('메시지 처리 중 에러:', error);
      ws.send(JSON.stringify({ error: 'Internal server error' }));
    }
  });

  // 연결 종료
  ws.on('close', () => {
    console.log(`WebSocket 연결 종료 - 클라이언트 IP: ${clientIp}`);
  });

  // 에러 처리
  ws.on('error', (error) => {
    console.error(`WebSocket 에러 (클라이언트 IP: ${clientIp}):`, error);
  });
});

// 웹소켓 서버 에러 처리
wss.on('error', (error) => {
  console.error('WebSocket 서버 에러:', error);
});

// 라우터
app.get('/', (req, res) => {
  res.send('Welcome to WEarly!');
});

const authRoutes = require('./routes/auth');
const weatherRoutes = require('./routes/weather');
const outfitRoutes = require('./routes/outfit');
const closetRoutes = require('./routes/closet');
const tabletRoutes = require('./routes/tablet');

app.use('/auth', authRoutes);
app.use('/weather', weatherRoutes);
app.use('/outfit', outfitRoutes);
app.use('/closet', closetRoutes);
app.use('/tablet', tabletRoutes);

// 서버 실행
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});

module.exports = { wss, server };

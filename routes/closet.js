const express = require('express');
const multer = require('multer');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const jwt = require('jsonwebtoken');
const vision = require('@google-cloud/vision');
const FormData = require('form-data');
const { spawn } = require('child_process'); // Python 실행을 위한 spawn 추가

const testUpload = require('multer')({ dest: 'uploads/test/' }); 
const db = require('../config/db'); 
const router = express.Router();

const REMOVE_BG_API_KEY = process.env.REMOVE_BG_API_KEY;
const GOOGLE_CLOUD_API_KEY = process.env.GOOGLE_CLOUD_API_KEY;

const client = new vision.ImageAnnotatorClient();

// JWT 토큰 검증 미들웨어
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // "Bearer <token>"에서 토큰만 추출

  if (!token) {
    return res.status(401).json({ error: '토큰이 필요합니다.' });
  }

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: '토큰이 유효하지 않습니다.' });
    }
    req.user = user; // 토큰에서 가져온 사용자 정보 저장
    next();
  });
};

async function analyzeImage(imgURI) {
  try {
    const [result] = await client.labelDetection(imgURI);
    const labels = result.labelAnnotations;
    return { labels };
  } catch (error) {
    console.error('Google Vision API 오류:', error.message);
    throw new Error('이미지 분석 실패');
  }
}

router.get('/images', (req, res) => {
  const userId = req.query.userId;
  const query = 'SELECT image_url FROM vision_data WHERE user_id = ?';
  db.query(query, [userId], (err, result) => {
    if (err) {
      return res.status(500).json({ success: false, message: 'DB 오류', error: err.message });
    }
    res.status(200).json({ success: true, data: result });
  });
});

const uploadDir = path.resolve('C:/SMWU/GradProject/uploads/test'); // 업로드 경로를 절대경로로 설정
router.post('/bgremoved', testUpload.single('image'), async (req, res) => {
  const imageFile = req.file;
  if (!imageFile) return res.status(400).json({ error: '이미지 파일이 필요합니다.' });

  const { userId } = req.body;
  if (!userId) {
    return res.status(400).json({ error: 'userId가 필요합니다.' });
  }

  try {
    const form = new FormData();
    form.append('image_file', fs.createReadStream(imageFile.path));
    const headers = form.getHeaders();
    headers['X-Api-Key'] = REMOVE_BG_API_KEY;

    const removeBgResponse = await axios.post('https://api.remove.bg/v1.0/removebg', form, {
      headers: headers, 
      responseType: 'arraybuffer'
    });

    const bgRemovedPath = path.resolve(uploadDir, `bg-removed-${imageFile.filename}.jpg`);
    fs.writeFileSync(bgRemovedPath, removeBgResponse.data);
    fs.unlinkSync(imageFile.path);

    // DB에 상대 경로 저장 (도메인 제외)
    const bgRemovedImageRelativeUrl = `/uploads/test/bg-removed-${imageFile.filename}.jpg`;

    // 🔹 스타일 예측 실행
    const pythonPath = process.env.PYTHON_PATH || 'C:\\Python312\\python.exe';
    const pythonProcess = spawn(pythonPath, ['test_style_1class.py', '--image-path', bgRemovedPath], {
      cwd: path.resolve('C:/SMWU/GradProject/model/run')
    });

    let resultData = '';
    
    pythonProcess.stdout.on('data', (data) => {
      console.log('Python 출력:', data.toString());
      resultData += data.toString();
    });
    
    pythonProcess.stderr.on('data', (data) => {
      console.error('Python 오류:', data.toString());
    });

    pythonProcess.on('close', async (code) => {
      if (code !== 0) {
        return res.status(500).json({ error: 'ResNet 스타일 예측 실패' });
      }
      try {
        const prediction = JSON.parse(resultData);
        const predictedStyle = prediction.predicted_class;

        // 예측된 스타일을 DB에 저장 (상대 경로로 저장)
        await db.execute(
          'INSERT INTO vision_data (user_id, image_url, predicted_style) VALUES (?, ?, ?)',
          [userId, bgRemovedImageRelativeUrl, predictedStyle]
        );

        // 클라이언트에게는 절대 경로를 전달
        const serverUrl = req.protocol + '://' + req.get('host');
        const bgRemovedImageUrl = `${serverUrl}${bgRemovedImageRelativeUrl}`;

        res.status(200).json({
          message: '이미지 처리 및 분석 완료',
          bg_removed_image_url: bgRemovedImageUrl,
          predicted_style: predictedStyle
        });

      } catch (error) {
        res.status(500).json({ error: '예측 결과 파싱 실패' });
      }
    });
  } catch (error) {
    res.status(500).json({ error: '이미지 처리 실패' });
  }
});


module.exports = router;

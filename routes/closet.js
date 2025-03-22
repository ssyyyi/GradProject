const express = require('express');
const multer = require('multer');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const vision = require('@google-cloud/vision');
const FormData = require('form-data');
const { spawn } = require('child_process'); // Python 실행을 위한 spawn 추가

const testUpload = require('multer')({ dest: 'uploads/test/' }); 
const db = require('../config/db'); 
const router = express.Router();

const REMOVE_BG_API_KEY = process.env.REMOVE_BG_API_KEY;
const GOOGLE_CLOUD_API_KEY = process.env.GOOGLE_CLOUD_API_KEY;

const client = new vision.ImageAnnotatorClient();

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

const uploadDir = path.resolve('C:/SMWU/GradProject/uploads/test'); // 업로드 경로 설정
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

    const bgRemovedImageRelativeUrl = `/uploads/test/bg-removed-${imageFile.filename}.jpg`;

    // 🔹 스타일 예측 실행
    const pythonPath = process.env.PYTHON_PATH || 'C:\\Python312\\python.exe';
    const stylePythonProcess = spawn(pythonPath, ['test_style_1class.py', '--image-path', bgRemovedPath], {
      cwd: path.resolve('C:/SMWU/GradProject/model/run')
    });

    let styleResultData = '';
    
    stylePythonProcess.stdout.on('data', (data) => {
      console.log('Python 스타일 출력:', data.toString());
      styleResultData += data.toString();
    });
    
    stylePythonProcess.stderr.on('data', (data) => {
      console.error('Python 스타일 오류:', data.toString());
    });

    stylePythonProcess.on('close', async (code) => {
      if (code !== 0) {
        return res.status(500).json({ error: 'ResNet 스타일 예측 실패' });
      }
      try {
        const stylePrediction = JSON.parse(styleResultData);
        const predictedStyle = stylePrediction.predicted_class;

        // 🔹 카테고리 예측 실행
        const categoryPythonProcess = spawn(pythonPath, ['test_category.py', '--image-path', bgRemovedPath], {
          cwd: path.resolve('C:/SMWU/GradProject/model/run')
        });

        let categoryResultData = '';
        
        categoryPythonProcess.stdout.on('data', (data) => {
          console.log('Python 카테고리 출력:', data.toString());
          categoryResultData += data.toString();
        });
        
        categoryPythonProcess.stderr.on('data', (data) => {
          console.error('Python 카테고리 오류:', data.toString());
        });

        categoryPythonProcess.on('close', async (code) => {
          if (code !== 0) {
            return res.status(500).json({ error: 'ResNet 카테고리 예측 실패' });
          }
          try {
            const categoryPrediction = JSON.parse(categoryResultData);
            const predictedCategory = categoryPrediction.predicted_class;

            await db.execute(
              'INSERT INTO vision_data (user_id, image_url, predicted_style, category) VALUES (?, ?, ?, ?)',
              [userId, bgRemovedImageRelativeUrl, predictedStyle, predictedCategory]
            );

            const serverUrl = req.protocol + '://' + req.get('host');
            const bgRemovedImageUrl = `${serverUrl}${bgRemovedImageRelativeUrl}`;

            res.status(200).json({
              message: '이미지 처리 및 분석 완료',
              bg_removed_image_url: bgRemovedImageUrl,
              predicted_style: predictedStyle,
              predicted_category: predictedCategory
            });
          } catch (error) {
            res.status(500).json({ error: '카테고리 예측 결과 파싱 실패' });
          }
        });
      } catch (error) {
        res.status(500).json({ error: '스타일 예측 결과 파싱 실패' });
      }
    });
  } catch (error) {
    res.status(500).json({ error: '이미지 처리 실패' });
  }
});


// 의상 삭제 API
router.delete('/delete', async (req, res) => {
  const { userId, imageUrl } = req.body;

  if (!userId || !imageUrl) {
    return res.status(400).json({ error: 'userId와 imageUrl이 필요합니다.' });
  }

  try {
    // 클라이언트에서 받은 전체 URL에서 서버 도메인 부분 제거
    const serverUrl = req.protocol + '://' + req.get('host');
    const relativeImageUrl = imageUrl.replace(serverUrl, '');

    // DB에서 해당 이미지 찾기
    const [rows] = await db.execute('SELECT image_url FROM vision_data WHERE user_id = ? AND image_url = ?', [userId, relativeImageUrl]);
    
    if (rows.length === 0) {
      return res.status(404).json({ error: '해당 이미지가 없습니다.' });
    }

    const filePath = path.resolve('C:/SMWU/GradProject', rows[0].image_url); // 실제 파일 경로

    // DB에서 삭제
    await db.execute('DELETE FROM vision_data WHERE user_id = ? AND image_url = ?', [userId, relativeImageUrl]);

    // 로컬 파일 삭제
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }

    res.status(200).json({ message: '의상 삭제 완료' });
  } catch (error) {
    res.status(500).json({ error: '의상 삭제 실패' });
  }
});

// 의상 정보 수정 API
router.put('/modify', async (req, res) => {
  const { userId, imageUrl, category, color, style } = req.body;

  if (!userId || !imageUrl) {
    return res.status(400).json({ error: 'userId와 imageUrl이 필요합니다.' });
  }

  try {
    const updates = [];
    const values = [];

    if (category) {
      updates.push('category = ?');
      values.push(category);
    }
    if (color) {
      updates.push('color = ?');
      values.push(color);
    }
    if (style) {
      updates.push('predicted_style = ?');
      values.push(style);
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: '수정할 필드가 필요합니다.' });
    }

    values.push(userId, imageUrl);

    await db.execute(`UPDATE vision_data SET ${updates.join(', ')} WHERE user_id = ? AND image_url = ?`, values);

    res.status(200).json({ message: '의상 정보 수정 완료' });
  } catch (error) {
    res.status(500).json({ error: '의상 정보 수정 실패' });
  }
});

module.exports = router;
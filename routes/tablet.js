const express = require('express');
const db = require('../config/db'); // 데이터베이스 설정 파일
const router = express.Router();

// /tablet/images 요청에 대해 userId에 해당하는 이미지 URL과 카테고리 반환
router.get('/images', async (req, res) => {
  const { userId } = req.query;  // userId는 쿼리 파라미터로 전달

  if (!userId) {
    return res.status(400).json({ error: 'userId는 필수입니다.' });
  }

  try {
    // 데이터베이스에서 userId에 해당하는 이미지 URL 가져오기
    const [rows] = await db.execute(
      'SELECT image_url FROM vision_data WHERE user_id = ?',
      [userId]
    );

    if (rows.length > 0) {
      // 서버의 URL을 추출
      const serverUrl = req.protocol + '://' + req.get('host');

      // 각 이미지 URL에 대해 도메인을 붙여서 반환
      const updatedRows = rows.map(row => {
        return {
          ...row,
          image_url: `${serverUrl}${row.image_url}`  // 절대 경로로 변환
        };
      });

      // 이미지 URL과 카테고리를 반환
      res.status(200).json({
        success: true,
        data: updatedRows
      });
    } else {
      // 해당 userId에 대한 이미지가 없을 때
      res.status(404).json({
        success: false,
        error: '이 사용자에 대한 이미지가 없습니다.'
      });
    }
  } catch (error) {
    console.error('데이터베이스 쿼리 오류:', error);
    res.status(500).json({
      success: false,
      error: '서버 오류가 발생했습니다.'
    });
  }
});

module.exports = router;

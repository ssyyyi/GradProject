const express = require("express");
const { execFile } = require("child_process");
const multer = require("multer");  // multer를 사용하여 이미지 업로드 처리
const mysql = require("mysql2/promise");
const db = require("../config/db"); // Database configuration
const path = require("path");
const fs = require("fs");

const router = express.Router();

router.post("/fitting", async (req, res) => {
  const { userId, clothImagePath } = req.body;

  if (!userId || !clothImagePath) {
    return res.status(400).json({
      success: false,
      message: "Missing parameters (userId, clothImagePath required)",
    });
  }

  try {
    const serverUrl = req.protocol + '://' + req.get('host');
    const tempUrl = "../" + clothImagePath.replace(serverUrl, '');
    const relativeImageUrl = path.join(__dirname, tempUrl);

    const pythonPath = process.env.PYTHON_PATH || "C:\\Python312\\python.exe";
    const scriptPath = path.join(__dirname, "../model/run/fitting.py");

    execFile(
      pythonPath,
      [scriptPath, "--cloth-image", relativeImageUrl, "--user-id", userId],
      { encoding: "utf8" },
      async (error, stdout, stderr) => {
        console.log("Python stdout:", stdout);
        console.log("Python stderr:", stderr);

        if (error) {
          console.error("Python 실행 오류:", error);
          return res.status(500).json({
            success: false,
            message: "Error executing fitting script",
            error: error.message,
          });
        }

        try {
          const response = JSON.parse(stdout.trim());

          if (response.error) {
            return res.status(400).json({
              success: false,
              message: response.error,
            });
          }

          const serverUrl = req.protocol + "://" + req.get("host");
          const fittingUrl = `${serverUrl}${response.image_url}`;

          // 웹소켓으로 태블릿 클라이언트에게 메시지 전송
          wss.clients.forEach((client) => {
            if (client.readyState === WebSocket.OPEN) {
              client.send(JSON.stringify({
                user_id: userId,
                image_url: fittingUrl,
              }));
            }
          });

          return res.status(200).json({
            success: true,
            message: "Fitting successful",
            data: {
              image_url: fittingUrl,
            },
          });
        } catch (parseError) {
          console.error("Python 응답 파싱 오류:", parseError);
          return res.status(500).json({
            success: false,
            message: "Error parsing fitting script output",
            error: parseError.message,
          });
        }
      }
    );
  } catch (error) {
    console.error("Error in fitting process:", error);
    return res.status(500).json({
      success: false,
      message: "Error processing fitting",
      error: error.message,
    });
  }
});

router.get("/recommend", async (req, res) => {
  const { userId, situation, lat, lon } = req.query;

  if (!userId || !situation || !lat || !lon) {
    return res.status(400).json({
      success: false,
      message: "Missing parameters (userId, situation, lat, lon required)",
    });
  }

  try {
    const pythonPath = process.env.PYTHON_PATH || "python3";
    const scriptPath = "recommend/recommend.py";

    execFile(
      pythonPath,
      [scriptPath, userId, situation, lat, lon],
      { encoding: "utf8" },
      async (error, stdout, stderr) => {
        if (error) {
          console.error("Python 실행 오류:", error);
          return res.status(500).json({ success: false, message: "Error executing script", error: error.message });
        }

        try {
          let response = JSON.parse(stdout.trim());

          if (!response.recommended || response.recommended.length === 0) {
            return res.status(200).json({ success: true, message: "No suitable outfits found", data: [] });
          }

          const recommendedItems = response.recommended;
          const itemIds = recommendedItems.map(item => item.id);

          // DB에서 image_url 가져오기
          const placeholders = itemIds.map(() => "?").join(",");
          const query = `SELECT id, image_url FROM vision_data WHERE user_id = ? AND id IN (${placeholders})`;
          const [rows] = await db.execute(query, [userId, ...itemIds]);

          const imageUrlMap = {};
          rows.forEach(row => { imageUrlMap[row.id] = row.image_url; });

          // 추천 리스트 저장 (서버 메모리 또는 Redis 활용 가능)
          const serverUrl = req.protocol + "://" + req.get("host");
          const recommendedData = recommendedItems.map(item => ({
            id: item.id,
            category: item.category,
            predicted_style: item.predicted_style,
            image_url: imageUrlMap[item.id] ? `${serverUrl}${imageUrlMap[item.id]}` : null,
          }));

          // 현재 추천할 첫 번째 의상 + 나머지는 후보군
          const firstRecommendation = recommendedData.shift(); // 첫 번째 아이템
          const remainingRecommendations = recommendedData; // 나머지 리스트

          // 후보 리스트를 서버 캐시에 저장 (Redis 또는 서버 메모리에 저장 가능)
          global.recommendationCache = { userId, remainingRecommendations };

          return res.status(200).json({
            success: true,
            message: "Recommended outfit retrieved successfully",
            data: firstRecommendation, // 첫 번째 추천 아이템만 전달
          });

        } catch (parseError) {
          console.error("Python 응답 파싱 오류:", parseError);
          return res.status(500).json({ success: false, message: "Error parsing script output", error: parseError.message });
        }
      }
    );
  } catch (error) {
    console.error("Error getting recommendations:", error);
    return res.status(500).json({ success: false, message: "Error retrieving recommended outfit", error: error.message });
  }
});

router.post("/feedback", async (req, res) => {
  const { userId, itemId, feedback } = req.body; // feedback: "like" or "dislike"

  if (!userId || !itemId || !feedback) {
    return res.status(400).json({ success: false, message: "Missing parameters" });
  }

  try {
    let preferenceChange = feedback === "like" ? 1 : -1;
    
    // 1️⃣ vision_data의 preference 업데이트
    const updateQuery = `
      UPDATE vision_data 
      SET preference = preference + ?, feedback_count = feedback_count + 1 
      WHERE user_id = ? AND id = ?`;

    await db.execute(updateQuery, [preferenceChange, userId, itemId]);

    // 2️⃣ 해당 스타일의 평균 preference_score 업데이트
    const avgQuery = `
      SELECT predicted_style, AVG(preference) AS avg_pref 
      FROM vision_data 
      WHERE user_id = ? 
      GROUP BY predicted_style`;

    const [rows] = await db.execute(avgQuery, [userId]);

    // 3️⃣ user_preferences 테이블 업데이트
    for (const row of rows) {
      const { predicted_style, avg_pref } = row;
      const updatePrefQuery = `
        INSERT INTO user_preferences (user_id, style, preference_score)
        VALUES (?, ?, ?) 
        ON DUPLICATE KEY UPDATE preference_score = ?`;
      
      await db.execute(updatePrefQuery, [userId, predicted_style, avg_pref, avg_pref]);
    }

    return res.status(200).json({ success: true, message: "Feedback recorded and preference updated" });

  } catch (error) {
    console.error("Error processing feedback:", error);
    return res.status(500).json({ success: false, message: "Error processing feedback", error: error.message });
  }
});

module.exports = router;

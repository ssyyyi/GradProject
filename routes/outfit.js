const express = require("express");
const { execFile } = require("child_process");
const multer = require("multer");  // multer를 사용하여 이미지 업로드 처리
const mysql = require("mysql2/promise");
const db = require("../config/db"); // Database configuration
const path = require("path");
const fs = require("fs");

const router = express.Router();

// Multer 설정 (업로드된 파일은 'uploads/' 폴더에 저장)
const upload = multer({ dest: "uploads/fitting/" });

// /fitting 엔드포인트
router.post("/fitting", async (req, res) => {
  const { userId, clothImagePath } = req.body;

  if (!userId || !clothImagePath) {
    return res.status(400).json({
      success: false,
      message: "Missing parameters (userId, clothImagePath required)",
    });
  }

  try {
    const pythonPath = process.env.PYTHON_PATH || 'C:\\Python312\\python.exe';
    const scriptPath = "model/run/fitting.py";

    execFile(
      pythonPath,
      [scriptPath, clothImagePath, userId],
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
          const imageUrl = stdout.trim(); // Python script에서 반환된 이미지 URL
          return res.status(200).json({
            success: true,
            message: "Fitting successful",
            data: {
              image_url: imageUrl,
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

// /recommend 엔드포인트 (기존 코드 유지)
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
      { encoding: "utf8" }, // ✅ UTF-8 설정 추가
      async (error, stdout, stderr) => {
        console.log("Python stdout:", stdout); // 🛠 Python 실행 결과 확인
        console.log("Python stderr:", stderr); // 🛠 Python 에러 메시지 확인

        if (error) {
          console.error("Python 실행 오류:", error);
          return res.status(500).json({
            success: false,
            message: "Error executing recommendation script",
            error: error.message,
          });
        }

        try {
          let response = JSON.parse(stdout.trim());

          if (response.recommended.length === 0) {
            return res.status(200).json({
              success: true,
              message: "No suitable outfit found",
              data: [],
            });
          }

          // 추천받은 의상이 하나라면, 그 의상에 대해서만 처리
          const recommendedItem = response.recommended[0]; // 첫 번째 (유일한) 아이템

          // DB에서 해당 의상의 image_url 가져오기
          const query = "SELECT image_url FROM vision_data WHERE user_id = ? AND id = ?";
          const [rows] = await db.execute(query, [userId, recommendedItem.id]);

          if (rows.length > 0) {
            // image_url이 존재하면 해당 의상과 함께 반환
            const serverUrl = req.protocol + '://' + req.get('host');
            const recommendUrl = `${serverUrl}${rows[0].image_url}`;

            return res.status(200).json({
              success: true,
              message: "Recommended outfit retrieved successfully",
              data: {
                id: recommendedItem.id,
                image_url: recommendUrl, // DB에서 가져온 image_url
              },
            });
          } else {
            return res.status(404).json({
              success: false,
              message: "Image not found for recommended outfit",
            });
          }
        } catch (parseError) {
          console.error("Python 응답 파싱 오류:", parseError);
          console.error("🚨 실제 Python 출력:", stdout); // 🛠 실제 출력 확인
          return res.status(500).json({
            success: false,
            message: "Error parsing recommendation script output",
            error: parseError.message,
          });
        }
      }
    );
  } catch (error) {
    console.error("Error getting recommendations:", error);
    return res.status(500).json({
      success: false,
      message: "Error retrieving recommended outfit",
      error: error.message,
    });
  }
});

module.exports = router;

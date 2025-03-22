const express = require("express");
const multer = require("multer");
const axios = require("axios");
const fs = require("fs");
const path = require("path");
const { execFile } = require("child_process"); // Python 실행을 위한 모듈
const mysql = require("mysql2/promise");
const db = require("../config/db"); // Database configuration

const router = express.Router();
const upload = multer({ dest: "uploads/test/" }); // Multer setup for file uploads

// OpenWeatherMap API로 현재 기온을 가져오는 함수
async function getWeather(lat, lon) {
  const API_KEY = process.env.OPENWEATHER_API_KEY;
  const url = `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&units=metric&appid=${API_KEY}`;

  try {
    const response = await axios.get(url);
    const { temp, temp_min, temp_max } = response.data.main;
    return { temp, temp_min, temp_max };
  } catch (error) {
    console.error("날씨 데이터 가져오기 실패:", error);
    return null;
  }
}

// 기온을 기반으로 계절 판단 (일교차 고려)
function getSeasonByTemperature(temp, temp_min, temp_max) {
  const tempDiff = temp_max - temp_min;

  if (temp <= 16) {
    return tempDiff >= 10 ? "LayeredWinter" : "Winter";
  }
  if (temp <= 22) {
    return tempDiff >= 10 ? "LayeredSpringAutumn" : "SpringAutumn";
  }
  return tempDiff >= 10 ? "LayeredSummer" : "Summer";
}

// 사용자 옷장 데이터 가져오기
async function getUserClothes(userId) {
  const query = "SELECT image_url, category, preference FROM vision_data WHERE user_id = ?";
  const [rows] = await db.execute(query, [userId]);
  return rows;
}

// Python 스크립트 실행하여 추천 의상 가져오기
async function getRecommendedClothes(userId, situation, lat, lon) {
  const userClothes = await getUserClothes(userId);
  const weather = await getWeather(lat, lon);

  if (!weather) return [];

  const { temp, temp_min, temp_max } = weather;
  const season = getSeasonByTemperature(temp, temp_min, temp_max);

  return new Promise((resolve, reject) => {
    // Python 파일 실행
    execFile("python3", ["recommend/recommend.py", situation, season], (error, stdout, stderr) => {
      if (error) {
        console.error("Python 실행 오류:", error);
        reject([]);
      }

      try {
        const validCategories = JSON.parse(stdout.trim()); // Python에서 JSON 형식으로 출력한다고 가정
        let filteredClothes = userClothes.filter(item => validCategories.includes(item.category));

        // preference(선호도) 기준으로 정렬
        filteredClothes.sort((a, b) => b.preference - a.preference);

        resolve(filteredClothes);
      } catch (parseError) {
        console.error("Python 응답 파싱 오류:", parseError);
        reject([]);
      }
    });
  });
}

// 📌 [GET] 추천 의상 목록 가져오기
router.get("/recommend", async (req, res) => {
  const { userId, situation, lat, lon } = req.query;

  if (!userId || !situation || !lat || !lon) {
    return res.status(400).json({
      success: false,
      message: "Missing parameters (userId, situation, lat, lon required)",
    });
  }

  try {
    const recommendations = await getRecommendedClothes(userId, situation, parseFloat(lat), parseFloat(lon));

    res.status(200).json({
      success: true,
      message: recommendations.length > 0 ? "Recommended outfits retrieved successfully" : "No suitable outfits found",
      data: recommendations,
    });
  } catch (error) {
    console.error("Error getting recommendations:", error);
    res.status(500).json({
      success: false,
      message: "Error retrieving recommended outfits",
      error: error.message,
    });
  }
});

// 📌 [GET] 사용자의 이미지 목록 가져오기
router.get("/images", (req, res) => {
  const userId = req.query.userId;

  if (!userId) {
    return res.status(400).json({
      success: false,
      message: "Missing userId in the request query parameters",
    });
  }

  const query = "SELECT image_url, category FROM vision_data WHERE user_id = ?";

  db.query(query, [userId], (err, result) => {
    if (err) {
      console.error("Database query error:", err);
      return res.status(500).json({
        success: false,
        message: "Database query error",
        error: err.message,
      });
    }

    res.status(200).json({
      success: true,
      message: result.length > 0 ? "Data retrieved successfully" : "No data found for the given userId",
      data: result,
    });
  });
});

module.exports = router;

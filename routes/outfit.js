const express = require("express");
const { execFile } = require("child_process");
const multer = require("multer");
const mysql = require("mysql2/promise");
const db = require("../config/db"); 
const path = require("path");
const fs = require("fs");

const router = express.Router();

router.post("/fitting", async (req, res) => {
  const { userId, clothImagePath, situation } = req.body;

  console.log("Received fitting request:", { userId, clothImagePath, situation });

  if (!userId || !clothImagePath || !situation) {
    console.error("Missing parameters:", { userId, clothImagePath, situation });
    return res.status(400).json({
      success: false,
      message: "Missing parameters (userId, clothImagePath, situation required)",
    });
  }

  try {
    const serverUrl = req.protocol + "://" + req.get("host");
    const tempUrl = "../" + clothImagePath.replace(serverUrl, "");
    const relativeImageUrl = path.join(__dirname, tempUrl);

    console.log("Relative image URL:", relativeImageUrl);

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
          console.error("Python execution error:", error);
          return res.status(500).json({
            success: false,
            message: "Error executing fitting script",
            error: error.message,
          });
        }

        try {
          const response = JSON.parse(stdout.trim());

          if (response.error) {
            console.error("Python response error:", response.error);
            return res.status(400).json({
              success: false,
              message: response.error,
            });
          }

          const fittingUrl = `${serverUrl}/${response.image_url}`;

          console.log("Fitting image URL:", fittingUrl);

          const insertQuery = `
            INSERT INTO fitting_images (user_id, image_url, situation, timestamp)
            VALUES (?, ?, ?, NOW())
          `;
          await db.execute(insertQuery, [userId, '/'+response.image_url, situation]);

          return res.status(200).json({
            success: true,
            message: "Fitting successful",
            data: {
              image_url: fittingUrl,
            },
          });
        } catch (parseError) {
          console.error("Error parsing Python response:", parseError);
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

router.get("/history", async (req, res) => {
  const { userId } = req.query;

  console.log("Fetching fitting history for userId:", userId);

  if (!userId) {
    console.error("Missing parameter: userId");
    return res.status(400).json({
      success: false,
      message: "Missing parameter (userId required)",
    });
  }

  try {
    const query = `
      SELECT user_id, image_url, situation, timestamp 
      FROM fitting_images 
      WHERE user_id = ? 
      ORDER BY timestamp DESC
    `;
    const [rows] = await db.execute(query, [userId]);

    const serverUrl = req.protocol + "://" + req.get("host");

    const historyData = rows.map(row => ({
      user_id: row.user_id,
      image_url: `${serverUrl}${row.image_url}`,
      situation: row.situation,
      timestamp: row.timestamp,
    }));

    console.log("Fitting history retrieved:", historyData);

    return res.status(200).json({
      success: true,
      message: "Fitting history retrieved successfully",
      data: historyData,
    });

  } catch (error) {
    console.error("Error retrieving fitting history:", error);
    return res.status(500).json({
      success: false,
      message: "Error retrieving fitting history",
      error: error.message,
    });
  }
});

router.get("/recommend", async (req, res) => {
  const { userId, situation, lat, lon } = req.query;

  console.log("Recommendation request:", { userId, situation, lat, lon });

  if (!userId || !situation || !lat || !lon) {
    console.error("Missing parameters:", { userId, situation, lat, lon });
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
        console.log("Python stdout:", stdout);
        console.log("Python stderr:", stderr);

        if (error) {
          console.error("Python execution error:", error);
          return res.status(500).json({ success: false, message: "Error executing script", error: error.message });
        }

        try {
          let response = JSON.parse(stdout.trim());

          if (!response.recommended || response.recommended.length === 0) {
            console.log("No suitable outfits found.");
            return res.status(200).json({ success: true, message: "No suitable outfits found", data: [] });
          }

          const recommendedItems = response.recommended;
          const itemIds = recommendedItems.map(item => item.id);

          console.log("Recommended items:", recommendedItems);

          const placeholders = itemIds.map(() => "?").join(",");
          const query = `SELECT id, image_url FROM vision_data WHERE user_id = ? AND id IN (${placeholders})`;
          const [rows] = await db.execute(query, [userId, ...itemIds]);

          const imageUrlMap = {};
          rows.forEach(row => { imageUrlMap[row.id] = row.image_url; });

          const serverUrl = req.protocol + "://" + req.get("host");
          const recommendedData = recommendedItems.map(item => ({
            id: item.id,
            category: item.category,
            predicted_style: item.predicted_style,
            image_url: imageUrlMap[item.id] ? `${serverUrl}${imageUrlMap[item.id]}` : null,
          }));

          const firstRecommendation = recommendedData.shift();
          const remainingRecommendations = recommendedData;

          global.recommendationCache = { userId, remainingRecommendations };

          return res.status(200).json({
            success: true,
            message: "Recommended outfit retrieved successfully",
            data: firstRecommendation,
          });

        } catch (parseError) {
          console.error("Error parsing Python response:", parseError);
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
  const { userId, itemId, feedback } = req.body;

  console.log("Feedback received:", { userId, itemId, feedback });

  if (!userId || !itemId || !feedback) {
    console.error("Missing parameters:", { userId, itemId, feedback });
    return res.status(400).json({ success: false, message: "Missing parameters" });
  }

  try {
    let preferenceChange = feedback === "like" ? 1 : -1;
    
    console.log("Updating preference:", { preferenceChange });

    const updateQuery = `
      UPDATE vision_data 
      SET preference = preference + ?, feedback_count = feedback_count + 1 
      WHERE user_id = ? AND id = ?`;

    await db.execute(updateQuery, [preferenceChange, userId, itemId]);

    const avgQuery = `
      SELECT predicted_style, AVG(preference) AS avg_pref 
      FROM vision_data 
      WHERE user_id = ? 
      GROUP BY predicted_style`;

    const [rows] = await db.execute(avgQuery, [userId]);

    for (const row of rows) {
      const { predicted_style, avg_pref } = row;
      const updatePrefQuery = `
        INSERT INTO user_preferences (user_id, style, preference_score)
        VALUES (?, ?, ?) 
        ON DUPLICATE KEY UPDATE preference_score = ?`;

      await db.execute(updatePrefQuery, [userId, predicted_style, avg_pref, avg_pref]);
    }

    console.log("Feedback processed and preferences updated.");

    // 피드백 후 추천 목록 갱신 (단, 좋아요일 경우 옷이 바뀌지 않도록 수정)
    if (global.recommendationCache && global.recommendationCache.userId === userId) {
      let updatedRecommendations = [...global.recommendationCache.remainingRecommendations];

      // dislike인 경우 해당 아이템을 제외
      if (feedback === "dislike") {
        updatedRecommendations = updatedRecommendations.filter(item => item.id !== itemId);
      }

      const nextRecommendation = updatedRecommendations.length > 0 ? updatedRecommendations[0] : null;

      // 갱신된 추천 목록 캐시 반영
      global.recommendationCache.remainingRecommendations = updatedRecommendations;

      return res.status(200).json({
        success: true,
        message: "Feedback recorded and preference updated",
        data: nextRecommendation ? { id: nextRecommendation.id, image_url: nextRecommendation.image_url } : null,
      });
    }

    return res.status(200).json({ success: true, message: "Feedback recorded and preference updated" });

  } catch (error) {
    console.error("Error processing feedback:", error);
    return res.status(500).json({ success: false, message: "Error processing feedback", error: error.message });
  }
});


module.exports = router;

import sys
import cv2
import numpy as np
import json
import os
import datetime
import pymysql
from dotenv import load_dotenv

# 환경 변수 로드
load_dotenv()

# 📌 인자 받기
cloth_img_path = sys.argv[1]  # 의상 이미지 경로
user_id = sys.argv[2]  # 사용자 ID

avatar_img_path = "model/data/avatar.png"
pose_json_path = "model/data/avatar_keypoints.json"

# 🔹 저장할 이미지 디렉토리 설정
output_dir = "output"
os.makedirs(output_dir, exist_ok=True)

# 🔹 MySQL 연결 정보
DB_CONFIG = {
    "host": os.getenv("DB_HOST"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "database": os.getenv("DB_NAME"),
    "charset": os.getenv("DB_CHARSET"),
}

OPENPOSE_KEYPOINTS_MAP = {
    "Neck": 1, "RShoulder": 2, "LShoulder": 5,
    "MidHip": 8, "RHip": 9, "LHip": 12,
    "RWrist": 4, "LWrist": 7
}

def load_avatar_keypoints(path):
    with open(path, "r") as f:
        data = json.load(f)
    kp = data["people"][0]["pose_keypoints_2d"]
    return {k: (kp[v*3], kp[v*3+1]) for k, v in OPENPOSE_KEYPOINTS_MAP.items()}

def detect_cloth_keypoints(image_path):
    img = cv2.imread(image_path, cv2.IMREAD_UNCHANGED)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    edges = cv2.Canny(gray, 50, 150)
    contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return None

    pts = np.vstack([cnt.squeeze() for cnt in contours])
    y_min, y_max = pts[:, 1].min(), pts[:, 1].max()
    x_min, x_max = pts[:, 0].min(), pts[:, 0].max()

    Neck = ((x_min + x_max) // 2, y_min)
    top = pts[pts[:, 1] <= y_min + int(img.shape[0] * 0.15)]
    LShoulder = tuple(top[top[:, 0].argmin()])
    RShoulder = tuple(top[top[:, 0].argmax()])
    mid = ((x_min + x_max) // 2, y_max - int(img.shape[0] * 0.1))

    return {
        "Neck": Neck, "LShoulder": LShoulder, "RShoulder": RShoulder,
        "MidHip": mid, "Type": ""  # Type 생략 가능
    }

def apply_affine(cloth_img, src, dst):
    src_pts = np.float32([src[p] for p in ["LShoulder", "RShoulder", "MidHip"]])
    dst_pts = np.float32([dst[p] for p in ["LShoulder", "RShoulder", "MidHip"]])
    M = cv2.getAffineTransform(src_pts, dst_pts)
    return cv2.warpAffine(cloth_img, M, (avatar_img.shape[1], avatar_img.shape[0]), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0, 0))

def overlay(avatar, cloth):
    result = avatar.copy()
    if cloth.shape[2] == 4:
        alpha = cloth[:, :, 3] / 255.0
        for c in range(3):
            result[:, :, c] = alpha * cloth[:, :, c] + (1 - alpha) * result[:, :, c]
    return result

def save_to_db(user_id, image_url):
    conn = pymysql.connect(**DB_CONFIG)
    try:
        with conn.cursor() as cur:
            sql = "INSERT INTO styled_outfits (user_id, image_url, created_at) VALUES (%s, %s, NOW())"
            cur.execute(sql, (user_id, image_url))
        conn.commit()
    finally:
        conn.close()

# 실행
avatar_img = cv2.imread(avatar_img_path, cv2.IMREAD_UNCHANGED)
avatar_kp = load_avatar_keypoints(pose_json_path)
cloth_kp = detect_cloth_keypoints(cloth_img_path)

# 어깨 살짝 벌리기
avatar_kp["LShoulder"] = (avatar_kp["LShoulder"][0] + 15, avatar_kp["LShoulder"][1])
avatar_kp["RShoulder"] = (avatar_kp["RShoulder"][0] - 15, avatar_kp["RShoulder"][1])

cloth_img = cv2.imread(cloth_img_path, cv2.IMREAD_UNCHANGED)
warped = apply_affine(cloth_img, cloth_kp, avatar_kp)
result = overlay(avatar_img, warped)

timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
filename = f"styled_outfit_{timestamp}.png"
output_path = os.path.join(output_dir, filename)
cv2.imwrite(output_path, result)

# URL 경로로 변환
server_base_url = "/uploads/fitting"
image_url = f"{server_base_url}/{filename}"
save_to_db(user_id, image_url)

print(image_url)

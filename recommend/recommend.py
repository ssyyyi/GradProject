import pymysql
import requests
import os
from dotenv import load_dotenv
from rdflib import Graph, Namespace, RDF
import json
import sys  # sys 임포트 추가

load_dotenv()

# 🔹 환경 변수 가져오기
DB_CONFIG = {
    "host": os.getenv("DB_HOST"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "database": os.getenv("DB_NAME"),
    "charset": os.getenv("DB_CHARSET"),
}
OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY")

# 온톨로지 로드
g = Graph()
g.parse("recommend/fashion.owl", format="turtle")
EX = Namespace("http://example.org/fashion#")

# 🟢 1. 날씨 데이터 가져오기
def get_weather(lat, lon):
    url = f"http://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lon}&appid={OPENWEATHER_API_KEY}&units=metric"
    response = requests.get(url)
    data = response.json()

    if "main" in data:
        temperature = data["main"]["temp"]
        return temperature
    return None

# 🟢 2. MySQL에서 사용자 옷 가져오기
def get_user_clothes(user_id):
    connection = pymysql.connect(**DB_CONFIG)
    try:
        with connection.cursor() as cursor:
            sql = "SELECT id, category, predicted_style, season FROM vision_data WHERE user_id = %s"
            cursor.execute(sql, (user_id,))
            result = cursor.fetchall()
            # 결과를 딕셔너리 형태로 변환
            return [{"id": row[0], "category": row[1], "predicted_style": row[2], "season": row[3]} for row in result]
    finally:
        connection.close()


# 🟢 3. 온톨로지에서 상황에 맞는 스타일 가져오기
def get_suitable_styles(situation):
    query = f"""
    PREFIX ex: <http://example.org/fashion#>
    SELECT ?style WHERE {{
        ex:{situation} ex:suitableForStyle ?style . 
    }}
    """
    styles = [str(row[0]).split("#")[-1] for row in g.query(query)]
    return styles

# 🟢 4. 추천 알고리즘 (수정된 버전)
def recommend_clothes(user_id, situation, lat, lon):
    # 1. 날씨 데이터 가져오기
    temperature = get_weather(lat, lon)
    if temperature is None:
        return {"error": "날씨 정보를 가져올 수 없습니다."}

    # 2. 사용자 옷 데이터 가져오기 (season 포함)
    user_clothes = get_user_clothes(user_id)
    if not user_clothes:
        return {"error": "사용자의 옷장에 데이터가 없습니다."}

    # 사용자 옷에서 season 정보 필터링
    user_season_clothes = [item for item in user_clothes if item["season"] is not None]

    if not user_season_clothes:
        return {"error": "사용자 옷장에서 계절 정보가 없는 옷이 없습니다."}

    # 사용자의 계절 정보를 기반으로 필터링
    if temperature >= 25:
        season = "summer"
    elif temperature <= 10:
        season = "winter"
    else:
        season = "springautumn"

    # 해당 계절에 맞는 옷 필터링
    filtered_clothes = [item for item in user_season_clothes if item["season"] == season]

    if not filtered_clothes:
        return {"error": f"{season}에 적합한 의상이 없습니다."}

    # 3. 적합한 스타일 가져오기 (상황)
    suitable_styles = set(get_suitable_styles(situation))

    # 4. 스타일 필터링 후, 추천 의상 선택 (여러 개 반환)
    recommended = [item for item in filtered_clothes if item["predicted_style"] in suitable_styles]

    if not recommended:
        return {"error": "추천할 의상이 없습니다."}

    # 🟢 5. 사용자 선호도 가져오기 (선호도 점수 기준으로 정렬)
    connection = pymysql.connect(**DB_CONFIG)
    try:
        with connection.cursor() as cursor:
            # 사용자 선호도 가져오기
            query = "SELECT style, preference_score FROM user_preferences WHERE user_id = %s"
            cursor.execute(query, (user_id,))
            preferences = cursor.fetchall()
            # 선호도를 딕셔너리로 변환
            preference_dict = {row[0]: row[1] for row in preferences}

            # 추천 의상에 선호도 점수 추가
            for item in recommended:
                item["preference_score"] = preference_dict.get(item["predicted_style"], 0)

            # 선호도 점수를 기준으로 정렬 (내림차순)
            recommended.sort(key=lambda x: x["preference_score"], reverse=True)

    finally:
        connection.close()

    # ✅ 여러 개의 추천 의상을 포함하도록 변경
    response = {
        "temperature": temperature,
        "recommended": recommended
    }

    return response



# 🟢 6. 실행 예시
if __name__ == "__main__":
    user_id = sys.argv[1]
    situation = sys.argv[2]
    lat = float(sys.argv[3])
    lon = float(sys.argv[4])

    result = recommend_clothes(user_id, situation, lat, lon)

    # ✅ UTF-8 인코딩 강제 설정
    sys.stdout.reconfigure(encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))

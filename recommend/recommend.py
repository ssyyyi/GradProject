import pymysql
import requests
import os
from dotenv import load_dotenv
from rdflib import Graph, Namespace, RDF

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
g.parse("fashion.owl", format="turtle")
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
            sql = "SELECT id, category, predicted_style FROM vision_data WHERE user_id = %s"
            cursor.execute(sql, (user_id,))
            return cursor.fetchall()  # [(1, 'Top', 'Casual'), (2, 'Top', 'Sporty'), ...]
    finally:
        connection.close()

# 🟢 3. 온톨로지에서 상황에 맞는 스타일 가져오기
def get_suitable_styles(situation):
    query = f"""
    PREFIX ex: <http://example.org/fashion#>
    SELECT ?style WHERE {{
        ?style rdf:type ex:Style .
        ?style ex:suitableForSituation ex:{situation} .
    }}
    """
    return [str(row[0]).split("#")[-1] for row in g.query(query)]  # 스타일 이름 리스트 반환

# 🟢 4. 온톨로지에서 온도에 맞는 스타일 가져오기
def get_suitable_styles_for_weather(temperature):
    if temperature >= 25:
        season = "Summer"
    elif temperature <= 10:
        season = "Winter"
    else:
        season = "SpringAutumn"

    query = f"""
    PREFIX ex: <http://example.org/fashion#>
    SELECT ?style WHERE {{
        ?clothing ex:suitableForSeason ex:{season} .
        ?clothing ex:suitableForStyle ?style .
    }}
    """
    return [str(row[0]).split("#")[-1] for row in g.query(query)]

# 🟢 5. 추천 알고리즘
def recommend_clothes(user_id, situation, lat, lon):
    temperature = get_weather(lat, lon)
    if temperature is None:
        return {"error": "날씨 정보를 가져올 수 없습니다."}

    user_clothes = get_user_clothes(user_id)
    if not user_clothes:
        return {"error": "사용자의 옷장에 데이터가 없습니다."}

    suitable_styles = set(get_suitable_styles(situation)) | set(get_suitable_styles_for_weather(temperature))

    recommended = [item for item in user_clothes if item[2] in suitable_styles]  # 스타일 필터링

    return {"temperature": temperature, "recommended": recommended}

# 🟢 6. 실행 예시
if __name__ == "__main__":
    user_id = 1
    situation = "CasualMeeting"  # 'FormalEvent', 'Sports', 'Date' 가능
    lat, lon = 37.5665, 126.9780  # 서울 좌표 예시

    result = recommend_clothes(user_id, situation, lat, lon)
    print(result)

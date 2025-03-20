import sys
import json

# 인자로 전달된 값 가져오기
situation = sys.argv[1]
season = sys.argv[2]

# 예제 데이터 (온톨로지에서 가져온다고 가정)
ontology_recommendations = {
    "casualMeeting": {
        "Winter": ["coat", "knitwear", "jeans"],
        "SpringAutumn": ["jacket", "long_pants", "sweater"],
        "Summer": ["shorts", "tshirt", "light_jacket"]
    },
    "FormalEvent": {
        "Winter": ["suit", "trench_coat", "dress_shoes"],
        "SpringAutumn": ["blazer", "slacks", "oxford_shoes"],
        "Summer": ["linen_shirt", "dress_pants", "loafers"]
    }
}

# 추천 리스트 가져오기
recommendations = ontology_recommendations.get(situation, {}).get(season, [])

# JSON 형식으로 출력 (Node.js에서 받아서 처리)
print(json.dumps(recommendations))

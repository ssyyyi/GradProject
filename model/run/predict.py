import sys
import os
import argparse
import json
import torch
import time
from PIL import Image
from torchvision import transforms
import pickle

# 현재 스크립트의 상위 디렉토리를 Python 경로에 추가
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

# 필요한 모델 import
from utility.resnest import *  # resnest 모델
from utility.ml_gcn import *   # GCN 모델

# 🔹 클래스 매핑 JSON 파일 경로
class_mapping_path_category = os.path.join(os.path.dirname(__file__), '..', 'data', 'kfashion_category', 'category_category_final2.json')
class_mapping_path_style = os.path.join(os.path.dirname(__file__), '..', 'data', 'kfashion_style', 'category_custom_final.json')

# 🔹 JSON 클래스 매핑 로드 함수
def load_class_mapping(file_path):
    if not os.path.exists(file_path):
        print(json.dumps({"error": f"⚠️ 클래스 매핑 파일이 없습니다! ({file_path})"}))
        sys.exit(1)

    with open(file_path, 'r', encoding='utf-8') as f:
        class_mapping = json.load(f)

    return {int(v): k for k, v in class_mapping.items()}  # {0: "코트"} 형태로 변환

# 🔹 파라미터 설정
parser = argparse.ArgumentParser(description='Single Image Category and Style Prediction')
parser.add_argument('--image-size', default=224, type=int)
parser.add_argument('--device_ids', default=[0, 1, 2, 3], type=int, nargs='+')
parser.add_argument('--batch-size', default=1, type=int, help='Batch size (default: 1)')
parser.add_argument('--image-path', required=True, help='Path to the image to be classified')

# 🔹 이미지 예측 함수
def run_prediction():
    args = parser.parse_args()
    use_gpu = torch.cuda.is_available()

    # 🔹 클래스 매핑 로드
    class_mapping_category = load_class_mapping(class_mapping_path_category)
    class_mapping_style = load_class_mapping(class_mapping_path_style)

    # 🔹 모델 설정 - 카테고리 예측 모델
    num_classes_category = 21  # 카테고리 모델 클래스 수 (예: 21개 클래스)
    model_path_category = '../checkpoint/kfashion_category/model_category_best.pth.tar'
    model_category = resnest50d(pretrained=False, nc=num_classes_category)
    model_category.load_state_dict(torch.load(model_path_category, map_location="cuda" if use_gpu else "cpu", weights_only=True)['state_dict'])
    model_category.eval()

    # 🔹 모델 설정 - 스타일 예측 모델
    num_classes_style = 10  # 스타일 모델 클래스 수 (예: 10개 스타일)
    model_style = gcn_resnet101(num_classes=num_classes_style, t=0.03, adj_file='../data/kfashion_style/custom_adj_final.pkl')
    # Word vector 로드
    with open('../data/kfashion_style/custom_glove_word2vec_final.pkl', 'rb') as f:
        inp_vector = pickle.load(f)
    inp_vector_tensor = torch.tensor(inp_vector, dtype=torch.float32).unsqueeze(0)

    model_style.eval()

    if use_gpu:
        model_category = model_category.cuda()
        model_style = model_style.cuda()

    # 🔹 이미지 로드 및 전처리
    img = Image.open(args.image_path).convert('RGB')
    transform = transforms.Compose([
        transforms.Resize((args.image_size, args.image_size)),
        transforms.ToTensor(),
    ])
    img = transform(img).unsqueeze(0)

    if use_gpu:
        img = img.cuda()

    # 🔹 카테고리 예측
    with torch.no_grad():
        output_category = model_category(img)

    # 🔹 스타일 예측
    with torch.no_grad():
        output_style = model_style(img, inp_vector_tensor)

    # 🔹 카테고리 예측 결과
    predicted_class_category = output_category.argmax(dim=1).item()
    predicted_label_category = class_mapping_category.get(predicted_class_category, "Unknown")

    # 🔹 스타일 예측 결과
    predicted_class_style = output_style.argmax(dim=1).item()
    predicted_label_style = class_mapping_style.get(predicted_class_style, "Unknown")

    # 🔹 JSON 결과 출력 (Node.js가 파싱 가능하도록)
    result = {
        "predicted_category": predicted_label_category,
        "predicted_style": predicted_label_style
    }

    print(json.dumps(result))
    sys.stdout.flush()  # Node.js가 결과를 즉시 받을 수 있도록 flush 실행

if __name__ == '__main__':
    start_time = time.time()
    run_prediction()

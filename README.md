# objDetectorTest

## AI Model 링크
[Storage for the  AI Models](https://1drv.ms/u/s!Auhtu5u0qmLGvJ5E5RTU6a5qo-r4Hg?e=YbzsLM)<br><br><br>

## Object Tracker 추가 필요성
### 1. 객체 탐지 실패 시 추적
- 객체 탐지에 실패하는 경우가 있음
- 이때 객체 추적이 가능하다면 프레임의 객체를 예측할 수 있음
  - 보행자를 탐지하는 중 보행자가 다른 사물에 가려지는 경우 --> 보행자 탐지 실패
  - 그러나 객체 추적 알고리즘을 구현하여 객체 탐지에 더하는 경우 여전히 탐지 대상을 예측하고 추적할 수 있음
  - 참고: https://github.com/ADA-1st-macro-walikngAssistant/yolov7_with_object_tracking<br><br>
### 2. 필요 작업
- ID 할당
  - 객체 탐지만을 사용하는 경우 객체의 위치만 표시하므로, 출력 배열만 보면 어떤 좌표가 어느 객체에 해당하는지 알 수 없음
  - 각 개체에 ID를 할당하고, 해당 프레임에서 해당 개체의 수명이 다할 때까지 해당 ID를 유지하여야 함
- 실시간 예측
  - 추적기 알고리즘의 실행 속도는 상당히 빠르므로 디텍터 + 트래커 동작은 무리 없을 것으로 판단됨<br><br>
### 3. DeepSORT 아키텍쳐
![DeepSORT_architecture](https://user-images.githubusercontent.com/82295573/200989741-3085c39b-a665-4d7f-8920-1ea33a65faaa.png)

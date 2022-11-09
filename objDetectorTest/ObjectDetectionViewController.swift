//
//  ObjectDetectionViewController.swift
//  objDetectorTest
//
//  Created by raymond on 2022/11/04.
//

import UIKit
import Vision
import CoreMedia

class ObjectDetectionViewController: UIViewController {

    // TODO: 스토리보드 연결 제거
    // MARK: UI 프로퍼티
//    var videoPreview: UIView!
    var boundingBoxView: BoundingBoxDisplayView!
    var labelsTableView: UITableView!

    var inferenceLabel: UILabel!
    var etimeLabel: UILabel!
    var fpsLabel: UILabel!

    func createInferenceView() {

    }

    // MARK: lazy var for object recognizer: UIView type.
    // The frame of the view is 300X240
    lazy var videoPreview: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.borderColor = UIColor.red.cgColor
        view.layer.borderWidth = 2
        view.frame = CGRect(x: 0, y: 0, width: 300, height: 240)
        return view
    }()


    var objectRecognitionModel: yolov5x6 {
        do {
            let config = MLModelConfiguration()
            return try yolov5x6(configuration: config)
        } catch {
            print(error)
            fatalError("Cannot create YOLOv5x6")
        }
    }

    // MARK: Vision 프레임워크 프로퍼티
    var request: VNCoreMLRequest?
    var visionModel: VNCoreMLModel?
    var didInference = false

    // MARK: AV 프레임워크 프로퍼티
    var videoCapture: VideoCapture!
    let semaphore = DispatchSemaphore(value: 1)
    var lastExecution = Date()

    // MARK: 예측값을 나타내기 위한 TableView에 들어가는 데이터
    var predictions: [VNRecognizedObjectObservation] = []

    // MARK: 모델 퍼포먼스 측정을 위한 프로퍼티
    private let performanceMeasurement = NumericMeasurements()

    // MARK: 이동 평균 필터(MAF; moving average filter) 정의 - 바운딩 박스 렌더링 및 경로 트래킹시 Noise 제거용
        /// 참고: https://www.analog.com/media/en/technical-documentation/dsp-book/dsp_book_ch15.pdf
    let movingAverageFilter1 = MovingAverageFilter()
    let movingAverageFilter2 = MovingAverageFilter()
    let movingAverageFilter3 = MovingAverageFilter()

    // MARK: CoreML 설정
    func setupCoreMLModel() {
        if let visionModel = try? VNCoreMLModel(for: objectRecognitionModel.model) {
            self.visionModel = visionModel
            request = VNCoreMLRequest(model: visionModel,
                                      completionHandler: didCompleteVisionRequest)
            request?.imageCropAndScaleOption = .scaleFill
        } else {
            fatalError("fail to create vision model")
        }
    }


    // MARK: object recognizer view 설정
    func setupObjectRecognizer() {
        videoPreview.layer.borderColor = UIColor.red.cgColor
        videoPreview.layer.borderWidth = 2
        videoPreview.layer.cornerRadius = 10
        videoPreview.layer.masksToBounds = true
        videoPreview.isHidden = true
        view.addSubview(videoPreview)
    }

//    func setupObjectRecognizer() {
//        objectRecognizer = ObjectRecognizer()
//    }

    // MARK: 뷰 컨트롤러 라이프사이클 정의
    override func viewDidLoad() {
        super.viewDidLoad()

        /// 모델 호출
        setupCoreMLModel()

        /// 객체 탐지기 호출
        setupObjectRecognizer()
    }

}


class MovingAverageFilter {
    private var arr: [Int] = []
    private let maxCount = 10

    public func appendElement(element: Int) {
        arr.append(element)
        if arr.count > maxCount {
            arr.removeFirst()
        }
    }

    public var averageValue: Int {
        guard !arr.isEmpty else { return 0 }
        let sum = arr.reduce(0) { $0 + $1 }
        return Int(Double(sum) / Double(arr.count))
    }
}


extension ObjectDetectionViewController {
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        guard let request = request else { fatalError() }

        /// 참고: 모델의 입력 구성에 따라 비전 프레임워크가 이미지의 입력 크기를 자동으로 구성함.
        self.semaphore.wait()  // wait(): -1, signal(): +1 반환
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try? handler.perform([request])
    }

    // MARK: 포스트 프로세싱
    func didCompleteVisionRequest(request: VNRequest, error: Error?) {
        self.performanceMeasurement.didObjectLabeled(with: "endInference")

        if let predictions = request.results as? [VNRecognizedObjectObservation] {
//            print(predictions.first?.labels.first?.identifier ?? "nil")
//            print(predictions.first?.labels.first?.confidence ?? -1)

            self.predictions = predictions

            DispatchQueue.main.async {
                self.boundingBoxView.predictedObjects = predictions
                self.labelsTableView.reloadData()

                // 측정 종료
                self.performanceMeasurement.didEndNumericMeasurement()

                self.didInference = false
            }
        } else {
            // 측정 종료
            self.performanceMeasurement.didEndNumericMeasurement()

            self.didInference = false
        }
        self.semaphore.signal()
    }
}

extension ObjectDetectionViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return predictions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "InformationCell") else {
            return UITableViewCell()
        }

        let rectString = predictions[indexPath.row].boundingBox.toString(digit: 3)
        let confidence = predictions[indexPath.row].labels.first?.confidence ?? -1
        let confidenceString = String(format: "%.3f", confidence)  // MARK: confidence: Math.sigmoid(confidence)

        cell.textLabel?.text = predictions[indexPath.row].label ?? "N/A"
        cell.detailTextLabel?.text = "\(rectString), \(confidenceString)"
        return cell
    }
}

extension ObjectDetectionViewController: NumericMeasurementsDelegate {
    func updateMeasurementResult(inferenceTime: Double, executionTime: Double, fps: Int) {
        print(executionTime, fps)

        DispatchQueue.main.async {
            self.movingAverageFilter1.appendElement(element: Int(inferenceTime * 1000.0))
            self.movingAverageFilter2.appendElement(element: Int(inferenceTime * 1000.0))
            self.movingAverageFilter3.appendElement(element: fps)

            self.inferenceLabel.text = "Inference: \(self.movingAverageFilter1.averageValue) ms"
            self.etimeLabel.text = "Inference: \(self.movingAverageFilter2.averageValue) ms"
            self.fpsLabel.text = "Inference: \(self.movingAverageFilter3.averageValue) ms"
        }
    }
}
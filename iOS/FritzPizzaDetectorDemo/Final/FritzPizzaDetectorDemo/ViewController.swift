import UIKit
import AVFoundation
import Fritz

class ViewController: UIViewController {

  var timer: Timer?

  lazy var visionModel = FritzVisionLabelModel()

  private lazy var cameraSession = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "com.fritzdemo.pizzadetector.session")
  private let captureQueue = DispatchQueue(label: "com.fritzdemo.pizzadetector.capture", qos: DispatchQoS.userInitiated)

  private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
    let preview = AVCaptureVideoPreviewLayer(session: cameraSession)
    preview.videoGravity = .resizeAspectFill
    return preview
  }()

  override func viewDidLoad() {
    super.viewDidLoad()

    // Setup model
    visionModel = FritzVisionLabelModel()

    // Setup camera
    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
      let input = try? AVCaptureDeviceInput(device: device)
      else { return }

    let output = AVCaptureVideoDataOutput()

    // Configure pixelBuffer format for use in model
    output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA as UInt32]
    output.alwaysDiscardsLateVideoFrames = true
    output.setSampleBufferDelegate(self, queue: captureQueue)

    sessionQueue.async {
      self.cameraSession.beginConfiguration()
      self.cameraSession.addInput(input)
      self.cameraSession.addOutput(output)
      self.cameraSession.commitConfiguration()
      self.cameraSession.sessionPreset = .photo
    }

  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    // Set the preview layer to the frame of the screen and start running.
    previewLayer.frame = view.layer.bounds
    view.layer.insertSublayer(previewLayer, at: 0)
    sessionQueue.async {
      self.cameraSession.startRunning()
    }
  }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    // 1
    let image = FritzVisionImage(sampleBuffer: sampleBuffer, connection: connection)

    // 2
    let options = FritzVisionLabelModelOptions()
    options.imageCropAndScaleOption = .centerCrop
    options.threshold = 0.2

    // 3
    guard let results = try? visionModel.predict(image, options: options) else { return }

    // 4
    let pizzaResults = results.filter { $0.label == "pizza" }
    if pizzaResults.count > 0 {
      print("Creating pizza timer")
      DispatchQueue.main.async {
        for _ in 0..<10 {
          self.createNewPizzaSlice()
        }
      }
    }
  }
}


extension ViewController {

  /// Generates a random pizza destination along the edge
  func generateRandomPizzaDestination() -> CGPoint {
    let width = view.frame.width
    let height = view.frame.height
    let multiplier = Int.random(in: 0..<2)

    let sendPizzaToLeftOrRight = Bool.random()
    if sendPizzaToLeftOrRight {
      let randomHeight = CGFloat.random(in: 0..<height)
      return CGPoint(x: width * CGFloat(multiplier), y: randomHeight)
    }

    let randomWidth = CGFloat.random(in: 0..<height)
    return CGPoint(x: randomWidth, y: height * CGFloat(multiplier))
  }

  var randomJitter: CGFloat {
    return CGFloat.random(in: -50..<50)
  }

  /// Creates a new Pizza animation
  func createNewPizzaSlice() {
    // 1
    let pizzaView = UIImageView(image: UIImage(named: "pizza.png")!)
    let frame = CGRect(
      x: self.view.frame.width / 2 - 50 + randomJitter,
      y: self.view.frame.height / 2 - 50 + randomJitter,
      width: 100,
      height: 100
    )
    pizzaView.frame = frame

    // 2
    self.view.addSubview(pizzaView)
    self.view.bringSubviewToFront(pizzaView)

    // 3
    UIView.animate(withDuration: 2.0, animations: {
      pizzaView.center = self.generateRandomPizzaDestination()
    }) { _ in
      pizzaView.removeFromSuperview()
    }
  }
}

import Cocoa
import FlutterMacOS
import CoreML
import Vision
import AppKit
import ImageIO

@main
class AppDelegate: FlutterAppDelegate {
  private var visionModel: VNCoreMLModel?
  private var isCoreMLInitialized = false
  
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    NSLog("🚀 AppDelegate.applicationDidFinishLaunching called")
    super.applicationDidFinishLaunching(notification)
    
    // Initialize Core ML
    if #available(macOS 10.15, *) {
      NSLog("🔧 Setting up Core ML...")
      setupCoreML()
    } else {
      NSLog("❌ macOS version too old for Core ML")
    }
    
    // Set up Core ML platform channel immediately and with retries
    NSLog("🔌 Setting up platform channel immediately...")
    setupCoreMLChannel()
    
    // Also set up with delay as backup
    NSLog("⏰ Scheduling backup platform channel setup in 2 seconds...")
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
      NSLog("⏰ 2 seconds elapsed, setting up platform channel (backup)...")
      self.setupCoreMLChannel()
    }
  }
  
  @available(macOS 10.15, *)
  private func setupCoreML() {
    do {
      // Try to load MobileNet V2 .mlmodelc (compiled version)
      if let mobileNetURL = Bundle.main.url(forResource: "MobileNetV2", withExtension: "mlmodelc") {
        let model = try MLModel(contentsOf: mobileNetURL)
        visionModel = try VNCoreMLModel(for: model)
        print("✅ MobileNet V2 Core ML model loaded successfully (.mlmodelc)")
        isCoreMLInitialized = true
        return
      }
      
      // Try to load MobileNet V2 .mlmodel (source version)
      if let mobileNetURL = Bundle.main.url(forResource: "MobileNetV2", withExtension: "mlmodel") {
        let model = try MLModel(contentsOf: mobileNetURL)
        visionModel = try VNCoreMLModel(for: model)
        print("✅ MobileNet V2 Core ML model loaded successfully (.mlmodel)")
        isCoreMLInitialized = true
        return
      }
      
      // Fallback to built-in Vision framework models
      print("⚠️ No custom Core ML models found, using Vision framework")
      isCoreMLInitialized = true
      
    } catch {
      print("❌ Error setting up Core ML: \(error)")
      isCoreMLInitialized = false
    }
  }
  
  private func setupCoreMLChannel() {
    NSLog("🔌 Setting up Core ML platform channel...")
    NSLog("🔍 Checking mainFlutterWindow: \(mainFlutterWindow != nil ? "exists" : "nil")")
    
    // Try to get the FlutterViewController from the main window
    guard let window = mainFlutterWindow else {
      NSLog("❌ mainFlutterWindow is nil")
      return
    }
    
    NSLog("🔍 Window found, checking contentViewController...")
    guard let controller = window.contentViewController as? FlutterViewController else {
      NSLog("❌ contentViewController is not FlutterViewController: \(type(of: window.contentViewController))")
      return
    }
    
    NSLog("✅ FlutterViewController found, creating method channel...")
    
    let coreMLChannel = FlutterMethodChannel(
      name: "creativevault.coreml",
      binaryMessenger: controller.engine.binaryMessenger
    )
    
    NSLog("✅ Method channel created: creativevault.coreml")
    
    coreMLChannel.setMethodCallHandler { [weak self] (call, result) in
      NSLog("📞 Method call received: \(call.method)")
      self?.handleCoreMLMethodCall(call: call, result: result)
    }
    
    NSLog("✅ Core ML platform channel setup completed")
  }
  
  private func setupCoreMLChannelDelayed() {
    print("🔌 Setting up Core ML platform channel (delayed)...")
    
    guard let window = mainFlutterWindow,
          let controller = window.contentViewController as? FlutterViewController else {
      print("❌ Could not get FlutterViewController even after delay")
      return
    }
    
    print("✅ FlutterViewController found (delayed), creating method channel...")
    
    let coreMLChannel = FlutterMethodChannel(
      name: "creativevault.coreml",
      binaryMessenger: controller.engine.binaryMessenger
    )
    
    print("✅ Method channel created: creativevault.coreml")
    
    coreMLChannel.setMethodCallHandler { [weak self] (call, result) in
      print("📞 Method call received: \(call.method)")
      self?.handleCoreMLMethodCall(call: call, result: result)
    }
    
    print("✅ Core ML platform channel setup completed (delayed)")
  }
  
  private func handleCoreMLMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("🔍 Handling Core ML method call: \(call.method)")
    
    if #available(macOS 10.15, *) {
      switch call.method {
      case "initializeCoreML":
        print("📞 initializeCoreML called, Core ML initialized: \(isCoreMLInitialized)")
        result(isCoreMLInitialized)
        
      case "testConnection":
        print("📞 testConnection called - platform channel is working!")
        result("Platform channel is working!")
        
      case "extractFeatureVector":
        print("📞 extractFeatureVector called")
        guard let args = call.arguments as? [String: Any],
              let imagePath = args["imagePath"] as? String else {
          print("❌ Invalid arguments for extractFeatureVector")
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
          return
        }
        
        print("🔍 Extracting features from: \(imagePath)")
        if let featureVector = extractFeatureVector(imagePath: imagePath) {
          print("✅ Feature vector extracted: \(featureVector.count) dimensions")
          result(featureVector)
        } else {
          print("❌ Failed to extract feature vector")
          result(FlutterError(code: "EXTRACTION_FAILED", message: "Failed to extract features", details: nil))
        }
        
      default:
        print("❌ Unknown method: \(call.method)")
        result(FlutterMethodNotImplemented)
      }
    } else {
      print("❌ macOS version too old for Core ML")
      result(FlutterError(code: "UNSUPPORTED_VERSION", message: "Core ML requires macOS 10.15+", details: nil))
    }
  }
  
  @available(macOS 10.15, *)
  private func extractFeatureVector(imagePath: String) -> [Double]? {
    guard isCoreMLInitialized else {
      print("❌ Core ML not initialized")
      return nil
    }
    
    guard let imageURL = URL(string: imagePath) else {
      print("❌ Invalid image path: \(imagePath)")
      return nil
    }
    
    do {
      let imageData = try Data(contentsOf: imageURL)
      guard let image = NSImage(data: imageData) else {
        print("❌ Could not create image from data")
        return nil
      }
      
      // Convert NSImage to CIImage
      guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("❌ Could not create CGImage from NSImage")
        return nil
      }
      
      let ciImage = CIImage(cgImage: cgImage)
      
      if let visionModel = visionModel {
        return extractFeaturesWithVisionModel(ciImage: ciImage, model: visionModel)
      } else {
        return extractFeaturesWithVisionFramework(ciImage: ciImage)
      }
      
    } catch {
      print("❌ Error processing image: \(error)")
      return nil
    }
  }
  
  @available(macOS 10.15, *)
  private func extractFeaturesWithVisionModel(ciImage: CIImage, model: VNCoreMLModel) -> [Double]? {
    var featureVector: [Double]?
    let semaphore = DispatchSemaphore(value: 0)
    
    let request = VNCoreMLRequest(model: model) { request, error in
      if let error = error {
        print("❌ Vision request error: \(error)")
        semaphore.signal()
        return
      }
      
      guard let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let firstObservation = observations.first,
            let multiArray = firstObservation.featureValue.multiArrayValue else {
        print("❌ Could not extract features from Vision model")
        semaphore.signal()
        return
      }
      
      // Convert MLMultiArray to [Double]
      featureVector = (0..<multiArray.count).map { Double(truncating: multiArray[$0]) }
      semaphore.signal()
    }
    
    // Configure the request
    request.imageCropAndScaleOption = .centerCrop
    
    let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
    
    do {
      try handler.perform([request])
      semaphore.wait()
      return featureVector
    } catch {
      print("❌ Error performing Vision request: \(error)")
      return nil
    }
  }
  
  @available(macOS 10.15, *)
  private func extractFeaturesWithVisionFramework(ciImage: CIImage) -> [Double]? {
    var featureVector: [Double]?
    let semaphore = DispatchSemaphore(value: 0)
    
    // Use Vision framework's built-in feature extraction
    let request = VNClassifyImageRequest { request, error in
      if let error = error {
        print("❌ Vision classification error: \(error)")
        semaphore.signal()
        return
      }
      
      guard let observations = request.results as? [VNClassificationObservation] else {
        print("❌ Could not extract classification observations")
        semaphore.signal()
        return
      }
      
      // Convert classification results to feature vector
      // Take top 1000 classifications as features
      let topClassifications = observations.prefix(1000)
      featureVector = topClassifications.map { Double($0.confidence) }
      
      // Pad with zeros if we have fewer than 1000 classifications
      while featureVector!.count < 1000 {
        featureVector!.append(0.0)
      }
      
      semaphore.signal()
    }
    
    let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
    
    do {
      try handler.perform([request])
      semaphore.wait()
      return featureVector
    } catch {
      print("❌ Error performing Vision classification: \(error)")
      return nil
    }
  }
}

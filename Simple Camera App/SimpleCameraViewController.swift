//
//  SimpleCameraViewController.swift
//  Simple Camera App
//
//  Created by Sorfian on 31/03/23.
//

import UIKit
import AVFoundation

class SimpleCameraViewController: UIViewController {

    @IBOutlet weak var cameraButton: UIButton!
    let captureSession = AVCaptureSession()
    
    var backFacingCamera: AVCaptureDevice?
    var frontFacingCamera: AVCaptureDevice?
    var currentDevice: AVCaptureDevice!
    
    var stillImageOutput: AVCapturePhotoOutput!
    var stillImage: UIImage?
    
    var cameraPreviewLayer: AVCaptureVideoPreviewLayer?
    
    var toggleCameraGestureRecognizer = UISwipeGestureRecognizer()
    
    var zoomInGestureRecognizer = UISwipeGestureRecognizer()
    var zoomOutGestureRecognizer = UISwipeGestureRecognizer()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func configure() {
//        Preset the session for taking photo in full resolution
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        
//        Get the front and back-facing camera for taking photos
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInDualWideCamera], mediaType: AVMediaType.video, position: .unspecified)
        
        for device in deviceDiscoverySession.devices {
            if device.position == .back {
                backFacingCamera = device
            } else if device.position == .front {
                frontFacingCamera = device
            }
        }
        
        currentDevice = backFacingCamera
        
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: currentDevice) else {
            return
        }
        
//         Configure the session with the output for capturing still images
        stillImageOutput = AVCapturePhotoOutput()
        
//         Configure the session with the input and the output devices
        captureSession.addInput(captureDeviceInput)
        captureSession.addOutput(stillImageOutput)
        
//        Provide a camera preview
        cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.addSublayer(cameraPreviewLayer!)
        cameraPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        cameraPreviewLayer?.frame = view.layer.frame
        
//        Bring the camera button to front
        view.bringSubviewToFront(cameraButton)
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
        
        toggleCameraGestureRecognizer.direction = .up
        toggleCameraGestureRecognizer.addTarget(self, action: #selector(toggleCamera))
        view.addGestureRecognizer(toggleCameraGestureRecognizer)
        
//        Zoom in recognizer
        zoomInGestureRecognizer.direction = .right
        zoomInGestureRecognizer.addTarget(self, action: #selector(zoomIn))
        view.addGestureRecognizer(zoomInGestureRecognizer)
        
//        Zoom out recognizer
        zoomOutGestureRecognizer.direction = .left
        zoomOutGestureRecognizer.addTarget(self, action: #selector(zoomOut))
        view.addGestureRecognizer(zoomOutGestureRecognizer)
    }
    
    @IBAction func capture(_ sender: UIButton) {
//        Set photo settings
        let photoSettings = AVCapturePhotoSettings(format: [
            AVVideoCodecKey : AVVideoCodecType.jpeg
        ])
        photoSettings.maxPhotoDimensions = CMVideoDimensions(width: 2556, height: 11792)
        photoSettings.flashMode = .auto
        
        stillImageOutput.maxPhotoDimensions = CMVideoDimensions(width: 2556, height: 11792)
        stillImageOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    @IBAction func unwindToCameraView(segue: UIStoryboardSegue) {
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPhoto" {
            let photoViewController = segue.destination as! PhotoViewController
            photoViewController.image = stillImage
        }
    }
    
    @objc func toggleCamera() {
        captureSession.beginConfiguration()
        
//        Change the device based on the current camera
        guard let newDevice = (currentDevice.position == AVCaptureDevice.Position.back) ? frontFacingCamera : backFacingCamera else {
            return
        }
        
//        Remove all inputs from the session
        for input in captureSession.inputs {
            captureSession.removeInput(input as! AVCaptureDeviceInput)
        }
        
//        Change to the new input
        let cameraInput: AVCaptureDeviceInput
        do {
            cameraInput = try AVCaptureDeviceInput(device: newDevice)
        } catch {
            print(error)
            return
        }
        
        if captureSession.canAddInput(cameraInput) {
            captureSession.addInput(cameraInput)
        }
        
        currentDevice = newDevice
        captureSession.commitConfiguration()
    }
    
    @objc func zoomIn() {
        if let zoomFactor = currentDevice?.videoZoomFactor {
            if zoomFactor < 5.0 {
                let newZoomFactor = min(zoomFactor + 1.0, 5.0)
                
                do {
                    try currentDevice.lockForConfiguration()
                    currentDevice.ramp(toVideoZoomFactor: newZoomFactor, withRate: 1.0)
                    currentDevice.unlockForConfiguration()
                } catch {
                    print(error)
                }
            }
        }
    }
    
    @objc func zoomOut() {
        if let zoomFactor = currentDevice?.videoZoomFactor {
            if zoomFactor > 1.0 {
                let newZoomFactor = min(zoomFactor - 1.0, 5.0)
                
                do {
                    try currentDevice.lockForConfiguration()
                    currentDevice.ramp(toVideoZoomFactor: newZoomFactor, withRate: 1.0)
                    currentDevice.unlockForConfiguration()
                } catch {
                    print(error)
                }
            }
        }
    }
    
}

extension SimpleCameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            return
        }
        
//        Get the image from the photo buffer
        guard let imageData = photo.fileDataRepresentation() else {
            return
        }
        
        stillImage = UIImage(data: imageData)
        performSegue(withIdentifier: "showPhoto", sender: self)
    }
}

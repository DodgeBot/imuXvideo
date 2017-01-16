//
//  ViewController.swift
//  FYP
//
//  Created by Jason HSJ on 9/1/2017.
//  Copyright © 2017 Jason, HU. All rights reserved.
//

import UIKit
// gyro, acc
import CoreMotion
// compass
import CoreLocation
// video
import AVFoundation


extension Date {
    struct Formatter {
        static let iso8601: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.locale = Locale(identifier: "zh_HK_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 8*3600)
            formatter.dateFormat = "yyMMdd'T'HHmmss"
            return formatter
        }()
    }
    var iso8601: String {
        return Formatter.iso8601.string(from: self)
    }
}


extension String {
    var dateFromISO8601: Date? {
        return Date.Formatter.iso8601.date(from: self)
    }
}

class ViewController: UIViewController,
CLLocationManagerDelegate,
AVCapturePhotoCaptureDelegate,
AVCaptureFileOutputRecordingDelegate
{
    
//    @IBOutlet var imu_acc_x: UITextView!
//    @IBOutlet var imu_acc_y: UITextView!
//    @IBOutlet var imu_acc_z: UITextView!
    
//    @IBOutlet var imu_gyro_x: UITextView!
//    @IBOutlet var imu_gyro_y: UITextView!
//    @IBOutlet var imu_gyro_z: UITextView!
    
    @IBOutlet var imu_motion_roll: UITextView!
    @IBOutlet var imu_motion_pitch: UITextView!
    @IBOutlet var imu_motion_yaw: UITextView!
    
    @IBOutlet var magnetic_heading: UITextView!
    
    @IBOutlet var btn_start: UIButton!
    @IBOutlet var btn_finish: UIButton!
    
    @IBOutlet var label_recording: UILabel!
    var IS_RECORDING: Bool! = false
    
    var motionManager:CMMotionManager!
    var locManager:CLLocationManager!
    
    var moveArr: Array<Array<Double>>!
    var startDateTime: String!
    var startTimeStamp: Int!
    var finishDateTime: String!
    var finishTimeStamp: Int!
    
    var err: NSError? = nil
    
    // video part
    @IBOutlet var camView: UIView!
    
    var captureSession = AVCaptureSession()
    var previewLayer = AVCaptureVideoPreviewLayer()
    var videoFileOutput = AVCaptureMovieFileOutput()
    
    override func viewWillAppear(_ animated: Bool) {
        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        
        let deviceDiscoverySession = AVCaptureDeviceDiscoverySession(deviceTypes: [AVCaptureDeviceType.builtInDualCamera, AVCaptureDeviceType.builtInTelephotoCamera, AVCaptureDeviceType.builtInWideAngleCamera], mediaType: AVMediaTypeVideo, position: AVCaptureDevicePosition.unspecified)
        
        for device in (deviceDiscoverySession?.devices)! {
            if(device.position == AVCaptureDevicePosition.back){
                print("debug: found back camera")
                if (device.hasMediaType(AVMediaTypeVideo)) {
                    print("debug: can shoot video")
                    beginSession(captureDevice: device)
                }
            }
        }
    }
    
    func beginSession(captureDevice: AVCaptureDevice) {
        do {
            try captureSession.addInput(AVCaptureDeviceInput(device: captureDevice))
        } catch {
            print("jsnh: failed to add input from device")
        }
        print("debug: started session")
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        previewLayer.connection.videoOrientation = AVCaptureVideoOrientation.portrait
        previewLayer.frame = self.camView.layer.frame
        self.camView.layer.addSublayer(previewLayer)
        self.camView.bringSubview(toFront: self.imu_motion_yaw)
        self.camView.bringSubview(toFront: self.imu_motion_roll)
        self.camView.bringSubview(toFront: self.imu_motion_pitch)
        self.camView.bringSubview(toFront: self.magnetic_heading)
        self.camView.bringSubview(toFront: self.btn_start)
        self.camView.bringSubview(toFront: self.btn_finish)
        self.camView.bringSubview(toFront: self.label_recording)
    }
    
    func recordVideo() {
        let data_file = self.startDateTime + "video.mp4"
        
        let recordDelegate:AVCaptureFileOutputRecordingDelegate? = self
        
        self.captureSession.addOutput(videoFileOutput)
        
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            
            let data_path = dir.appendingPathComponent(data_file)
            
            videoFileOutput.startRecording(toOutputFileURL: data_path, recordingDelegate: recordDelegate)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // initialize IS_RECORDING and hide recording label
        self.IS_RECORDING = false
        self.label_recording.isHidden = true
        
        // camera starts refressing
        self.captureSession.startRunning()
        
        self.motionManager = CMMotionManager()
        self.locManager = CLLocationManager()
        
        self.moveArr = [[Double]]()
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func stopUpdates() {
        //        self.motionManager.stopAccelerometerUpdates()
        //        self.motionManager.stopGyroUpdates()
        self.motionManager.stopDeviceMotionUpdates()
        self.locManager.stopUpdatingHeading()
    }
    
    func startUpdates() {
        //        self.motionManager.accelerometerUpdateInterval = 0.2
        //
        //        self.motionManager.startAccelerometerUpdates(to: OperationQueue.current!, withHandler: {_,_ in
        //            if let accelerometerData = self.motionManager.accelerometerData {
        //                self.updateAcc(accelerometerData: accelerometerData)
        //            }
        //        })
        //
        //        self.motionManager.gyroUpdateInterval = 0.1
        //
        //        self.motionManager.startGyroUpdates(to: OperationQueue.current!, withHandler: {_,_ in
        //            if let gyroData = self.motionManager.gyroData {
        //                self.updateGyro(gyroData:gyroData)
        //            }
        //        })
        
        self.motionManager.deviceMotionUpdateInterval = 0.1
        
        self.motionManager.startDeviceMotionUpdates(to: OperationQueue.current!, withHandler: {_,_ in
            if let motionData = self.motionManager.deviceMotion {
                self.updateMotion(motionData: motionData)
            }
        })
        
        self.locManager.delegate = self
        self.locManager.startUpdatingHeading()
        
        print("start")
    }
    
    // MARK: -
    // MARK: CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Manager failed: \(error)")
    }
    
    // Heading readings tend to be widely inaccurate until the system has calibrated itself
    // Return true here allows iOS to show a calibration view when iOS wants to improve itself
    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        return true
    }
    
    // This function will be called whenever your heading is updated. Since you asked for best
    // accuracy, this function will be called a lot of times. Better make it very efficient
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        //        print(newHeading.magneticHeading)
        //        print("hello")
        self.magnetic_heading.text = String(format:"%f", newHeading.magneticHeading)
    }
    
    func updateMotion(motionData:CMDeviceMotion) {
        let x = motionData.userAcceleration.x
        let y = motionData.userAcceleration.y
        let z = motionData.userAcceleration.z
        self.imu_motion_roll.text = String(format:"%f", x)
        self.imu_motion_pitch.text = String(format:"%f", y)
        self.imu_motion_yaw.text = String(format:"%f", z)
        
        // record movement data in the array
        self.moveArr.append([x, y, z])
    }
    
    
    // start updates and record in array
    @IBAction func startRecording(_ sender: AnyObject) {
        // toggle IS_RECORDING and recording label
        self.IS_RECORDING = true
        self.label_recording.isHidden = false
        
        // make sure previous data all removed
        self.moveArr.removeAll()
        self.startDateTime = Date().iso8601
        self.startTimeStamp = Int(Date().timeIntervalSince1970)
        
        // start imu recording
        self.startUpdates()
        
        // start videoRecording
        self.recordVideo()
    }
    
    func prepCSV()-> String {
        var str = ""
        for row in self.moveArr {
            for i in 0 ... 2 {
                if (i < 2) {
                    str += String(row[i]) + ","
                } else {
                    str += String(row[i])
                }
            }
            str += "\n"
        }
        return str
    }
    
    // stop updates, export data and extra info to a pair of files, clear array
    @IBAction func exportData(_ sender: AnyObject) {
        if (self.IS_RECORDING!) {
            self.finishDateTime = Date().iso8601
            self.finishTimeStamp = Int(Date().timeIntervalSince1970)
            
            // stop video recording
            self.videoFileOutput.stopRecording()
            
            // stop imu updates
            self.stopUpdates()
            
            // write to file, comment if testing functionality
            self.writeToFile()
        
            // clear movedata after exporting
            self.moveArr.removeAll()
            
            // toggle IS_RECORDING and label
            self.IS_RECORDING = false
            self.label_recording.isHidden = true
        }
    }
    
    // actually write data to appFiles
    func writeToFile() {
        let data_file = self.startDateTime + "X" + finishDateTime + "data.csv" //this is the data file.
        let info_file = self.startDateTime + "X" + finishDateTime + "info.txt" //this is the extra info file.
        
        let info = String(startTimeStamp) + "," + String(finishTimeStamp)
        
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            
            let data_path = dir.appendingPathComponent(data_file)
            
            //writing data
            do {
                try prepCSV().write(to: data_path, atomically: false, encoding: String.Encoding.utf8)
            }
            catch {/* error handling here */}
            
            let info_path = dir.appendingPathComponent(info_file)
            
            //writing data
            do {
                try info.write(to: info_path, atomically: false, encoding: String.Encoding.utf8)
            }
            catch {/* error handling here */}
        }
    }
    
    // functions for AVCaptureFileOutputRecordingDelegate protocols
    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        return
    }
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        return
    }
}



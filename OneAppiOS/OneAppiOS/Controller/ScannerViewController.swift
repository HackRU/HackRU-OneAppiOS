//
//  ScannerViewController.swift
//  OneAppiOS
//
//  Created by Qasim Abbas on 4/15/18.
//  Copyright © 2018 Qasim Abbas. All rights reserved.
//

import UIKit
import AVFoundation
import QRCodeReader
import MaterialComponents
import Alamofire
import SwiftyJSON
import Firebase

class ScannerViewController: UIViewController, QRCodeReaderViewControllerDelegate {
    @IBOutlet weak var changeScanning: MDCRaisedButton!
    var ref: DatabaseReference!
    @IBOutlet weak var lblStatus: UILabel!
    var scanning : String?
    var scanParam: [String: AnyObject]?
    var state: Int?
    var email: String?
    
    @IBOutlet weak var btnScanner: MDCRaisedButton!
    @IBOutlet weak var btnScan: UILabel!
    
    @IBOutlet weak var previewView: QRCodeReaderView! {
        didSet {
            previewView.setupComponents(showCancelButton: false, showSwitchCameraButton: false, showTorchButton: false, showOverlayView: true, reader: reader)
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        btnScanner.tintColor = .white
        btnScanner.backgroundColor = HackRUColor.lightBlue
        btnScanner.titleLabel?.textColor = .white
        
        changeScanning.tintColor = .white
        changeScanning.backgroundColor = HackRUColor.lightBlue
        changeScanning.titleLabel?.textColor = .white
        
        self.btnScanner.isHidden = true
        
        
    }
    
    
    lazy var reader: QRCodeReader = QRCodeReader()
    lazy var readerVC: QRCodeReaderViewController = {
        let builder = QRCodeReaderViewControllerBuilder {
            $0.reader = QRCodeReader(metadataObjectTypes: [.qr], captureDevicePosition: .back)
        }
        
        return QRCodeReaderViewController(builder: builder)
    }()

    // MARK: - QRCodeReaderViewController Delegate Methods
    
    func reader(_ reader: QRCodeReaderViewController, didScanResult result: QRCodeReaderResult) {
        reader.stopScanning()
        
        dismiss(animated: true, completion: nil)
    }
    
    //This is an optional delegate method, that allows you to be notified when the user switches the cameraName
    //By pressing on the switch camera button
//    func reader(_ reader: QRCodeReaderViewController, didSwitchCamera newCaptureDevice: AVCaptureDeviceInput) {
//        if let cameraName = newCaptureDevice.device.localizedName {
//            print("Switching capturing to: \(cameraName)")
//        }
//    }
    
    func readerDidCancel(_ reader: QRCodeReaderViewController) {
        reader.stopScanning()
        
        dismiss(animated: true, completion: nil)
    }
    
    private func checkScanPermissions() -> Bool {
        do {
            return try QRCodeReader.supportsMetadataObjectTypes()
        } catch let error as NSError {
            let alert: UIAlertController
            
            switch error.code {
            case -11852:
                alert = UIAlertController(title: "Error", message: "This app is not authorized to use Back Camera.", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Setting", style: .default, handler: { (_) in
                    DispatchQueue.main.async {
                        if let settingsURL = URL(string: UIApplicationOpenSettingsURLString) {
                            UIApplication.shared.open(settingsURL, options: ["Open Settings": "Open"], completionHandler: nil)
                        }
                    }
                }))
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            default:
                alert = UIAlertController(title: "Error", message: "Reader not supported by the current device", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            }
            
            present(alert, animated: true, completion: nil)
            
            return false
        }
    }
    
    func apiCall(userString: String, dictUpdate: [String: [String: AnyObject]]){
        let jsonObject: NSMutableDictionary = NSMutableDictionary()
        var jsonData: Data = Data()

        //print("TOKEN \(user.value(forKey: "auth") ?? "NONE")")
        
        jsonObject.setValue(userString, forKey: "user_email")
        jsonObject.setValue(UserDefaults.standard.object(forKey: "email") as! String, forKey: "auth_email")
        jsonObject.setValue(UserDefaults.standard.object(forKey: "auth") as! String, forKey: "auth")
        
        //jsonObject.setValue(["email": userString], forKey: "query")
        
        jsonObject.setValue(dictUpdate, forKey: "updates")
        
        do {
            jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: JSONSerialization.WritingOptions()) as Data
            let jsonString = NSString(data: jsonData , encoding: String.Encoding.utf8.rawValue)! as String
            print("json string = \(jsonString)")
        } catch _ {
            print ("JSON Failure")
        }

        var request = URLRequest(url: URL(string: baseURL + "/update")!)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        Alamofire.request(request).responseJSON { (response) in
            let swiftJson = JSON(response.result.value!)
                print(swiftJson)
            
            if let statusCode = swiftJson["statusCode"].int {
                if(statusCode == 200){
                    
                    if let body = swiftJson["body"].string{
                        print(body)
                        
                           self.scanInPreviewAction((Any).self)
                    }
                }else{
                    self.previewView.layer.borderWidth = 5
                    self.previewView.layer.borderColor = UIColor.red.cgColor
                    
                    
                    let alert = UIAlertController(title: "Error", message: swiftJson.description, preferredStyle: .alert)
                    
                    
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {item in
                        self.scanInPreviewAction((Any).self)
                        
                    }))
                    
                    self.present(alert, animated: true, completion: nil)
                    
                }
                
                
            }
        }

    }
    
    
    func printQR(printEmail: String){
        let url: String = "https://labels.hackru.org/\(printEmail)"
    
        Alamofire.request(url).responseJSON { response in
            
            switch response.result{
            case .success:
                
                print("SUCCESS SOMETHING SOMETHING")
                let swiftJson = JSON(response.result.value!)
                
                    if(swiftJson["statusCode"].int == 200){
                        
                        print(printEmail)
                        self.apiCall(userString: printEmail, dictUpdate: ["$set": ["registration_status": "check-in" as AnyObject, "day_of.checked_in": true as AnyObject]])
                        
                    }else{
                        let alert = UIAlertController(title: "Error Printing \(printEmail)", message: swiftJson.description, preferredStyle: .alert)
                        
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {item in
                            //self.scanInPreviewAction((Any).self)
                            self.scanInPreviewAction((Any).self)
                            
                        }))
                        
                        self.present(alert, animated: true, completion: nil)
                    }
                
            case .failure:
                    let alert = UIAlertController(title: "Error Printing \(printEmail)", message: " Error Connecting to Label Printer", preferredStyle: .alert)
                    
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: {item in
                        //self.scanInPreviewAction((Any).self)
                        self.scanInPreviewAction((Any).self)
                        
                    }))
                
                    self.present(alert, animated: true, completion: nil)
            }

        }
    }
    
    
    func checkIn(email: String){
        let jsonObject = NSMutableDictionary()
        var jsonData: Data = Data()
        
        jsonObject.setValue(UserDefaults.standard.object(forKey: "auth") as! String, forKey: "auth")
        jsonObject.setValue(UserDefaults.standard.object(forKey: "email") as! String, forKey: "email")
        jsonObject.setValue(["email": email], forKey: "query")
        
        do {
            jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: JSONSerialization.WritingOptions()) as Data
            let jsonString = NSString(data: jsonData , encoding: String.Encoding.utf8.rawValue)! as String
            print("json string = \(jsonString)")
        } catch _ {
            print ("JSON Failure")
        }
        
        var request = URLRequest(url: URL(string: baseURL + "/read")!)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        
        
        Alamofire.request(request).responseJSON { (response) in
            let swiftJson = JSON(response.result.value!)
            
            print(swiftJson.description)
          //  let stringJson = swiftJson.description
            
            if let body = JSON(response.result.value!)["body"].array {
                for item in body {
                    let day_of = item["day_of"].dictionary
                    
                    let checked = day_of!["checked_in"]?.bool ?? false
                            print("CHECKED STATUS: \(checked)")
                    
                    self.ref = Database.database().reference()
                    self.ref.observe(.value, with: { snapshot in
                       // print(snapshot.value!)
                         let swiftJson = JSON(snapshot.value!)
                        if let allowOnlyAccepted = swiftJson["allowOnlyAccepted"].bool {
                            if(item["registration_status"].string == "coming" || !allowOnlyAccepted == true){
                                if (checked == true) {
                                    
                                    let alert = UIAlertController(title: "Already Checked In", message: "AHOY MATE \(email) ye be checked in", preferredStyle: .alert)
                                    
                                    alert.addAction(UIAlertAction(title: "Print QR Again", style: .default, handler: {item in
                                        
                                        self.printQR(printEmail: email)
                                        print("print")
                                        
                                    }))
                                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: {item in
                                        
                                        self.scanInPreviewAction((Any).self)
                                    }))
                                    
                                    self.present(alert, animated: true, completion: nil)
                                    
                                }else{
                                    
                                    print("HEADING TO PRINT")
                                    self.printQR(printEmail: email)
                                    
                                }
                            }else{
                                let alert = UIAlertController(title: "Waitlist checkin has not opened up yet! \(email)", message: "Only people who are marked as coming are being scanned at the moment,Accepted and Coming is Being Checked In ", preferredStyle: .alert)
                                

                                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: {item in
                                    
                                    self.scanInPreviewAction((Any).self)
                                }))
                                
                                self.present(alert, animated: true, completion: nil)
                                
                            }
                        }
                    })
                    
             
                }
            }
            
        
            
            print("FIRST TIME CHECKIN")
        }
        
    }

    
    @IBAction func changeBtnAction(_ sender: Any) {
        let alert = UIAlertController(title: "Change Scanner", message: "Select what you are scanning for", preferredStyle: .actionSheet)
       
        alert.addAction(UIAlertAction(title: "Check-In", style: .default, handler: {item in
            self.btnScan.text = "Scanning For: Check-In"
            self.scanInPreviewAction((Any).self)
            self.state = 0
        }))
        
        alert.addAction(UIAlertAction(title: "Lunch 1", style: .default, handler: {item in
            self.btnScan.text = "Scanning For: Lunch 1"
            self.scanInPreviewAction((Any).self)
            self.state = 1
        }))
        
        alert.addAction(UIAlertAction(title: "Dinner", style: .default, handler: {item in
            self.btnScan.text = "Scanning For: Dinner"
            self.scanInPreviewAction((Any).self)
            self.state = 2
        }))
        
        alert.addAction(UIAlertAction(title: "Midnight Surprise", style: .default, handler: {item in
            self.btnScan.text = "Scanning For: Midnight Surprise"
            self.scanInPreviewAction((Any).self)
            self.state = 3
        }))
        
        alert.addAction(UIAlertAction(title: "T-Shirt", style: .default, handler: {item in
             self.btnScan.text = "Scanning For: T-Shirt"
            self.scanInPreviewAction((Any).self)
            self.state = 4
        }))
        
        alert.addAction(UIAlertAction(title: "Breakfast", style: .default, handler: {item in
             self.btnScan.text = "Scanning For: Breakfast"
            self.scanInPreviewAction((Any).self)
            self.state = 5
        }))
        
        alert.addAction(UIAlertAction(title: "Lunch 2", style: .default, handler: {item in
             self.btnScan.text = "Scanning For: Lunch 2"
             self.scanInPreviewAction((Any).self)
            self.state = 6
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
        
        
        
    }
    
    
    
    @IBAction func scanInPreviewAction(_ sender: Any) {
        guard checkScanPermissions(), !reader.isRunning else { return }
        
        reader.didFindCode = { result in
            self.previewView.layer.borderWidth = 5
            self.previewView.layer.borderColor = UIColor.green.cgColor
           
            
            print("Completion with result: \(result.value) of type \(result.metadataType)")
            
            //self.apiCall(userString: result.value)
            
            switch self.state {
            case 0:
                
                self.checkIn(email: result.value)
                break
            case 1:
                self.apiCall(userString: result.value, dictUpdate: ["$inc": ["registration_status": "check-in" as AnyObject, "day_of.lunch_1": 1 as AnyObject]])
                break
            case 2:
                self.apiCall(userString: result.value, dictUpdate: ["$inc": ["registration_status": "check-in" as AnyObject, "day_of.day_of.dinner": 1 as AnyObject]])
                break
            case 3:
                self.apiCall(userString: result.value, dictUpdate: ["$inc": ["registration_status": "check-in" as AnyObject, "day_of.midnight_suprise": 1 as AnyObject]])
                break
            case 4:
                self.apiCall(userString: result.value, dictUpdate: ["$inc": ["registration_status": "check-in" as AnyObject, "day_of.t_shirt": 1 as AnyObject]])
                break
            case 5:
                self.apiCall(userString: result.value, dictUpdate: ["$inc": ["registration_status": "check-in" as AnyObject, "day_of.breakfast": 1 as AnyObject]])
                break
            case 6:
                self.apiCall(userString: result.value, dictUpdate: ["$inc": ["registration_status": "check-in" as AnyObject, "day_of.lunch_2": 1 as AnyObject]])
                break
            default:
                break
            }
            
        }
        self.previewView.layer.borderWidth = 0
        self.previewView.layer.borderColor = UIColor.green.cgColor
        self.lblStatus.text = ""
        reader.startScanning()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        reader.stopScanning()
    }
}


//    @IBAction func scanAction(_ sender: AnyObject) {
//        // Retrieve the QRCode content
//        // By using the delegate pattern
//        readerVC.delegate = self
//
//        // Or by using the closure pattern
//        readerVC.completionBlock = { (result: QRCodeReaderResult?) in
//            print(result ?? "none")
//        }
//
//        // Presents the readerVC as modal form sheet
//        readerVC.modalPresentationStyle = .formSheet
//        present(readerVC, animated: true, completion: nil)
//    }

//    func getUserAuth(userString: String) -> String{
//        let jsonObject: NSMutableDictionary = NSMutableDictionary()
//        var jsonData: Data = Data()
//
//        //print("TOKEN \(user.value(forKey: "auth") ?? "NONE")")
//
//        jsonObject.setValue(UserDefaults.standard.object(forKey: "auth") as! String, forKey: "auth")
//        jsonObject.setValue(UserDefaults.standard.object(forKey: "email") as! String, forKey: "email")
//        jsonObject.setValue(["email": userString], forKey: "query")
//
//        do {
//            jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: JSONSerialization.WritingOptions()) as Data
//            let jsonString = NSString(data: jsonData , encoding: String.Encoding.utf8.rawValue)! as String
//            print("json string = \(jsonString)")
//        } catch _ {
//            print ("JSON Failure")
//        }
//
//        var request = URLRequest(url: URL(string: baseURL + "/read")!)
//        request.httpMethod = HTTPMethod.post.rawValue
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.httpBody = jsonData
//
//
//
//        Alamofire.request(request).responseJSON { (response) in
//
//            //print(swiftJsonVar)
//
//            if let body = JSON(response.result.value!)["body"].array {
//
//                print(body)
//
//                for item in body {
//
//                }
//            }
//        }
//
//        return ""
//    }

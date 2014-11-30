//
//  ViewController.swift
//  OreOre Kintai
//
//  Created by tinpay on 2014/11/24.
//  Copyright (c) 2014年 ChatWork. All rights reserved.
//


import UIKit
import Foundation
import CoreLocation

class ViewController: UIViewController, CLLocationManagerDelegate{

    
    @IBOutlet weak var timeLabel: UILabel!
    

    let proximityUUID = NSUUID(UUIDString:"<proximity UUID>")
    let chatworkToken = "<ChatWork AccessToken>"
    
    let flatBlueColor:UIColor = UIColor(red: 0.1607843137254902, green: 0.5019607843137255, blue: 0.7254901960784313, alpha: 1.0)
    let flatGreyColor:UIColor = UIColor(red: 0.5843137254901961, green: 0.6470588235294118, blue: 0.6509803921568628, alpha: 1.0)
    
    var dateFormatter = NSDateFormatter()
    var region  = CLBeaconRegion()
    var manager = CLLocationManager()

    enum BeaconDistance {
        case Unknown
        case Immediate
        case Near
        case Far
        
    }
    var beaconDistance : BeaconDistance = BeaconDistance.Unknown
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: Selector("onTimer"), userInfo: nil, repeats: true)

        self.dateFormatter.dateStyle = NSDateFormatterStyle.MediumStyle
        self.dateFormatter.timeStyle = NSDateFormatterStyle.MediumStyle
        
        self.changeScreenColor()
        
        
        
        if (CLLocationManager.isMonitoringAvailableForClass(CLCircularRegion)) {
            self.manager.delegate = self
            self.region = CLBeaconRegion(proximityUUID:proximityUUID,identifier:"com.chatwork.OreKin")
            self.manager.startMonitoringForRegion(self.region)
        } else {
            //iBeaconが使えないiOSや端末の場合
        }
        
        
        switch CLLocationManager.authorizationStatus() {
        case .Authorized, .AuthorizedWhenInUse:
            self.manager.startRangingBeaconsInRegion(self.region)
        case .NotDetermined:
            if(self.manager.respondsToSelector("requestAlwaysAuthorization")) {
                self.manager.requestAlwaysAuthorization()
            }else{
                self.manager.startRangingBeaconsInRegion(self.region)
            }
        case .Restricted, .Denied:
            break
        default:
            break
        }
        
        
    }
    
    
    //MARK: - CLLocationManagerDelegate method
    
    func locationManager(manager: CLLocationManager!, didStartMonitoringForRegion region: CLRegion!) {
        NSLog("start monitoring.")
        manager.requestStateForRegion(region)
    }
    
    func locationManager(manager: CLLocationManager!, didDetermineState state: CLRegionState, forRegion inRegion: CLRegion!) {
        NSLog("determine state.")
        
        switch (state) {
        case .Inside:
            NSLog("Region State : inside");
            self.startRangingBeaconsforRegion(inRegion)
            break;
        case .Outside:
            NSLog("Region State : outside");
            break;
        case .Unknown:
            NSLog("Region State : unknown");
            break;
        default:
            break;
        }
    }
    
    
    func locationManager(manager: CLLocationManager!, monitoringDidFailForRegion region: CLRegion!, withError error: NSError!) {
        NSLog("monitoringDidFailForRegion \(error)")
    }
    
    //通信失敗
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        NSLog("didFailWithError \(error)")
    }
    
    func locationManager(manager: CLLocationManager!, didEnterRegion region: CLRegion!) {
        self.startRangingBeaconsforRegion(region)
        self.postChatWorkToMyChat("出勤しました(F)")
    }
    
    func locationManager(manager: CLLocationManager!, didExitRegion region: CLRegion!) {
        manager.stopRangingBeaconsInRegion(region as CLBeaconRegion)
        self.postChatWorkToMyChat("退勤しました(beer)")
    }
    
    func locationManager(manager: CLLocationManager!, didRangeBeacons beacons: NSArray!, inRegion region: CLBeaconRegion!) {
        println(beacons)
        
        if(beacons.count == 0) {
            return
        }
        //一つ目
        var beacon = beacons[0] as CLBeacon
        
        switch (beacon.proximity){
        case .Unknown:
            self.beaconDistance = BeaconDistance.Unknown
        case .Immediate:
            self.beaconDistance = BeaconDistance.Immediate
        case .Near:
            self.beaconDistance = BeaconDistance.Near
        case .Far:
            self.beaconDistance = BeaconDistance.Far
        }
        
        self.changeScreenColor()
        
    }
    
    //MARK: - for timer method
    func onTimer(){
        self.timeLabel.text = self.dateFormatter.stringFromDate(NSDate())
    }

    
    
    //MARK: - private method
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func startRangingBeaconsforRegion(inRegion: CLRegion!){
        if(inRegion.isMemberOfClass(CLBeaconRegion) && CLLocationManager .isRangingAvailable()){
            manager.startRangingBeaconsInRegion(self.region)
        }
        
    }
    func changeScreenColor() {
        var color:UIColor
        if self.beaconDistance == BeaconDistance.Immediate || self.beaconDistance == BeaconDistance.Near || self.beaconDistance == BeaconDistance.Far{
            color = flatBlueColor
        }else{
            color = flatGreyColor
        }
        
        self.view.backgroundColor = color
        self.timeLabel.textColor = UIColor.whiteColor()
        
    }
    
    
    func localNotificate(message : String) {
        var notification : UILocalNotification = UILocalNotification()
        notification.fireDate = NSDate()
        notification.timeZone = NSTimeZone.defaultTimeZone()
        notification.alertBody = message
        notification.alertAction = "OK"
        notification.soundName = UILocalNotificationDefaultSoundName
        UIApplication.sharedApplication().scheduleLocalNotification(notification)
        
    }
    
    func postChatWorkToMyChat(msg : String){
        
        let postMsg = "\(msg) (" + self.dateFormatter.stringFromDate(NSDate()) + ")"
        
        let request  = NSURLRequest(URL:NSURL(string: "https://api.chatwork.com/v1/rooms")!)
        
        var configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.HTTPAdditionalHeaders = ["X-ChatWorkToken" : self.chatworkToken]
        
        let session = NSURLSession(configuration: configuration)
        var task = session.dataTaskWithRequest(request){
            (data, response, error) -> Void in
            if error == nil {
                var error:NSError?
                let rooms = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: &error) as NSArray
                rooms.enumerateObjectsUsingBlock({
                    (room, idx, stop) -> Void in
                    let roomtype = room["type"]! as String
                    let roomid = room["room_id"]! as Int
                    if (roomtype == "my") {
                        //マイチャットの場合
                        var urlstring  = "https://api.chatwork.com/v1/rooms/" + String(roomid) + "/messages"
                        var requestMessage  = NSMutableURLRequest(URL:NSURL(string: urlstring)!)
                        requestMessage.HTTPMethod = "POST"
                        let params:String = "body=\(postMsg)"
                        requestMessage.HTTPBody = params.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)

                        var taskMessage = session.dataTaskWithRequest(requestMessage){
                            (data, response, er) -> Void in
                            
                            var error:NSError?
                            let arr = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: &error) as NSDictionary
                            //いろいろ処理
                            
                            
                            
                            self.localNotificate(postMsg)

                            
                        }
                        taskMessage.resume()
                    }
                })
            }
        }
        task.resume()
        
    }
    
    
    
}

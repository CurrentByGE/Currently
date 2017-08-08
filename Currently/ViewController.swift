//
//  ViewController.swift
//  Currently
//
//  Created by Joseph Sirak on 7/21/17.
//  Copyright © 2017 Joseph Sirak. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController, UISearchBarDelegate, CLLocationManagerDelegate, MKMapViewDelegate {

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        getClientToken()
        
       
    }
    
    @IBOutlet weak var map: MKMapView!
    
    
    var pkincalled = false
    var pkoutcalled = false
    var clientTkn : String!
    var metadataurl = "https://ic-metadata-service.run.aws-usw02-pr.ice.predix.io/v2/metadata" as String
    var eventurl = "https://ic-event-service.run.aws-usw02-pr.ice.predix.io/v2/" as String
    var prevLocation : String!
    var predixZoneId:String = "SDSIM-IE-PARKING"
    var locationDict = [String : CLLocationCoordinate2D]()
    var circles = [String: MKCircle]()
    var startTime:Int64 = 1499644800000
    var endTime:Int64 = 1499714983000
    
    let manager = CLLocationManager()
    
    @IBAction func timeSelector(_ sender: Any) {
        let selectedTime = UIDatePicker().date.description
        let timeSelected = selectedTime.components(separatedBy: " ")[1].components(separatedBy: ":")
        endTime = (Int64(timeSelected[0])!)*3600*1000 + Int64(timeSelected[1])!*60*1000 + Int64(timeSelected[2])!*1000 + startTime
        
        self.map.removeOverlays(Array(self.circles.values))
        print(endTime)
        getAllPEDCount()
        
        }
    @IBAction func search(_ sender: Any) {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchBar.delegate = self
        present(searchController, animated: true, completion: nil)
    }
    
    func getbbox() -> String{
        let mRect:MKMapRect = self.map.visibleMapRect;
        let seMapPoint:MKMapPoint = MKMapPointMake(MKMapRectGetMaxY(mRect), MKMapRectGetMaxY(mRect))
        let nwMapPoint:MKMapPoint = MKMapPointMake(mRect.origin.x, mRect.origin.y);
        let seCoord:CLLocationCoordinate2D = MKCoordinateForMapPoint(seMapPoint);
        let nwCoord:CLLocationCoordinate2D = MKCoordinateForMapPoint(nwMapPoint);
        let bbox = "\(nwCoord.latitude):\(nwCoord.longitude), \(seCoord.latitude):\(seCoord.longitude)"
        return bbox
    }
    
    func getAllPEDCount() -> Void{
        
        let pedUrl:String = self.eventurl + "/locations/events?eventType=PEDEVT&bbox=90:180,-90:-180&locationType=WALKWAY&startTime=\(startTime)&endTime=\(endTime)"
        let clientToken = "Bearer " + self.clientTkn
        var requestPed = URLRequest(url: URL.init(string: pedUrl)!)
        requestPed.setValue(clientToken, forHTTPHeaderField: "Authorization")
        requestPed.setValue("SDSIM-IE-PEDESTRIAN", forHTTPHeaderField: "Predix-Zone-Id")
        let taskIn = URLSession.shared.dataTask(with:requestPed){
            (data, response, error) in
            if(error != nil){
                print("error @ped call : ", error!.localizedDescription)
            } else {
                do{
                    
                    if let json2=try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String: Any]{
                        
                        DispatchQueue.main.sync {
                            let contents:[[String:Any]] = json2["content"] as! [[String: Any]]
                        
                            for content in contents{
                                let locationUid:String = (content["locationUid"] as? String!)!
                                let measure:[String:Any] = (content["measures"] as? [String:Any]!)!
                                let pedCount:Int = (measure["pedestrianCount"] as? Int!)!
                                let coordinate:CLLocationCoordinate2D = self.locationDict[locationUid]!
                                self.drawCircle(pedCount, coordinate: coordinate, locationId: locationUid)
                                
                            }
                        
                            self.map.addOverlays(Array(self.circles.values))

                        }
                    }
                }catch{
                    print("Error with the Json Serialization")
                }
            }
        }
        taskIn.resume()
    }
    
    func getAllLocationIds() -> Void{
        let requestALLUrl:String = self.metadataurl + "/locations/search?q=locationType:WALKWAY&bbox=90:180,-90:-180&page=0&size=200"
        let clientToken = "Bearer " + self.clientTkn
        var request = URLRequest(url: URL.init(string: requestALLUrl)!)
        request.setValue(clientToken, forHTTPHeaderField: "Authorization")
        request.setValue(predixZoneId, forHTTPHeaderField: "Predix-Zone-Id")
        let task = URLSession.shared.dataTask(with: request){ (data, response, error) in
            if(error != nil){
                print ("error : ", error!.localizedDescription)
            } else {
                do{
                    if let json=try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String: Any]
                    {
                        DispatchQueue.main.sync {
                            let contents:[[String:Any]] = json["content"] as! [[String: Any]]
                        
                            for content in contents{
                                let locationUid:String = (content["locationUid"] as? String!)!
                                let coordinates:String = (content["coordinates"] as? String!)!
                                var coord = coordinates.components(separatedBy: ",")
                                let coord1:[String] = coord[0].components(separatedBy: ":")
                                let coord2: [String] = coord[0].components(separatedBy: ":")
                                let lat1:Double = Double(coord1[0])!
                                let lat2:Double = Double(coord2[0])!
                                let long1:Double = Double(coord1[1])!
                                let long2:Double = Double(coord2[1])!
                                let loc_coord:CLLocationCoordinate2D = CLLocationCoordinate2DMake((lat1 + lat2)/2, (long1 + long2)/2)
                                self.locationDict[locationUid] = loc_coord
                            }
                            self.getAllPEDCount()

                        }
                        
                    }
                }catch{
                    print("Error with the Json Serialization.")
                }
            }
        }
        task.resume()
        
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        //Ignoring User
        UIApplication.shared.beginIgnoringInteractionEvents()
        manager.stopUpdatingLocation()
        //Activity Indicator
        let activityIndicator = UIActivityIndicatorView()
        activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
        activityIndicator.center = self.view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()
        activityIndicator.stopAnimating()
    
        
        // hide Searching bar
        self.view.addSubview(activityIndicator)
        searchBar.resignFirstResponder()
        dismiss(animated: true, completion: nil)
        UIApplication.shared.endIgnoringInteractionEvents()
        
        //Searching
        let searchRequest = MKLocalSearchRequest()
        searchRequest.naturalLanguageQuery = searchBar.text
        
        let activeSearch = MKLocalSearch(request: searchRequest)
        activeSearch.start{ (response, error) in
            if response == nil
            {
                print("ERROR")
                
            }
            else
            {
                //Get the data
                let latitude = response?.boundingRegion.center.latitude
                let longtiude = response?.boundingRegion.center.longitude
                let annotation = MKPointAnnotation()
                annotation.title = searchBar.text
                annotation.coordinate = CLLocationCoordinate2DMake(latitude!, longtiude!)
                
                self.map.addAnnotation(annotation)
                
                let coordinate:CLLocationCoordinate2D = CLLocationCoordinate2DMake(latitude!, longtiude!)
                let span = MKCoordinateSpanMake(0.085, 0.085)
                let region  = MKCoordinateRegionMake(coordinate, span)
                self.map.setRegion(region, animated: true)
            }
        }
        
    }
    
    
    func locationManager(_ manger: CLLocationManager, didUpdateLocations locations:[CLLocation]){
        let location = locations[0]
        let span:MKCoordinateSpan = MKCoordinateSpanMake(0.01, 0.01)
        let myLocation:CLLocationCoordinate2D = CLLocationCoordinate2DMake(location.coordinate.latitude, location.coordinate.longitude)
        let region:MKCoordinateRegion = MKCoordinateRegionMake(myLocation, span)
        map.setRegion(region, animated: true)
        self.map.showsUserLocation = true
        
    }
    
    @IBAction func locate(_ sender: Any) {
        manager.startUpdatingLocation()
    }
    
    // getting oauth info and the rest URLs
    func getClientToken(){
       
        let config = URLSessionConfiguration.default // Session Configuration
        let session = URLSession(configuration: config) // Load configuration into Session
        // let url =
        var request = URLRequest(url: URL(string: "https://890407d7-e617-4d70-985f-01792d693387.predix-uaa.run.aws-usw02-pr.ice.predix.io/oauth/token?grant_type=client_credentials" )!)
        //request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic ZGlnaXRhbGludGVybjpAZGlnaXRhbGludGVybg==", forHTTPHeaderField: "Authorization")
        request.setValue("digitalintern", forHTTPHeaderField: "Username")
        request.setValue("@digitalintern", forHTTPHeaderField: "Password")
       
        let task = session.dataTask(with: request, completionHandler: {
            
            (data, response, error) in
            if error != nil {
                print("error : ",error!.localizedDescription)
            } else {
                do {
                    
                    if let json = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String: Any]
                    {
                        DispatchQueue.main.sync {
                            self.clientTkn = json["access_token"] as! String?
                            self.getAllLocationIds()
                        }
                        
                    }
                    
                } catch {
                    print("error in JSONSerialization")
                }
                
            }
        })
        task.resume()
        
    }

    
    func drawCircle(_ pedCount:Int, coordinate:CLLocationCoordinate2D, locationId:String){
        //print("I drew circle for \(coordinate.latitude), \(coordinate.longitude) for \(pedCount) pedistrians")
        self.map?.delegate = self
        let circle:MKCircle = MKCircle(center: coordinate, radius: CLLocationDistance((pedCount - 20) * 10))
        circles[locationId] = circle
    }
    
    func mapView(_ map: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKCircleRenderer(overlay: overlay)
        renderer.fillColor = UIColor.init(red: 249/255.0, green: 227/255.0, blue: 99/255.0, alpha: 0.4)
        renderer.strokeColor = UIColor.init(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.0)
        renderer.lineWidth = 1
        return renderer
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        
        
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}


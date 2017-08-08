//
//  WebServiceHandler.swift
//  GE Parking
//
//  Created by InsMobility on 10/20/16.
//  Copyright © 2016 Kanaga Karuppasamy. All rights reserved.
//

import UIKit

class WebServiceHandler: NSObject {

    //MARK: - Get Favorite List
    var didSuccessGetFavoriteList:((WebServiceHandler) -> (Void))?
    var didFailureGetFavoriteList:((WebServiceHandler) -> (Void))?
    
    func getFavoritesFromServer(){
        
        let urlSessionConfig : URLSessionConfiguration = URLSessionConfiguration.default
        let session : URLSession = URLSession(configuration: urlSessionConfig)
        
        let url : URL = URL(string: "https://itunes.apple.com/search?meida=music&entity=song&term=apple")!
        let urlRequest : URLRequest = URLRequest(url: url)
        session.dataTask(with: urlRequest) { (data, response, error) in
            
            if let error = error {
                print(error.localizedDescription)
                self.didFailureGetFavoriteList!(self)
            }
            else if (response as? HTTPURLResponse) != nil {
                let httpResponse = response as? HTTPURLResponse
                if httpResponse?.statusCode == 200 {
                    
                    let dict = try! JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers)
                    print("\n\n resop == \(dict) \n\n\n")
                    
                    self.didSuccessGetFavoriteList!(self)
                }
            }
        }.resume()
    }
}

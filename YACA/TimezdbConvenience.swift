//
//  TimezdbConvenience.swift
//  YACA
//
//  Created by Andreas Pfister on 18/12/15.
//  Copyright © 2015 AP. All rights reserved.
//

import Foundation

extension TimezdbClient {
    
    func getTimezoneByCity(cityName: String, completionHandler: (result: Int?, error: NSError?) -> Void) {
        
        let parameters = [
            ParameterKeys.ApiKey : Constants.ApiKey,
            ParameterKeys.Method : Methods.byCityName,
            ParameterKeys.CityName : cityName
        ]
        
        taskForGETMethod(parameters) { JSONResult, error in
            
            if let error = error {
                completionHandler(result: nil, error: error)
            } else {
                print(JSONResult)
            }
            
        }
        
        completionHandler(result: nil, error: nil)
    }
    
}
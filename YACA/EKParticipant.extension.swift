//
//  EKParticipant.extension.swift
//  YACA
//
//  Created by Andreas Pfister on 03/01/16.
//  Copyright © 2016 AP. All rights reserved.
//

import Foundation
import EventKit

// MARK: - Extend class by function which retrieves the Email address from description
extension EKParticipant {
    func getEmail() -> String {
        if let currentParticipant = self as? EKParticipant {
            let descriptionDictionary = currentParticipant.description.componentsSeparatedByString("{")[1].componentsSeparatedByString("}")[0].componentsSeparatedByString("; ")
            var resultDict = [String:String]()
            
            for descriptionComponent in descriptionDictionary {
                let components = descriptionComponent.componentsSeparatedByString(" = ")
                resultDict[components[0]] = components[1]
            }
            return resultDict["email"]!
        } else {
            return ""
        }
    }
}
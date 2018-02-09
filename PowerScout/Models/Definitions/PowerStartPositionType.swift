//
//  PowerStartPositionType.swift
//  PowerScout
//
//  Created by Srinivas Dhanwada on 2/5/18.
//  Copyright © 2018 FRC Team 525. All rights reserved.
//

import Foundation

enum PowerStartPositionType:Int {
    case none = 0
    case exchange
    case center
    case nonExchange
    
    func toString() -> String {
        return (self == .exchange)    ? "Exchange"        :
               (self == .center)      ? "Center"          :
               (self == .nonExchange) ? "Not at Exchange" : "None";
    }
}

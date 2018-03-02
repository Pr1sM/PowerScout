//
//  StrongActionEdit.swift
//  PowerScout
//
//  Created by Srinivas Dhanwada on 3/2/18.
//  Copyright © 2018 FRC Team 525. All rights reserved.
//

import Foundation

struct StrongActionEdit {
    var action:StrongAction
    var index:Int
    var edit:EditType
    
    init(edit:EditType, action:StrongAction, atIndex index:Int) {
        self.edit = edit
        self.action = action
        self.index = index
    }
}

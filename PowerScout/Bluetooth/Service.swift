//
//  Service.swift
//  SteamScout
//
//  Created by Srinivas Dhanwada on 3/18/17.
//  Copyright © 2017 dhanwada. All rights reserved.
//

import Foundation
import CoreBluetooth
import MultipeerConnectivity

enum MatchTransferType {
    case multipeerConnectivity
    case coreBluetooth
}

struct NearbyDevice {
    var displayName: String
    var type: MatchTransferType
    var hash: Int
    var mcInfo: [String:String]
    var mcId: MCPeerID?
}

struct MatchTransferUUIDs {
    static let dataService = CBUUID(string: "816DB342-21B7-4B0B-9D29-863A0981AC4F")
    static let dataCharacteristic = CBUUID(string: "9C781E1C-D5F6-453A-A0BB-0BF37E0DA7EA")
}

enum MatchTransferVersion: String, RawRepresentable {
    
    case invalid
    case v0_1_0
    case v0_1_1
    case v0_2_0
    
    typealias RawValue = String
    
    init?(rawValue: RawValue) {
        switch rawValue {
        case "0.1.0": self = .v0_1_0
        case "0.1.1": self = .v0_1_1
        case "0.2.0": self = .v0_2_0
        default: return nil
        }
    }
    
    var rawValue: RawValue {
        switch self {
        case .v0_1_0: return "0.1.0"
        case .v0_1_1: return "0.1.1"
        case .v0_2_0: return "0.2.0"
        default: return "invalid"
        }
    }
}

struct MatchTransfer {
    static let serviceType = "PwrSct-dataxfer"
    static let localPeerID = MCPeerID(displayName: UIDevice.current.name)
    static var session = MCSession(peer: MatchTransfer.localPeerID, securityIdentity: nil, encryptionPreference: .none)
}

struct MatchTransferDiscoveryInfo {
    static let VersionKey = "kMatchTransferDiscoveryInfoVersionKey"
    static let DeviceName = "KMatchTransferDiscoveryInfoDeviceName"
    static let MatchTypeKey = "kMatchTransferDiscoveryInfo"
    
    static let SendVersion = MatchTransferVersion.v0_1_0.rawValue
}

struct MatchTransferData {
    static let VersionKey = "kMatchTransferDataVersionKey"
    static let MessageKey = "kMatchTransferDataMessageKey"
    static let PayloadKey = "kMatchTransferDataPayloadKey"
    
    static let SendVersion = MatchTransferVersion.v0_1_0.rawValue
}

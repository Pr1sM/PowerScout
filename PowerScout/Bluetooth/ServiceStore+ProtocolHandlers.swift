//
//  ServiceStore+ProtocolHandlers.swift
//  SteamScout
//
//  Created by Srinivas Dhanwada on 8/23/17.
//  Copyright © 2017 dhanwada. All rights reserved.
//

import Foundation
import CoreBluetooth
import MultipeerConnectivity

extension ServiceStore: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("advertiser \(advertiser) did receive invitation from peer \(peerID.displayName) with context \(String(describing: context))")
        proceedWithAdvertising()
        // TEMPORARY -- Should ask user instead
        invitationHandler(true, MatchTransfer.session)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("advertiser \(advertiser) did not start advertising due to error \(error.localizedDescription)")
    }
}

extension ServiceStore: MCNearbyServiceBrowserDelegate {
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        guard let _info = info else {
            print("Discovery Info is null! Bypassing...");
            return
        }
        
        if let version = _info[MatchTransferDiscoveryInfo.VersionKey] {
            print("Found Peer with protocol version: \(version)")
            if let mtVersion = MatchTransferVersion(rawValue: version) {
                switch mtVersion {
                case .v0_1_0:
                    print("Adding peer \(peerID.displayName) (\(String(describing: _info[MatchTransferDiscoveryInfo.DeviceName]))) with type \(String(describing: _info[MatchTransferDiscoveryInfo.MatchTypeKey]))")
                    if !foundNearbyDevices.contains(where: { peerID.hash == $0.hash}) {
                        let newDevice = NearbyDevice(displayName: _info[MatchTransferDiscoveryInfo.DeviceName] ?? "Unknown", type: .multipeerConnectivity, hash: peerID.hash, mcInfo: _info, mcId: peerID, cbPeripheral: nil)
                        foundNearbyDevices.append(newDevice)
                        self.delegate?.serviceStore(self, foundNearbyDevice: newDevice)
                    }
                default:
                    print("Found Peer with invalid version: \(version)! Bypassing...")
                }
            }
        } else {
            print("Found Peer with invalid version key! Bypassing...")
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("Did not start browsing for peers: \(error.localizedDescription)")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        guard let ndIndex = foundNearbyDevices.index(where: {$0.hash == peerID.hash && $0.type == .multipeerConnectivity}) else {
            print("Lost Peer that was not found or was not a MC device! Bypassing...")
            return
        }
        let _info = foundNearbyDevices[ndIndex].mcInfo
        if let version = _info[MatchTransferDiscoveryInfo.VersionKey] {
            print("Lost Peer with protocol version: \(version)")
            if let mtVersion = MatchTransferVersion(rawValue: version) {
                switch mtVersion {
                case .v0_1_0:
                    print("Removing peer \(peerID.displayName) (\(String(describing: _info[MatchTransferDiscoveryInfo.DeviceName]))) with type (\(String(describing: _info[MatchTransferDiscoveryInfo.MatchTypeKey])))")
                    let oldDevice = foundNearbyDevices.remove(at: ndIndex)
                    self.delegate?.serviceStore(self, lostNearbyDevice: oldDevice)
                default:
                    print("Lost Peer with invalid version: \(version)! Bypassing...")
                }
            }
        } else {
            print("Lost Peer with invalid version key! Bypassing...")
        }
    }
}

extension ServiceStore: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let prevState = sessionState
        self.sessionState = state
        self.delegate?.serviceStore(self, withSession: session, didChangeState: state)
        print("MCSession \(session.myPeerID.displayName) with did change state to \(String(describing: state.rawValue))")
        
        if advertising {
            if prevState == .notConnected && state == .connecting {
                proceedWithAdvertising()
            } else if prevState == .connecting && state == .connected {
                proceedWithAdvertising()
            } else if prevState == .connected && state == .connecting {
                goBackWithAdvertising()
            } else if prevState == .connecting && state == .notConnected {
                goBackWithAdvertising()
            } else if prevState == .connected && state == .notConnected {
                proceedWithAdvertising()
            }
        } else if browsing {
            if prevState == .notConnected && state == .connecting {
                proceedWithBrowsing()
            } else if prevState == .connecting && state == .connected {
                proceedWithBrowsing()
            } else if prevState == .connected && state == .connecting {
                goBackWithBrowsing()
            } else if prevState == .connecting && state == .notConnected {
                goBackWithBrowsing()
            } else if prevState == .connected && state == .notConnected {
                proceedWithBrowsing()
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let device = self.foundNearbyDevices.first(where: {$0.hash == peerID.hash}) {
            print("MCSession \(session.myPeerID.displayName) did receive data from peer \(peerID): \(data)")
            if let string = String(data: data, encoding: .utf8) {
                if string.elementsEqual("EOD") {
                    if advertising {
                        proceedWithAdvertising()
                    } else if browsing {
                        proceedWithBrowsing()
                    }
                }
            }
            self.delegate?.serviceStore(self, didReceiveData: data, fromDevice: device)
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print("MCSession \(session.myPeerID.displayName) did receive stream \(streamName) from peer \(peerID.displayName)")
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        print("MCSession \(session.myPeerID.displayName) did start receiving resource with name \(resourceName) from peer \(peerID.displayName) with progress \(progress)")
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        print("MCSession \(session.myPeerID.displayName) did finish receiving resource with name \(resourceName) from peer \(peerID.displayName) at \(String(describing: localURL)) with error \(String(describing: error?.localizedDescription))")
    }
    
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        print("MCSession \(session.myPeerID.displayName) did receive certificate \(String(describing: certificate?.debugDescription)) from peer \(peerID.displayName)")
        certificateHandler(true)
    }
}

extension ServiceStore: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("PeripheralManager State is \(peripheral.state.rawValue)")
        if peripheral.state == .unsupported {
            transferType = .multipeerConnectivity
        } else if peripheral.state == .poweredOn {
            setupCBAdvertisementServices()
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("PeripheralManagerDidStartAdvertising with error \(error.debugDescription)")
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        print("PeripheralManagerIsReadyToUpdateSubscribers")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("PeripheralManager did receive read request \(request.debugDescription)")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        print("PeripheralManager did add service: \(service.debugDescription) with error \(error.debugDescription)")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print("PeripheralManager did receive write requests: \(requests.debugDescription)")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("PeripheralManager central \(central.debugDescription) did subscribe to characteristic \(characteristic.debugDescription)")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("PeripheralManager central \(central.debugDescription) did unsubscribe from characteristic \(characteristic.debugDescription)")
    }
}

extension ServiceStore: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("Peripheral \(peripheral.debugDescription) did discover services with error \(error.debugDescription)")
        var foundService = false
        if let services = peripheral.services {
            for service in services {
                if service.uuid == MatchTransferUUIDs.dataService && !foundService {
                    foundService = true
                    peripheral.discoverCharacteristics([MatchTransferUUIDs.dataCharacteristic], for: service)
                }
            }
        }
        if !foundService {
            print("ERROR: Could not find right service! Erroring out...")
            self.errorOutWithBrowsing()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("Peripheral \(peripheral.debugDescription) did discover characteristics for service \(service.debugDescription) with error \(error.debugDescription)")
        var foundCharacteristic = false
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if characteristic.uuid == MatchTransferUUIDs.dataCharacteristic && !foundCharacteristic {
                    foundCharacteristic = true
                    self.proceedWithBrowsing()
                    peripheral.readValue(for: characteristic)
                }
            }
        }
        if !foundCharacteristic {
            print("ERROR: Could not find right characteristic! Erroring out...")
            self.errorOutWithBrowsing()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == MatchTransferUUIDs.dataCharacteristic {
            if let data = characteristic.value, let device = self.foundNearbyDevices.first(where: {$0.hash == peripheral.identifier.hashValue}) {
                self.delegate?.serviceStore(self, didReceiveData: data, fromDevice: device)
                self.proceedWithBrowsing()
            } else {
                print("ERROR: Data was null! Erroring out...")
                self.errorOutWithBrowsing()
            }
        } else {
            print("WARN: updated value to wrong characteristic! Erroring out...")
            self.errorOutWithBrowsing()
        }
    }
}

extension ServiceStore: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("CentralManager State is \(central.state.rawValue)")
        if central.state == .unsupported {
            transferType = .multipeerConnectivity
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("CentralManager did connect to peripheral \(peripheral.debugDescription)")
        self.proceedWithBrowsing()
        peripheral.discoverServices([MatchTransferUUIDs.dataService])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("CentralManager did fail to connect to peripheral \(peripheral.debugDescription) with error \(error.debugDescription)")
        if self.browsing {
            self.errorOutWithBrowsing()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("CentralManager did disconnect with peripheral \(peripheral.debugDescription) with error \(error.debugDescription)")
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if filters[peripheral.identifier] == nil {
            filters[peripheral.identifier] = RollingAverage(withSize: 50)
        }
        filters[peripheral.identifier]!.addValue(RSSI.doubleValue)
        let filter = filters[peripheral.identifier]!
        let deviceIdx = self.foundNearbyDevices.index(where: {peripheral.identifier.hashValue == $0.hash && $0.type == .coreBluetooth})
        if filter.average > -30.0 && deviceIdx == nil {
            print("CentralManager did discover peripheral \(peripheral.debugDescription) with addata \(advertisementData.debugDescription) and rssi \(RSSI)")
            let newDevice = NearbyDevice(displayName: advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? "Unknown", type: .coreBluetooth, hash: peripheral.identifier.hashValue, mcInfo: [:], mcId: nil, cbPeripheral: peripheral)
            self.foundNearbyDevices.append(newDevice)
            self.delegate?.serviceStore(self, foundNearbyDevice: newDevice)
        } else if filter.average < -30.0 && deviceIdx != nil {
            print("CentralManager did undiscover peripheral \(peripheral.debugDescription) with addata \(advertisementData.debugDescription) and rssi \(RSSI)")
            let oldDevice = self.foundNearbyDevices.remove(at: deviceIdx!)
            self.delegate?.serviceStore(self, lostNearbyDevice: oldDevice)
        }
    }
}

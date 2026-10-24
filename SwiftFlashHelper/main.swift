//
//  main.swift
//  SwiftFlashHelper
//
//  Root launch daemon that writes disk images to raw devices on behalf of SwiftFlash.
//  Registered by the app through SMAppService; reachable only via XPC.
//

import Foundation

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        // Only the correctly signed SwiftFlash app may talk to this root process.
        newConnection.setCodeSigningRequirement(FlashHelperConstants.clientRequirement)

        newConnection.exportedInterface = NSXPCInterface(with: FlashHelperProtocol.self)
        newConnection.remoteObjectInterface = NSXPCInterface(with: FlashProgressReceiverProtocol.self)

        let service = FlashHelperService(connection: newConnection)
        newConnection.exportedObject = service

        // Quit when the app goes away so launchd starts the current binary next time
        // (also avoids a stale helper after an app update).
        newConnection.invalidationHandler = {
            service.cancelOperation {}
            exit(0)
        }
        newConnection.resume()
        return true
    }
}

let listenerDelegate = ListenerDelegate()
let listener = NSXPCListener(machServiceName: FlashHelperConstants.helperIdentifier)
listener.delegate = listenerDelegate
listener.resume()
RunLoop.current.run()

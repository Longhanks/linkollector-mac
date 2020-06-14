import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var context: UnsafeMutableRawPointer!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        context = zmq_ctx_new()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        zmq_ctx_term(context)
        context = nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        true
    }
}

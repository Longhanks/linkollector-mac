import Cocoa

class ViewControllerActing: NSViewController {
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var textField: NSTextField!

    enum Action {
        case Receiving
        case Sending
    }

    var action: Action = Action.Sending

    private var workerThread: pthread_t? = nil
    private var signalSocket: UnsafeMutableRawPointer? = nil
    private var tcpSocket: UnsafeMutableRawPointer? = nil

    override func viewWillAppear() {
        super.viewWillAppear()

        progressIndicator.startAnimation(self)

        self.textField.stringValue = "\(self.action)..."
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        let context = (NSApp.delegate as! AppDelegate).context!
        var noLinger: Int32 = 0

        self.signalSocket = zmq_socket(context, ZMQ_PAIR)
        zmq_setsockopt(self.signalSocket, ZMQ_LINGER, &noLinger, MemoryLayout<Int32>.stride)

        let bindRcSignal = "inproc://signal".withCString { cString in
            return zmq_bind(self.signalSocket, cString)
        }

        if bindRcSignal != 0 {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = "Failed to bind signal socket"
            let window = self.view.window!.sheetParent!
            self.dismiss(self)
            alert.beginSheetModal(for: window) { _ in }
            return
        }

        if self.action == .Receiving {
            self.tcpSocket = zmq_socket(context, ZMQ_REP)
            zmq_setsockopt(self.tcpSocket, ZMQ_LINGER, &noLinger, MemoryLayout<Int32>.stride)

            let functor: PThreadCallback = { data in
                let self_ = Unmanaged<ViewControllerActing>.fromOpaque(data).takeUnretainedValue()

                let bindRcTcp = "tcp://*:17729".withCString { cString in
                    zmq_bind(self_.tcpSocket, cString)
                }

                if bindRcTcp != 0 {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Error"
                        alert.informativeText = "Failed to bind signal socket"
                        let window = self_.view.window!.sheetParent!
                        self_.dismiss(self_)
                        alert.beginSheetModal(for: window) { _ in }
                    }
                    return nil
                }

                var breakLoop = false

                while !breakLoop {
                    let maybeResponses = blockingPoll(targets: [
                        PollTarget(socket: self_.signalSocket!, targetEvent: Int16(ZMQ_POLLIN)),
                        PollTarget(socket: self_.tcpSocket!, targetEvent: Int16(ZMQ_POLLIN)),
                    ])

                    guard let responses = maybeResponses else {
                        DispatchQueue.main.async {
                            let alert = NSAlert()
                            alert.messageText = "Error"
                            alert.informativeText = "Failure in zmq_poll, killing server..."
                            let window = self_.view.window!.sheetParent!
                            self_.dismiss(self_)
                            alert.beginSheetModal(for: window) { _ in }
                        }
                        break
                    }

                    if responses.isEmpty {
                        continue
                    }

                    for response in responses {
                        if response.responseSocket == self_.signalSocket && response.responseEvent == Int16(ZMQ_POLLIN) {
                            var msg = zmq_msg_t()
                            zmq_msg_init(&msg)
                            if zmq_msg_recv(&msg, self_.signalSocket, 0) == -1 {
                                zmq_msg_close(&msg)
                                DispatchQueue.main.async {
                                    let alert = NSAlert()
                                    alert.messageText = "Error"
                                    alert.informativeText = "Failed to receive answer from signal socket"
                                    let window = self_.view.window!.sheetParent!
                                    self_.dismiss(self_)
                                    alert.beginSheetModal(for: window) { _ in }
                                }
                            }
                            breakLoop = true
                            break
                        }

                        if response.responseSocket == self_.tcpSocket && response.responseEvent == Int16(ZMQ_POLLIN) {
                            let onMessage: (_ data: Data, _ didError: inout Bool) -> Void = { data, didError in
                                if zmq_send(self_.tcpSocket!, nil, 0, 0) == -1 {
                                    DispatchQueue.main.async {
                                        let alert = NSAlert()
                                        alert.messageText = "Error"
                                        alert.informativeText = "Failed to send data to the TCP responder socket"
                                        let window = self_.view.window!.sheetParent!
                                        self_.dismiss(self_)
                                        alert.beginSheetModal(for: window) { _ in }
                                    }
                                    didError = true
                                    return
                                }

                                if data.isEmpty {
                                    return
                                }

                                let maybeData = deserialize(data)

                                if maybeData == nil {
                                    DispatchQueue.main.async {
                                        let alert = NSAlert()
                                        alert.messageText = "Error"
                                        alert.informativeText = "Could not parse message from client"
                                        let window = self_.view.window!.sheetParent!
                                        self_.dismiss(self_)
                                        alert.beginSheetModal(for: window) { _ in }
                                    }
                                    return
                                }

                                let (activity, message) = maybeData!

                                DispatchQueue.main.async {
                                    if activity == .URL {
                                        guard let url = URL(string: message) else {
                                            let alert = NSAlert()
                                            alert.messageText = "URL invalid"
                                            alert.informativeText = "Invalid URL received: \"\(message)\""
                                            let window = self_.view.window!.sheetParent!
                                            self_.dismiss(self_)
                                            alert.beginSheetModal(for: window) { _ in }
                                            return
                                        }
                                        NSWorkspace.shared.open(url)
                                        self_.dismiss(self_)
                                    } else {
                                        let alert = NSAlert()
                                        alert.messageText = "Text received"
                                        alert.informativeText = "Received the following text:"
                                        alert.accessoryView = NSTextField(string: message)
                                        let window = self_.view.window!.sheetParent!
                                        self_.dismiss(self_)
                                        alert.beginSheetModal(for: window) { _ in }
                                    }
                                }
                            }

                            var didError = false

                            if !asyncReceive(socket: self_.tcpSocket!, onMessage: onMessage, didError: &didError) {
                                DispatchQueue.main.async {
                                    let alert = NSAlert()
                                    alert.messageText = "Error"
                                    alert.informativeText = "Failure in zmq_msg_recv, killing server..."
                                    let window = self_.view.window!.sheetParent!
                                    self_.dismiss(self_)
                                    alert.beginSheetModal(for: window) { _ in }
                                }
                                breakLoop = true
                                break
                            }

                            if didError {
                                breakLoop = true
                                break
                            }
                        }
                    }
                }

                return nil
            }

            pthread_create(&workerThread, nil, functor, Unmanaged.passUnretained(self).toOpaque())
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        if let workerThread = workerThread {
            let context = (NSApp.delegate as! AppDelegate).context!
            var noLinger: Int32 = 0

            let otherSignalSocket = zmq_socket(context, ZMQ_PAIR)
            zmq_setsockopt(otherSignalSocket, ZMQ_LINGER, &noLinger, MemoryLayout<Int32>.stride)

            let connectRcSignal = "inproc://signal".withCString { cString in
                return zmq_connect(otherSignalSocket, cString)
            }

            if connectRcSignal != 0 {
                let alert = NSAlert()
                alert.messageText = "Error"
                alert.informativeText = String(cString: zmq_strerror(errno))  // "Failed to connect to the signal socket"
                alert.runModal()
                exit(EXIT_FAILURE)
            }

            if zmq_send(otherSignalSocket, nil, 0, 0) == -1 {
                let alert = NSAlert()
                alert.messageText = "Error"
                alert.informativeText = "Failed to send to the signal socket"
                alert.runModal()
                exit(EXIT_FAILURE)
            }

            zmq_close(otherSignalSocket)

            pthread_join(workerThread, nil)
        }

        if self.signalSocket != nil {
            zmq_close(self.signalSocket)
        }

        if self.tcpSocket != nil {
            zmq_close(self.tcpSocket)
        }

        progressIndicator.stopAnimation(self)
    }
}

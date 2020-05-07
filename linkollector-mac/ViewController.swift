import Cocoa

class ViewController: NSViewController, NSTextFieldDelegate {
    @IBOutlet weak var buttonMessageTypeURL: NSButton!
    @IBOutlet weak var buttonMessageTypeText: NSButton!
    @IBOutlet weak var textFieldToDevice: NSTextField!
    @IBOutlet weak var textFieldMessageContent: NSTextField!
    @IBOutlet weak var buttonSend: NSButton!

    var buttonsMessageType: [NSButton] {
        [self.buttonMessageTypeURL, self.buttonMessageTypeText]
    }

    @IBAction func messageTypeButtonPressed(_ sender: NSButton) {
        self.buttonsMessageType.forEach {
            $0.state = $0 == sender ? .on : .off
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.textFieldToDevice.delegate = self
        self.textFieldMessageContent.delegate = self
    }

    func controlTextDidChange(_ notification: Notification) {
        self.buttonSend.isEnabled =
            !(self.textFieldToDevice.stringValue.isEmpty
            || self.textFieldMessageContent.stringValue.isEmpty)
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        guard let sender = sender as? NSView else {
            return
        }

        let target = segue.destinationController as! ViewControllerActing

        if sender == self.buttonSend {
            target.action = .Sending
        } else {
            target.action = .Receiving
        }
    }
}

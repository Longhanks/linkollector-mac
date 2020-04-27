import Cocoa

class ViewController: NSViewController {
    @IBOutlet weak var buttonMessageTypeURL: NSButton!
    @IBOutlet weak var buttonMessageTypeText: NSButton!

    var buttonsMessageType: [NSButton] {
        [buttonMessageTypeURL, buttonMessageTypeText]
    }

    @IBAction func messageTypeButtonPressed(_ sender: NSButton) {
        buttonsMessageType.forEach {
            $0.state = $0 == sender ? .on : .off
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}

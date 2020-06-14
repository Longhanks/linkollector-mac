import Cocoa

class ViewControllerActing: NSViewController {
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var textField: NSTextField!

    enum Action {
        case Receiving
        case Sending
    }

    var action: Action = Action.Sending

    override func viewDidLoad() {
        super.viewDidLoad()

        let context = (NSApp.delegate as! AppDelegate).context!
    }

    override func viewWillAppear() {
        progressIndicator.startAnimation(self)

        self.textField.stringValue = "\(self.action)..."
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        progressIndicator.stopAnimation(self)
    }

}

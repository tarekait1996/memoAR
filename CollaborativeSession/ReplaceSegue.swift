
import UIKit
class ReplaceSegue: UIStoryboardSegue {

    override func perform() {
        source.navigationController?.setViewControllers([destination], animated: true)
    }
}

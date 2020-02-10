import Foundation
import UIKit


/// UIViewController Helpers
///
extension UIViewController {

    /// Returns the default nibName: Matches the classname (expressed as a String!)
    ///
    class var nibName: String {
        return classNameWithoutNamespaces
    }

    /// Removes the text of the navigation bar back button in the next view controller of the navigation stack.
    ///
    func removeNavigationBackBarButtonText() {
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
    }
    
    /// Show the X close button on the left bar button item position
    ///
    func addLeftCloseNavigationBarButton() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: .closeButton, style: .plain, target: self, action: #selector(dismiss))
    }
    
//    private func dismiss() {
//        dismiss(animated: true, completion: nil)
//    }
}

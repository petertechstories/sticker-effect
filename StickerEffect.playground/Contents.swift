import UIKit
import PlaygroundSupport

class MyViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let effectView = StickerEffectView(frame: CGRect(origin: CGPoint(x: 100.0, y: 200.0), size: CGSize(width: 200.0, height: 200.0)))
        effectView.image = UIImage(named: "logo.png")
        view.addSubview(effectView)
        
        class DisplayLinkTarget: NSObject {
            let f: () -> Void
            
            init(_ f: @escaping () -> Void) {
                self.f = f
                
                super.init()
            }
            
            @objc func update() {
                self.f()
            }
        }
        
        effectView.updateLayers(fraction: 0.0, reverse: false)
        
        var t: CGFloat = 0.0
        let displayLink = CADisplayLink(target: DisplayLinkTarget {
            t += 1.0 / 60.0 * 0.3
            t = t.truncatingRemainder(dividingBy: 1.0)
            
            let scaledT: CGFloat
            let reverse: Bool
            if t < 0.3 {
                scaledT = t / 0.3
                reverse = false
            } else if t < 0.3 + 0.3 {
                scaledT = 1.0
                reverse = false
            } else {
                scaledT = (t - (0.3 + 0.3)) / (1.0 - (0.3 + 0.3))
                reverse = true
            }
            
            // Equivalent to the ease-in-out timing function
            let effectiveT = evaluateBezier(0.42, 0.0, 0.58, 1.0, scaledT)
            
            effectView.updateLayers(fraction: effectiveT, reverse: reverse)
        }, selector: #selector(DisplayLinkTarget.update))
        displayLink.add(to: .main, forMode: .common)
    }
}

PlaygroundPage.current.liveView = MyViewController()


import UIKit
import MetalKit
import ModelIO

class ViewController: UIViewController {
    var mtkView: MTKView!
    var renderer: Renderer!
    override func viewDidLoad() {
        super.viewDidLoad()

        let value = UIInterfaceOrientation.portrait.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
        
        mtkView = MTKView()
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mtkView)
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[mtkView]|", options: [], metrics: nil, views: ["mtkView" : mtkView!]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[mtkView]|", options: [], metrics: nil, views: ["mtkView" : mtkView!]))
        
        let device = MTLCreateSystemDefaultDevice()!
        mtkView.device = device
        mtkView.colorPixelFormat = .bgra8Unorm_srgb
        mtkView.depthStencilPixelFormat = .depth32Float
        
        //from modern-metal renderer = Renderer(view: mtkView, device: device)
        renderer = Renderer(device: device, with: mtkView)
        mtkView.delegate = renderer
        mtkView.isMultipleTouchEnabled = true
    }
    

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touchCount = touches.count
        let touch = touches.first
        let t = touch!.preciseLocation(in: view)
        print("\(touchCount) touches started \(t.x) \(t.y)")
        mtkView.isPaused = false;
        renderer.didTouch(touches: touches, with: event, first: true)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        renderer.didTouch(touches: touches, with: event, first: false)
        mtkView.isPaused = false;
        
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        renderer.didTouch(touches: touches, with: event, last: true)
        
        let touchCount = touches.count
        let touch = touches.first
        let t = touch!.preciseLocation(in: view)
        print("\(touchCount) touches ended \(t.x) \(t.y)")
        renderer.defaultBrush.touchEnded = true
        //view paused in renderer.drawFrame
        //mtkView.isPaused = true;
    }
    override func touchesEstimatedPropertiesUpdated(_ touches: Set<UITouch>) {
        for touch in touches {
            guard let index = touch.estimationUpdateIndex else {
                continue
            }
            //print ("update index: \(index) force: \(touch.force)")
        }
        renderer.updateTouch(touches: touches)
    }
    
}
    


    // MARK: - UIPencilInteractionDelegate

    @available(iOS 12.1, *)
    extension ViewController: UIPencilInteractionDelegate {

        /// Handles double taps that the user makes on an Apple Pencil.
        /// - Tag: pencilInteractionDidTap
        func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            if UIPencilInteraction.preferredTapAction == .switchPrevious {
                //leftRingControl.switchToPreviousTool()
            }
        }

    }




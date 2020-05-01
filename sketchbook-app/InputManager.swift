//
//  InputManager.swift
//  sketchbook-app
//
//  Created by Si Li on 4/15/20.
//  Copyright © 2020 Metal By Example. All rights reserved.
//

import Foundation
import UIKit
import MetalKit
    

class InputManager {
    var txwidth: Int = 0
    var txheight: Int = 0
    
    var view: MTKView!
    var uim: UIManager
    
    var brushes: Brushes

    //test stuff
    var maxTouch: Int = 100
    var replayBrushBuffer: [BrushSample] = []
    var replay: Bool = false
    var enableReplay: Bool = false
    var beginReplay: Bool = false
    var firstTouch: UITouch? = nil
    

    init(w: Int, h: Int, u: UIManager, v: MTKView, b: Brushes) {
        txwidth = w
        txheight = h
        uim = u
        view = v
        
        brushes = b

        replayBrushBuffer.reserveCapacity(maxTouch)
    }
    
    //MARK: - touch
    func processTouchPosition(touch: UITouch, view: MTKView) -> Vec2 {
        let t = touch.preciseLocation(in: view)
        let txw = Float(txwidth)
        let txh = Float(txheight)
        let bounds = view.bounds.size
        let x = 2 * Float(t.x) / Float(bounds.width) * txw - txw
        let y = 2 * Float(t.y) / Float(bounds.height) * txh - txh
        let pos: Vec2 = Vec2(x,y)
        return pos
    }
    
    enum TouchType : Int {
        case update
        case standard
        case prediction
    }
    
    let filter: Int = 10
    var touchCount: Int = 0
    
    func updateTouch(touches: Set<UITouch>) {
        if uim.cantDraw() {
            return
        }
        for touch in touches {
            guard let index = touch.estimationUpdateIndex else {
                continue
            }
            let pos = processTouchPosition(touch: touch, view: view)
            let first = brushes.updatedBrush.firstUpdateIndex == Int(truncating: index)
            brushes.updatedBrush.append(pos: pos, force: Float(touch.force), first: first)
            if first {
                //print("first update: \(pos)")
            }
            let count = brushes.updatedBrush.sampleBuffer.count
            if count > 0 {
                //print ("inputManager: brush samples: \(count)")
            }
            //print("updated force: \(touch.force)")
        }
    }
    
    func didTouch(touches: Set<UITouch>, with event: UIEvent?, first: Bool = false, last: Bool = false, type: TouchType = .standard) {
        /*
        if replay {
            if replayBrushBuffer.isEmpty {
                replay = false
                let clearColor = MTLClearColorMake(200/255.0, 40/255.0, 40/255.0, 1.0)
                clearTexture(texture: canvasTexture, color: clearColor, in: view)
            } else {
                return
            }
        }
 // */
        
        //button hit eval
        if let touch = touches.first, touch.type == .direct {
            
            let target = uim.resizeButtonLocation
            let pos = processTouchPosition(touch: touch, view: view)
            let hit = v_len(a: target - pos) < 140.0
            //print("dist: \(v_len(a: target - pos))")
            if hit && first {
                uim.pressButton()
            }
            if last {
                print("release button")
                uim.releaseButton()
                //TODO need to initialize uim new brush size? or only do this if brush resize was pressed??
                brushes.updatedBrush.size = uim.newBrushSize
            }
        }
        
        
        //eval first: need to mark first sample of a stroke
        if first {
            firstTouch = touches.first!
            let pos = processTouchPosition(touch: firstTouch!, view: view)
            if firstTouch!.type == .pencil {
                uim.firstPencilLoc = pos
            }
            
            if firstTouch!.estimatedPropertiesExpectingUpdates != [] {
                if let estimationUpdateIndex = firstTouch?.estimationUpdateIndex {
                    brushes.updatedBrush.firstUpdateIndex = Int(truncating: estimationUpdateIndex)
                }
            }
            
            //if first touch is in color picker, disable drawing, go to color pick mode
            uim.firstTouch(pos: pos, pencil: firstTouch!.type == .pencil)
        }
/*
        //predicted touch
        if let predictedTouches = event!.predictedTouches(for: firstTouch!)
        {
            //print("predictedTouches:", predictedTouches.count)
            for predictedTouch in predictedTouches
            {
                //let pos = processTouchPosition(touch: predictedTouch, view: view)
                //brushes.predictedBrush.append(pos: pos, force: Float(predictedTouch.force), first: firstOnce)
            }
        }
*/
        //touches
        var firstOnce = first
        for touch in touches {
            touchCount += 1
            if touchCount == filter {
                touchCount = 0
            } else {
                //continue
            }
            let pos = processTouchPosition(touch: touch, view: view)
            brushes.defaultBrush.append(pos: pos, force: Float(touch.force), first: firstOnce); firstOnce = false
            if touch.type == .pencil {
                uim.currentPencilLoc = pos
            }
            
            brushes.updatedBrush.color = uim.processTouch(pos: pos)
            
            if enableReplay == true {
                guard let brush = brushes.defaultBrush.sampleBuffer.last else { return }
                if replayBrushBuffer.count < maxTouch {
                    replayBrushBuffer.append(brush)
                    print ("replaybuff: \(replayBrushBuffer.count)")
                } else {
                    if !replay {
                        beginReplay = true
                        replay = true
                        print("starting replay!")
                        break
                    }
                }
            }
        }
    }
}

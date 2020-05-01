//
//  UIManager.swift
//  sketchbook-app
//
//  Created by Si Li on 4/9/20.
//  Copyright © 2020 Metal By Example. All rights reserved.
//

import Foundation
import MetalKit

class UIManager {
    var txwidth: Int = 0
    var txheight: Int = 0
    
    let buttonActivatedColor = Color(40,40,100, 255)
    var buttonColor: Color
    
    var dontDraw = true
    var buttonPressed = false
    var colorPickMode = false
    var colorPickHueMode = false
    
    var brush: Brush

    var firstPencilLoc = Vec2()
    var currentPencilLoc = Vec2()
    var newBrushSize: Float = 16
    var buttonLoc = Vec2(0, -800)
    

    var activeColorSlot : ColorSlot
    
    var hsv = FloatHSV (200, 1, 1, 1)
    //rendering glue

    var uiMap : [String: GraphicalElement] = [:]
    var uiArray : [GraphicalElement] = []

    var renderer: Renderer!
    var initialized: Bool = false
    
    let resizeButtonLocation = Vec2(-200.0, -2000)
    
    init(w: Int, h: Int, r: Renderer, b: Brushes) {
        txwidth = w
        txheight = h
        renderer = r
        initialized = true
        

        brush = b.updatedBrush
        brush.color = hsv2rgb(input: hsv)
        buttonColor = brush.color

        //create graphical elements and their backing texture
        let td = MTLTextureDescriptor()
        td.usage = [.shaderRead, .shaderWrite]
        
        //circle brush
        var size = Vec2(brush.size)
        //var ti = renderer.createTexture(td, size: size)
        var ti = 0
        var pos = Vec2()
        //var color = Color(40, 40, 200,255)
        var color = brush.color
        //let circleBrush = CircleBrush(p: pos, s: size, c: color, ti: ti)
        //circleBrush.fill(&r.stampTextures.t[ti]!)

        //color slots; currently using same texture as brush, can override color while retaining alpha of texture
        //TODO need to make an offset system based on relative desired offset from some UI element
        //*
        let colorPickerDim = 500
        let colorPickerLocation = Vec2(800, -2000)
        let colorPickerHueOffsetLocation = Vec2(900, 0)
        let widthHue = 360
        let heightHue = 2
        
        size = Vec2(110)
        pos = colorPickerLocation + Vec2(-700, -400)
        color = Color(200, 200, 200, 255)
        uiArray.append(ColorSlot(p: pos, s: size, c: color, ti: ti))
        uiMap["activeColorSlotIndicator"] = uiArray.last
        uiArray.last!.hitable = false
        
        size = Vec2(100)
        color = Color(43, 43, 43, 255)
        for i in 0 ... 3 {
            uiArray.append(ColorSlot(p: pos, s: size, c: color, ti: ti))
            let name = "ColorSlot\(i)"
            uiArray.last!.name = name
            uiArray.last!.tag = "ColorSlot"
            uiMap[name] = uiArray.last
            pos = pos + Vec2(0, 260)
        }
        activeColorSlot = uiArray[1] as! ColorSlot
        // */
        //activeColorSlot = (ColorSlot(p: pos, s: size, c: color, ti: ti))

        //color picker
        size = Vec2(Float(colorPickerDim))
        var txSize = Vec2(Float(256))
        ti = renderer.createTexture(td, size: txSize)
        uiArray.append(ColorPicker(p: colorPickerLocation, s: size, ts: txSize, h: Int(hsv.h), ti: ti))
        uiMap["colorPicker"] = uiArray.last
        uiArray.last!.name = "colorPicker"

        //color picker hue
        size = Vec2(Float(widthHue))
        txSize = Vec2(Float(widthHue), Float(heightHue))
        ti = renderer.createTexture(td, size: txSize)
        pos = colorPickerLocation + colorPickerHueOffsetLocation
        uiArray.append(ColorPickerHue(p: pos, s: size, ts: txSize, ti: ti))
        uiMap["colorPickerHue"] = uiArray.last
        uiArray.last!.name = "colorPickerHue"

        //new layer
        
        //create gradient maps
        
        //create color markers for gradient map
        
        //how to add and delete markesr??
        
        //how to change colors of each marker?
    }

    func getElements(_ textureBox : TextureBox, _ buffer : inout [BrushUniform]) {
        for ge in uiArray {
            ge.fill(&textureBox.t[Int(ge.txIndex)]!)
            let element = ge.getElement()
            buffer.append(convert(sample: element, txIndex: uint(ge.txIndex)))
        }
    }
    
    func setSelectedColor(_ c : Color) {
        activeColorSlot.color = c
    }
    func pressButton() {
        print("resize button pressed!")
        buttonColor = buttonActivatedColor
        buttonPressed = true
        firstPencilLoc = Vec2()
        currentPencilLoc = Vec2()
    }
    
    func releaseButton() {
        buttonColor = brush.color
        buttonPressed = false
        dontDraw = false
    }
    
    func confirmBrushSize() {
        brush.size = newBrushSize
    }
    
    func convert(sample: BrushSample, txIndex: uint = 0) -> BrushUniform {
        let p = Vec2(sample.position.x / Float(txwidth),
                     sample.position.y / Float(txheight))
        let s = Vec2(sample.size / Float(txwidth),
                     sample.size / Float(txheight))
        let c = float4(Float(sample.color.r)/255.0,
                       Float(sample.color.g)/255.0,
                       Float(sample.color.b)/255.0,
                       Float(sample.color.a)/255.0 * powf(sample.force, 2.0))
        //print("convert color: \(c)")
        let strokeSample = BrushUniform(position: p, size: s, color: c, txIndex: txIndex)
        return strokeSample
    }

    func createResizeBrushButton() -> BrushSample {
        let element = BrushSample(position: resizeButtonLocation, size: 128.0, color: buttonColor)
        return element
    }
    
    func distTravelledFromButton() -> Float {
        let distFirst = v_len(a: firstPencilLoc - buttonLoc)
        let distCurr = v_len(a: buttonLoc - currentPencilLoc)
        let dist = distCurr - distFirst
        return dist
    }
    
    func createResizeBrush(brushSize: Float) -> BrushSample {
        let dist = distTravelledFromButton()
        //print("dist \(dist)")
        newBrushSize = brushSize + dist / 2
        
        let element = BrushSample(position: buttonLoc, size: newBrushSize, color: brush.color)
        return element
    }
    
    //MARK: - UI logic
    
    //checks if a touch hits a UI target
    //this locks the ui selection until the next touchBegan
    func firstTouch(pos: Vec2, pencil: Bool) {
        //get box of color picker
        colorPickMode = uiMap["colorPicker"]!.isOver(pos)
        colorPickHueMode = uiMap["colorPickerHue"]!.isOver(pos, debug: true)
        if colorPickMode || colorPickHueMode {
            print ("colorPickMode \(colorPickMode) colorPickHueMode \(colorPickHueMode)")
        }
        
        for ge in uiArray {
            if let colorSlot = ge as? ColorSlot {
                let hit = colorSlot.isOver(pos)
                if hit {
                    print("\(ge.name) hit")
                    dontDraw = true
                    //print("uimap size: \(uiMap.count) acsi: \(uiMap["activeColorSlotIndicator"]!.position)")
                    //TODO indicator behavior is wrong
                    if pencil {
                        uiMap["activeColorSlotIndicator"]!.position = colorSlot.position
                        activeColorSlot = colorSlot
                        brush.color = colorSlot.color
                        hsv = colorSlot.hsvColor
                    } else {
                        //take colorSlot, multiply by .1, add current color *.9
                        let newColor = lerp(activeColorSlot.hsvColor, colorSlot.hsvColor, 0.9)
                        print ("\(ge.name) curr: \(activeColorSlot.hsvColor.h) target: \(colorSlot.hsvColor.h) out: \(newColor.h)")
                        activeColorSlot.hsvColor = newColor
                        hsv = activeColorSlot.hsvColor
                        brush.color = hsv2rgb(input: activeColorSlot.hsvColor)
                        activeColorSlot.color = brush.color
                    }
                    let cp = uiMap["colorPicker"] as! ColorPicker
                    cp.hue = Int(hsv.h)
                    cp.toUpdate = true
                    break
                }
            }
        }
    }
    
    func lerp(_ a: FloatHSV, _ b: FloatHSV, _ f: Float) -> FloatHSV {
        var ret = FloatHSV()
        //find shortest direction to lerp
        let normalLerp = abs(a.h - b.h) < 180
        if normalLerp {
            ret.h = lerp(a.h, b.h, f)
        } else {
            if a.h > b.h {
                ret.h = lerp(a.h, b.h+360, f)
            } else {
                ret.h = lerp(a.h+360, b.h, f)
            }
            if ret.h > 360 {
                ret.h -= 360
            }
        }
        ret.s = lerp(a.s, b.s, f)
        ret.v = lerp(a.v, b.v, f)
        return ret
    }
    func lerp(_ a: Float, _ b: Float, _ f: Float) -> Float {
        return a * f + b * (1 - f)
    }
    

    func cantDraw() -> Bool {
        return buttonPressed || colorPickMode || colorPickHueMode
    }
    
    //this activates the selected UI, change its appearance, and perform its functions
    func processTouch(pos: Vec2) -> Color{
        if colorPickMode {
            let temp = (uiMap["colorPicker"] as! ColorPicker).touch(pos)
            hsv.s = temp.s
            hsv.v = temp.v
        }
        
        if colorPickHueMode {
            hsv.h = (uiMap["colorPickerHue"] as! ColorPickerHue).touch(pos)
            let cp = uiMap["colorPicker"] as! ColorPicker
            cp.hue = Int(hsv.h)
            cp.toUpdate = true
            print("colorpick hsv: \(hsv)")
        }
        
        if colorPickHueMode || colorPickMode {
            brush.color = hsv2rgb(input: hsv)
            print("\(brush.color)")
            setSelectedColor(brush.color)
            activeColorSlot.color = brush.color
            activeColorSlot.hsvColor = hsv
        }
        
        return brush.color
    }
}

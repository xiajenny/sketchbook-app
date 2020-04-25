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
    
    let defaultButtonColor = Color(80,80,180, 255)
    let buttonActivatedColor = Color(40,40,100, 255)
    var buttonColor: Color
    
    var buttonPressed = false
    var colorPickMode = false
    var colorPickHueMode = false
    

    var colorPickerDim = 500
    var firstPencilLoc = Vec2()
    var currentPencilLoc = Vec2()
    var newBrushSize: Float = 256
    var brushSize: Float = 256
    var buttonLoc = Vec2(0, -800)
    
    let resizeButtonLocation = Vec2(-200.0, -2000)
    var colorPickerLocation = Vec2(800, -2000)
    let colorPickerHueOffsetLocation = Vec2(900, 0)
    
    var activeColorSlot : ColorSlot
    
    var hue = 300
    var sat = 255
    var val = 255
    let widthHue = 360
    let heightHue = 2
    var brushColor: Color
    //rendering glue

    var uiMap : [String: GraphicalElement] = [:]
    var uiArray : [GraphicalElement] = []

    var renderer: Renderer!
    var initialized: Bool = false
    
    init(w: Int, h: Int, r: Renderer) {
        txwidth = w
        txheight = h
        renderer = r
        initialized = true
        
        buttonColor = defaultButtonColor
        let hsv = itof(i: IntHSV(h: hue, s: 50, v: 50, a: 255))
        brushColor = hsv2rgb(input: hsv)

        //create graphical elements and their backing texture
        let td = MTLTextureDescriptor()
        td.usage = [.shaderRead, .shaderWrite]
        
        //circle brush
        var size = Vec2(brushSize)
        //var ti = renderer.createTexture(td, size: size)
        var ti = 0
        var pos = Vec2()
        //var color = Color(40, 40, 200,255)
        var color = brushColor
        //let circleBrush = CircleBrush(p: pos, s: size, c: color, ti: ti)
        //circleBrush.fill(&r.stampTextures.t[ti]!)

        //color slots; currently using same texture as brush, can override color while retaining alpha of texture
        //TODO need to make an offset system based on relative desired offset from some UI element
        //*
        size = Vec2(110)
        pos = colorPickerLocation + Vec2(-700, -400)
        color = Color(200, 200, 200, 255)
        uiArray.append(ColorSlot(p: pos, s: size, c: color, ti: ti))
        uiMap["activeColorSlotIndicator"] = uiArray.last
        
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
        uiArray.append(ColorPicker(p: colorPickerLocation, s: size, ts: txSize, h: hue, ti: ti))
        uiMap["colorPicker"] = uiArray.last

        //color picker hue
        size = Vec2(Float(widthHue))
        txSize = Vec2(Float(widthHue), Float(heightHue))
        ti = renderer.createTexture(td, size: txSize)
        pos = colorPickerLocation + colorPickerHueOffsetLocation
        uiArray.append(ColorPickerHue(p: pos, s: txSize, ts: txSize, ti: ti))
        uiMap["colorPickerHue"] = uiArray.last

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
        buttonColor = defaultButtonColor
        buttonPressed = false
    }
    
    func confirmBrushSize() {
        brushSize = newBrushSize
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
        print("dist \(dist)")
        newBrushSize = brushSize + dist / 2
        
        let element = BrushSample(position: buttonLoc, size: newBrushSize, color: defaultButtonColor)
        return element
    }
    
    //MARK: - UI logic
    
    //checks if a touch hits a UI target
    //this locks the ui selection until the next touchBegan
    func firstTouch(pos: Vec2, pencil: Bool) {
        //get box of color picker
        var offset = Float(colorPickerDim)
        var left = colorPickerLocation.x - offset
        var right = colorPickerLocation.x + offset
        var top = colorPickerLocation.y + offset
        var bottom = colorPickerLocation.y - offset
        
        colorPickMode = left < pos.x && pos.x < right && top > pos.y && pos.y > bottom
        colorPickMode = uiMap["colorPicker"]!.isOver(pos)
        
        offset = Float(widthHue)
        let hueLoc = colorPickerLocation + colorPickerHueOffsetLocation
        left = hueLoc.x - offset
        right = hueLoc.x + offset
        top = hueLoc.y + offset
        bottom = hueLoc.y - offset
        colorPickHueMode = left < pos.x && pos.x < right && top > pos.y && pos.y > bottom
        //colorPickHueMode = uiMap["colorPickerHue"]!.isOver(pos)
        
        for ge in uiArray {
            if let colorSlot = ge as? ColorSlot {
                let hit = colorSlot.isOver(pos)
                if hit {
                    print("\(ge.name) hit")
                    uiMap["activeColorSlotIndicator"]!.position = colorSlot.position
                    //TODO indicator behavior is wrong
                    if pencil {
                        activeColorSlot = colorSlot
                        brushColor = colorSlot.color
                        hue = Int(colorSlot.hsvColor.h)
                        sat = Int(colorSlot.hsvColor.s)
                        val = Int(colorSlot.hsvColor.v)
                    } else {
                        //take colorSlot, multiply by .1, add current color *.9
                        activeColorSlot.hsvColor = lerp(activeColorSlot.hsvColor, colorSlot.hsvColor, 0.9)
                        hue = Int(activeColorSlot.hsvColor.h)
                        sat = Int(activeColorSlot.hsvColor.s)
                        val = Int(activeColorSlot.hsvColor.v)
                        brushColor = hsv2rgb(input: activeColorSlot.hsvColor)
                        activeColorSlot.color = brushColor
                    }
                    let cp = uiMap["colorPicker"] as! ColorPicker
                    cp.hue = hue
                    cp.toUpdate = true
                }
            }
        }
    }
    
    func lerp(_ a: FloatHSV, _ b: FloatHSV, _ f: Float) -> FloatHSV {
        var ret = FloatHSV()
        ret.h = lerp(a.h, b.h, f)
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
            let dim = Float(colorPickerDim)
            var origin = colorPickerLocation
            origin.x += dim
            origin.y += dim
            let sv = (origin - pos)/2
            sat = Int(min(255, max(0.0, (dim - sv.y) * 255 / dim)))
            val = Int(min(255, max(0, (dim - sv.x) * 255 / dim)))
            print("sv: \(sv) hue: \(hue) s: \(sat) v: \(val)")
        }
        
        if colorPickHueMode {
            let dim = Float(widthHue)
            var origin = colorPickerLocation
            origin.x += dim
            let sv = (pos - origin) / 2
            hue = Int(min(255, max(0.0, sv.x * 255 / dim)))
            let cp = uiMap["colorPicker"] as! ColorPicker
            cp.hue = hue
            cp.toUpdate = true
            print("pos: \(pos.x) origin: \(origin.x) sv: \(sv) hue: \(hue) s: \(sat) v: \(val)")
        }
        
        if colorPickHueMode || colorPickMode {
            let hsv = itof(i: IntHSV(h: hue, s: Int(sat), v: Int(val), a: 255))
            brushColor = hsv2rgb(input: hsv)
            setSelectedColor(brushColor)
            activeColorSlot.color = brushColor
            activeColorSlot.hsvColor = hsv
        }
        
        return brushColor
    }
}

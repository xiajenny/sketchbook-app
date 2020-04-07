//
//  Renderer.swift
//
//  Copyright © 2020
//

import MetalKit

let defaultBrushSize : Float = 256

struct Vec2 {
    var x : Float = 0.0
    var y : Float = 0.0
}

extension Vec2: CustomStringConvertible {
    var description: String {
        return "\(x), \(y)"
    }
}
    
extension Vec2 {
    static func + (left: Vec2, right: Vec2) -> Vec2 {
        return Vec2(x: left.x + right.x, y: left.y+right.y)
    }
    static func - (left: Vec2, right: Vec2) -> Vec2 {
        return Vec2(x: left.x - right.x, y: left.y-right.y)
    }
    static func * (left: Vec2, right: Vec2) -> Vec2 {
        return Vec2(x: left.x * right.x, y: left.y*right.y)
    }
    static func * (left: Vec2, right: Float) -> Vec2 {
        return Vec2(x: left.x * right, y: left.y*right)
    }
    static func / (left: Vec2, right: Float) -> Vec2 {
        return Vec2(x: left.x / right, y: left.y/right)
    }
}

typealias ivec2 = (x: Int, y: Int)
typealias float3 = SIMD3<Float>
typealias float4 = SIMD4<Float>

func v_len(a: Vec2) -> Float { return sqrtf(a.x*a.x + a.y*a.y) }
func v_norm(a: Vec2) -> Vec2 { return a * (1.0 / v_len(a: a)) }

struct Vertex {
    var position: float3
    var color: float4
}

struct BrushSample {
    var position: Vec2 = Vec2(x: 40, y: 40)
    var force: Float = 1
    var first: Bool = true
    var size: Float = 16
    var alpha: Float = 1.0
    var color = Color(r: 255,g: 10,b: 255,a:100)
}
extension BrushSample: CustomStringConvertible {
    var description: String {
        return "pos: \(position), f: \(force), size: \(size), color: \(color)"
    }
}

struct BrushUniform {
    var position: Vec2
    var size: Vec2
    var color: float4
}

struct Color {
    var r : UInt8
    var g : UInt8
    var b : UInt8
    var a : UInt8
}

struct Brush {
    var name: String
    var size: Float = defaultBrushSize
    var sampleBuffer: [BrushSample] = []
    //var strokeBuffer: [BrushUniform] = []
    var color = Color(r: 10,g: 10,b: 80,a:155)
    var prevSample = BrushSample()
    var touchEnded: Bool = true
    var firstUpdateIndex: Int = 0
    var txwidth: Int = 0
    var txheight: Int = 0
    init (n: String, w: Int, h: Int) {
        name = n
        //strokeBuffer.reserveCapacity(1000)
        txwidth = w
        txheight = h
    }

    mutating func newColor() {
        color.r = UInt8((Int(color.r) + 43) % 256)
        color.g = UInt8((Int(color.g) + 19) % 256)
        color.b = UInt8((Int(color.b) + 4) % 256)
    }
    
    mutating func append(pos: Vec2, force: Float, first: Bool) {
        var sample = BrushSample(position: pos, force: force, first: first)
        sample.size = self.size //* force
        sample.color = self.color
        sample.first = first
        sample.force = force
        sampleBuffer.append(sample)
        //print("appending brush.size: \(self.size) f: \(force) size: \(sample.size)")
    }
    
    func convert(sample: BrushSample) -> BrushUniform {
        let p = Vec2(x: sample.position.x / Float(txwidth),
                     y: sample.position.y / Float(txheight))
        let s = Vec2(x: sample.size / Float(txwidth),
                     y: sample.size / Float(txheight))
        let c = float4(Float(sample.color.r)/255.0,
                       Float(sample.color.g)/255.0,
                       Float(sample.color.b)/255.0,
                       Float(sample.color.a)/255.0)
        let strokeSample = BrushUniform(position: p, size: s, color: c)
        return strokeSample
    }
    
}

class Renderer: NSObject {
    var view: MTKView!
    var commandQueue: MTLCommandQueue!
    var renderPipelineState: MTLRenderPipelineState!
    var brushPipelineState: MTLRenderPipelineState!
    var strokePipelineState: MTLRenderPipelineState!
    var clearPipelineState: MTLRenderPipelineState!
    
    var uniformBuffer: MTLBuffer! = nil;
    var vertexBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    var uniformStrokeBuffer: MTLBuffer!
    
    var strokeBuffer: [BrushUniform] = []
    
    //for a fullframe quad
    let vertices:[Float] = [
    -1.0,-1.0, 0.0,   0.0, 0.0,
    1.0,-1.0, 0.0,   1.0, 0.0,
    1.0, 1.0, 0.0,   1.0, 2732.0/2736.0,
    1.0, 1.0, 0.0,   1.0, 2732.0/2736.0,
    -1.0, 1.0, 0.0,   0.0, 2732.0/2736.0,
    -1.0,-1.0, 0.0,   0.0, 0.0]
    let indices: [UInt16] = [0,1,2,2,4,0]
    
    var brushTexture: MTLTexture! = nil
    var canvasTexture: MTLTexture! = nil
    var uiTexture: MTLTexture! = nil
    var displayTexture: MTLTexture! = nil
    
    var winwidth: Int = 0
    var winheight: Int = 0
    var txwidth: Int = 0
    var txheight: Int = 0
    
    var defaultBrush: Brush
    var updatedBrush: Brush
    var predictedBrush: Brush

    //test stuff
    var maxTouch: Int = 100
    var replayBrushBuffer: [BrushSample] = []
    var replay: Bool = false
    var enableReplay: Bool = false
    var beginReplay: Bool = false
    var firstTouch: UITouch? = nil
    
    var framesIdle: UInt = 0
    
    //ui stuff
    let clearColor = MTLClearColorMake(200/255.0, 40/255.0, 40/255.0, 0.0)
    let defaultColor = MTLClearColorMake(200/255.0, 40/255.0, 40/255.0, 1.0)
    let defaultButtonColor = Color(r: 80,g: 80,b: 80, a: 200)
    let buttonActivatedColor = Color(r: 40,g: 40,b: 40, a: 200)
    var buttonColor = Color(r: 80,g: 80,b: 80, a: 200)
    
    var buttonPressed = false
    var buttonFirstPencilLoc = Vec2()
    var buttonCurrentPencilLoc = Vec2()
    var newSize: Float = 256
    
    //MARK: - Setup
    init(device: MTLDevice, with v: MTKView) {
        view = v
        txwidth = 2048
        txheight = 2736 // multiple of 16 px tile size
        //may need to change for a different screen
        winwidth = 2048
        winheight = 2732
        defaultBrush = Brush(n: "defaultBrush", w: txwidth, h: txheight)
        defaultBrush.size = 32
        defaultBrush.color = Color(r: 255, g: 0, b: 0,a:255)
        updatedBrush = Brush(n: "updatedBrush", w: txwidth, h: txheight)
        updatedBrush.size = 16
        updatedBrush.color = Color(r: 0, g: 255, b: 0,a:255)
        predictedBrush = Brush(n: "predictedBrush", w: txwidth, h: txheight)
        predictedBrush.size = 40
        predictedBrush.color = Color(r: 0, g: 0, b: 255,a:255)
        super.init()
        createCommandQueue(device: device)
        createPipelineState(device: device)
        createBuffers(device: device)
        createTextures(device: device)
        
        //clearCanvas(color: Color(r: 200, g: 40, b: 40))
        fillBrush(color: Color(r:40, g: 40, b: 200,a:255))
        replayBrushBuffer.reserveCapacity(maxTouch)
    }
    
    func createCommandQueue(device: MTLDevice) {
        commandQueue = device.makeCommandQueue()
    }
    
    func createPipelineState(device: MTLDevice) {
        // The device will make a library for us
        let library = device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "basic_vertex")
        let fragmentFunction = library?.makeFunction(name: "basic_fragment")
        
        // Create basic descriptor
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        // Attach the pixel format that si the same as the MetalView
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        renderPipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormat(rawValue: 252)!
        // Attach the shader functions
        renderPipelineDescriptor.vertexFunction = vertexFunction
        renderPipelineDescriptor.fragmentFunction = fragmentFunction
        
        // Try to update the state of the renderPipeline
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            print(error.localizedDescription)
        }
        
        //for subsequent pipelines
        renderPipelineDescriptor.depthAttachmentPixelFormat = .invalid
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.isDepthWriteEnabled = false
        depthStateDescriptor.depthCompareFunction = .never
        device.makeDepthStencilState(descriptor: depthStateDescriptor)
        
        // create clear fragment pipeline
        let clearFragmentFunction = library?.makeFunction(name: "clear_fragment")
        renderPipelineDescriptor.fragmentFunction = clearFragmentFunction
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
        do {
            clearPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            print(error.localizedDescription)
        }
        
        // create a brush pipeline
        let brushVertexFunction = library?.makeFunction(name: "brush_vertex")
        let brushFragmentFunction = library?.makeFunction(name: "brush_fragment")

        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
        renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        renderPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        renderPipelineDescriptor.vertexFunction = brushVertexFunction
        renderPipelineDescriptor.fragmentFunction = brushFragmentFunction
        
        do {
            brushPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            print(error.localizedDescription)
        }
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].offset = MemoryLayout<float3>.size
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        renderPipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        let strokeVertexFunction = library?.makeFunction(name: "stroke_vertex")
        renderPipelineDescriptor.vertexFunction = strokeVertexFunction
        do {
            strokePipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func createBuffers(device: MTLDevice) {
        uniformBuffer = device.makeBuffer(length: 8 * MemoryLayout<Float>.stride)
        vertexBuffer = device.makeBuffer(bytes: vertices,
                                         length: MemoryLayout<Float>.size * vertices.count,
                                         options: [])
        indexBuffer = device.makeBuffer(bytes: indices,
                                        length: MemoryLayout<UInt16>.size * indices.count,
                                        options: [])
        uniformStrokeBuffer = device.makeBuffer(length: 3000 * MemoryLayout<BrushUniform>.stride)
    }
    
    func createTextures(device: MTLDevice) {
        // create canvas texture
        let txdesc = MTLTextureDescriptor()
        //txdesc.pixelFormat = MTLPixelFormat.BGRA8Unorm
        txdesc.pixelFormat = MTLPixelFormat.rgba8Unorm
        txdesc.usage = [.renderTarget, .shaderRead, .shaderWrite]
        txdesc.storageMode = MTLStorageMode.shared
        txdesc.textureType = MTLTextureType.type2D
        txdesc.width = txwidth
        txdesc.height = txheight
        displayTexture = device.makeTexture(descriptor: txdesc)
        //txdesc.pixelFormat = MTLPixelFormat.rgba16Unorm
        canvasTexture = device.makeTexture(descriptor: txdesc)
        uiTexture = device.makeTexture(descriptor: txdesc)
        txdesc.usage = [.shaderRead, .shaderWrite]
        txdesc.width = Int(defaultBrushSize)
        txdesc.height = Int(defaultBrushSize)
        brushTexture = device.makeTexture(descriptor: txdesc)
        
    }
    func fillColor(imgData: UnsafeMutablePointer<UInt8>, width: Int, height: Int, color: Color) -> UnsafeMutablePointer<UInt8>{
        var i = 0
        for _ in 0 ..< height {
            for _ in 0 ..< width {
                imgData[i+0] = color.r
                imgData[i+1] = color.g
                imgData[i+2] = color.b
                imgData[i+3] = 0xff
                i+=4
            }
        }
        return imgData
    }
    
    func fillBrush(color: Color) {
        let bytesPerPixel = 4
        let kw = Int(defaultBrushSize)
        let kernelSize = kw * kw * 4
        let brushData = UnsafeMutablePointer<UInt8>.allocate(capacity: kernelSize)
        let center = ivec2(kw/2, kw/2)
        for x in 0 ..< kw {
            for y in 0 ..< kw {
                let i = (y * kw + x) * 4 //4 is num components per pixel
                //if distance from center is more than brush radius, 0 alpha
                brushData[i+0] = color.r
                brushData[i+1] = color.g
                brushData[i+2] = color.b
                if pow(Decimal(x - center.x), 2) + pow(Decimal(y - center.y), 2) < pow(Decimal(kw/2), 2) {
                    brushData[i+3] = 0xff
                } else {
                    brushData[i+3] = 0
                }
            }
        }
        let region = MTLRegionMake2D(0, 0, kw, kw)
        brushTexture.replace(region: region, mipmapLevel: 0, withBytes: brushData, bytesPerRow: kw*bytesPerPixel)
        brushData.deallocate()
    }
    
    func clearCanvas(color: Color) {
        let bytesPerPixel = 4

        //draw grids
        let w = 8
        let markerColor = Color(r: 0,g: 0,b: 0,a:255)
        var markerData = UnsafeMutablePointer<UInt8>.allocate(capacity: w*w*4)
        markerData = fillColor(imgData: markerData, width: w, height: w, color: markerColor)
        for row in 0 ... 7 {
            for col in 0 ... 7 {
                let x = row * txwidth / 8
                let y = col * txheight / 8
                let region = MTLRegionMake2D(x, y, w, w)
                canvasTexture.replace(region: region, mipmapLevel: 0, withBytes: markerData, bytesPerRow: w*bytesPerPixel)
            }
        }
        markerData.deallocate()
    }
    
    //MARK: - touch
    func processTouchPosition(touch: UITouch, view: MTKView) -> Vec2 {
        let t = touch.preciseLocation(in: view)
        let txw = Float(txwidth)
        let txh = Float(txheight)
        let bounds = view.bounds.size
        let x = 2 * Float(t.x) / Float(bounds.width) * txw - txw
        let y = 2 * Float(t.y) / Float(bounds.height) * txh - txh
        let pos: Vec2 = Vec2(x: x,y: y)
        //let liv = touch.location(in: view)
        //print("processTouchPosition: \(pos), locInView: \(liv)")
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
        if buttonPressed {
            return
        }
        for touch in touches {
            guard let index = touch.estimationUpdateIndex else {
                continue
            }
            let pos = processTouchPosition(touch: touch, view: view)
            let first = updatedBrush.firstUpdateIndex == Int(index)
            updatedBrush.append(pos: pos, force: Float(touch.force), first: first)
            if first {
                print("first update: \(pos)")
            }
            //print("updated force: \(touch.force)")
        }
    }
    
    func didTouch(touches: Set<UITouch>, with event: UIEvent?, first: Bool = false, last: Bool = false, type: TouchType = .standard) {
        if replay {
            if replayBrushBuffer.isEmpty {
                replay = false
                let clearColor = MTLClearColorMake(200/255.0, 40/255.0, 40/255.0, 1.0)
                clearTexture(texture: canvasTexture, color: clearColor, in: view)
            } else {
                return
            }
        }
        
        //button hit eval
        if let touch = touches.first, touch.type == .direct {
            
            let target = Vec2(x: 0, y: -2000)
            let pos = processTouchPosition(touch: touch, view: view)
            let hit = v_len(a: target - pos) < 140.0
            //print("dist: \(v_len(a: target - pos))")
            if hit && first {
                buttonColor = buttonActivatedColor
                buttonPressed = true
                buttonFirstPencilLoc = Vec2()
                buttonCurrentPencilLoc = Vec2()
            }
            if last {
                buttonColor = defaultButtonColor
                buttonPressed = false
                updatedBrush.size = newSize
            }
        }
        
        
        //eval first
        if first {
            firstTouch = touches.first!
            if firstTouch!.type == .pencil {
                let pos = processTouchPosition(touch: firstTouch!, view: view)
                buttonFirstPencilLoc = pos
            }
            
            if firstTouch!.estimatedPropertiesExpectingUpdates != [] {
                if let estimationUpdateIndex = firstTouch?.estimationUpdateIndex {
                    updatedBrush.firstUpdateIndex = Int(estimationUpdateIndex)
                }
            }
        }

        //predicted touch
        if let predictedTouches = event!.predictedTouches(for: firstTouch!)
        {
            //print("predictedTouches:", predictedTouches.count)
            
            var firstOnce = first
            for predictedTouch in predictedTouches
            {
                //let locationInView =  predictedTouch.location(in: view)
                let pos = processTouchPosition(touch: predictedTouch, view: view)
                //predictedBrush.append(pos: pos, force: Float(predictedTouch.force), first: firstOnce)
                firstOnce = false
            }
        }
        
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
            //defaultBrush.append(pos: pos, force: Float(touch.force), first: firstOnce)
            firstOnce = false
            if touch.type == .pencil {
                buttonCurrentPencilLoc = pos
            }
            
            if enableReplay == true {
                guard let brush = defaultBrush.sampleBuffer.last else { return }
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

extension Renderer: MTKViewDelegate {

    func convert(sample: BrushSample) -> BrushUniform {
        let p = Vec2(x: sample.position.x / Float(txwidth),
                     y: sample.position.y / Float(txheight))
        let s = Vec2(x: sample.size / Float(txwidth),
                     y: sample.size / Float(txheight))
        let c = float4(Float(sample.color.r)/255.0,
                       Float(sample.color.g)/255.0,
                       Float(sample.color.b)/255.0,
                       Float(sample.color.a)/255.0 * powf(sample.force, 2.0))
        //print("convert color: \(c)")
        let strokeSample = BrushUniform(position: p, size: s, color: c)
        return strokeSample
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let clearColor = MTLClearColorMake(200/255.0, 40/255.0, 40/255.0, 1.0)
        clearTexture(texture: canvasTexture, color: clearColor, in: view)
    }
    
    func draw(in view: MTKView) {
        //draw on texture first, then present to screen
        //drawCanvas(in: view)
        if beginReplay {
            beginReplay = false
            let clearColor = MTLClearColorMake(200/255.0, 40/255.0, 40/255.0, 1.0)
            clearTexture(texture: canvasTexture, color: clearColor, in: view)
            clearCanvas(color: Color(r: 200, g: 40, b: 40,a:255))
        } else {
            //if (!replay && defaultBrush.inputBuffer.isEmpty) || (replay && replayBrushBuffer.isEmpty) {
            if false {
                framesIdle += 1
                if framesIdle > 60 {
                    view.isPaused = true
                    framesIdle = 61
                    return
                }
            } else {
                framesIdle = 0
            }
            drawCanvasInstanced(in: view)
            //drawUI
            let clearColor = MTLClearColorMake(200/255.0, 40/255.0, 40/255.0, 0.0)
            clearTexture(texture: uiTexture, color: clearColor, in: view)
            let element = BrushSample(position: Vec2(x: -0.0, y: -2000), size: 128.0, color: buttonColor)
            strokeBuffer.append(convert(sample: element))
            
            if buttonPressed {
                //get dist pencil has moved since button pressed
                let buttonLoc = Vec2(x: 0, y: -800)
                let distFirst = v_len(a: buttonFirstPencilLoc - buttonLoc)
                let distCurr = v_len(a: buttonLoc - buttonCurrentPencilLoc)
                let dist = distCurr - distFirst
                newSize = updatedBrush.size + dist / 2
                
                let brushSizeElement = BrushSample(position: buttonLoc, size: newSize, color: defaultButtonColor)
                strokeBuffer.append(convert(sample: brushSizeElement))
            }
            drawStroke(texture: uiTexture, in: view, brush: defaultBrush)
            strokeBuffer.removeAll(keepingCapacity: true)
        }
        drawFrame(in: view)
    }
        
    func prepareStrokeSegment(next: BrushSample, current: inout BrushSample) {
        //DEBUG paint 1 sample per segment
    /*
        let strokeSample = convert(sample: next)
        print("prepss: \(strokeSample)")
        strokeBuffer.append(strokeSample)
        return
    // */
        
        var spacing: Float = 1.0//max(1.0, brush.size / 30.0)
        let d = v_len(a: (next.position - current.position))
        var n: Int = Int(d / spacing)
        if n > 400 {
            n = 400
            spacing = d / Float(n)
        }
        let step = v_norm(a: (next.position - current.position)) * spacing
        let df: Float = (next.force - current.force) / Float(n + 1)
        //print("force: \(c.force) df: \(df) ")
        
        for _ in 0 ..< n {
            if strokeBuffer.count == 3000 {
                break;
            }
            let strokeSample = convert(sample: current)
            strokeBuffer.append(strokeSample)
            
            current.position = current.position + step
            current.force += df
        }
        let pos = current.position
        current = next
        current.position = pos
    }
    
    func prepareStroke(in view: MTKView, brush: inout Brush) {
        let newStroke = !brush.sampleBuffer.isEmpty && brush.sampleBuffer.first!.first
        var c = newStroke ? brush.sampleBuffer.first : brush.prevSample
        for sample in brush.sampleBuffer {
            prepareStrokeSegment(next: sample, current: &(c)!)
        }
        brush.prevSample = c!
        brush.sampleBuffer.removeAll()
    }
    
    func drawCanvasInstanced(in view: MTKView) {
        if replay {
            if replayBrushBuffer.isEmpty {
                return
            }
            var c = defaultBrush.prevSample
            var sample = replayBrushBuffer.removeFirst()
            if sample.first {
                c = sample
                if !replayBrushBuffer.isEmpty {
                    sample = replayBrushBuffer.removeFirst()
                }
            }
            prepareStrokeSegment(next: sample, current: &c)
            if strokeBuffer.count > 0 {
                drawStroke(texture: canvasTexture, in: view, brush: defaultBrush)
                strokeBuffer.removeAll(keepingCapacity: true)
            }
        } else {
            prepareStroke(in: view, brush: &updatedBrush)
            prepareStroke(in: view, brush: &defaultBrush)
            prepareStroke(in: view, brush: &predictedBrush)
            if !strokeBuffer.isEmpty {
                drawStroke(texture: canvasTexture, in: view, brush: defaultBrush)
                strokeBuffer.removeAll(keepingCapacity: true)
            }
        }
    }
    
    func clearTexture(texture: MTLTexture, color: MTLClearColor, in view: MTKView) {
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = color
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        // Create a buffer from the commandQueue
        let commandBuffer = commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        commandEncoder?.setRenderPipelineState(clearPipelineState)
        commandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        commandEncoder?.setFragmentTexture(brushTexture, index: 0)
        
        commandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        commandEncoder?.endEncoding()
        commandBuffer?.commit()
    }
    
    func drawFrame(in view: MTKView) {
        // Get the current drawable and descriptor
        guard let drawable = view.currentDrawable,
            let renderPassDescriptor = view.currentRenderPassDescriptor else {
                return
        }
        
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        //renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
        // Create a buffer from the commandQueue
        let commandBuffer = commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        commandEncoder?.setRenderPipelineState(renderPipelineState)
        // Pass in the vertexBuffer into index 0
        commandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        // Draw primitive at vertextStart 0
        commandEncoder?.setFragmentTexture(canvasTexture, index: 0)
        commandEncoder?.setFragmentTexture(uiTexture, index: 1)
        commandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        
        commandEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
    
    /*
    //drawing just 1 thing, consider replace with drawStroke w/ instance of 1
    func drawBrush(in view: MTKView, brush: BrushSample) {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = imageTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .load
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        let uniformBuffer_ptr = uniformBuffer.contents().assumingMemoryBound(to: Float.self)
        let b = convertToUniform(from: brush)
        uniformBuffer_ptr[0] = b.position.x
        uniformBuffer_ptr[1] = b.position.y
        
        //print ("drawBrush \(brush.position)")
        uniformBuffer_ptr[2] = b.size.x
        uniformBuffer_ptr[3] = b.size.y
        
        uniformBuffer_ptr[4] = b.color.x
        uniformBuffer_ptr[5] = b.color.y
        uniformBuffer_ptr[6] = b.color.z
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        commandEncoder?.setRenderPipelineState(strokePipelineState)
        
        commandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        commandEncoder?.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        
        commandEncoder?.setFragmentTexture(brushTexture, index: 0)
        commandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count, instanceCount: 1)
        commandEncoder?.endEncoding()
        commandBuffer?.commit()
    }
 */
    
    func drawStroke(texture: MTLTexture, in view: MTKView, brush: Brush) {

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .load
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        let uniformBuffer_ptr = uniformStrokeBuffer.contents()//.assumingMemoryBound(to: Float.self)
        memcpy(uniformBuffer_ptr, strokeBuffer, strokeBuffer.count * MemoryLayout<BrushUniform>.stride)

        let commandBuffer = commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        commandEncoder?.setRenderPipelineState(strokePipelineState)
        
        commandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        commandEncoder?.setVertexBuffer(uniformStrokeBuffer, offset: 0, index: 1)
        commandEncoder?.setFragmentTexture(brushTexture, index: 0)
        
        commandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count, instanceCount: strokeBuffer.count)
        //print ("samples: \(strokeBuffer.count)")
        commandEncoder?.endEncoding()
        commandBuffer?.commit()
    }
}


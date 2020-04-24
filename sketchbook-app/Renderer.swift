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
    init () {}
    init (_ _x: Float) {
        x = _x
        y = _x
    }
    init (_ _x: Float, _ _y: Float) {
        x = _x
        y = _y
    }
}

extension Vec2: CustomStringConvertible {
    var description: String {
        return "\(x), \(y)"
    }
}
    
extension Vec2 {
    static func + (left: Vec2, right: Vec2) -> Vec2 {
        return Vec2(left.x + right.x, left.y+right.y)
    }
    static func - (left: Vec2, right: Vec2) -> Vec2 {
        return Vec2(left.x - right.x, left.y-right.y)
    }
    static func * (left: Vec2, right: Vec2) -> Vec2 {
        return Vec2(left.x * right.x, left.y*right.y)
    }
    static func * (left: Vec2, right: Float) -> Vec2 {
        return Vec2(left.x * right, left.y*right)
    }
    static func / (left: Vec2, right: Float) -> Vec2 {
        return Vec2(left.x / right, left.y/right)
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

//struct used in metal shaders
struct BrushUniform {
    var position: Vec2
    var size: Vec2
    var color: float4
    var txIndex: uint = 1
}

class TextureBox {
    static var _id : Int = 0
    var t: [MTLTexture?] = []//nil, nil, nil]
    var id : Int
    init() {
        id = TextureBox._id
        TextureBox._id += 1
        t.reserveCapacity(8)
    }
    
}

class Renderer: NSObject {
    var view: MTKView!
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var commandBuffer: MTLCommandBuffer!
    
    var renderPipelineState: MTLRenderPipelineState!
    var brushPipelineState: MTLRenderPipelineState!
    var strokePipelineState: MTLRenderPipelineState!
    var clearPipelineState: MTLRenderPipelineState!
    
    var fence: MTLFence!
    let rdpUI = MTLRenderPassDescriptor()
    let rdpCanvas = MTLRenderPassDescriptor()
    
    var uniformBuffer: MTLBuffer! = nil;
    var vertexBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    var uniformStrokeBuffer: MTLBuffer!
    var uniformUIBuffer: MTLBuffer!
    var uniformCPBuffer: MTLBuffer!
    
    var uniformStagingBuffer: [BrushUniform] = []
    
    //for a fullframe quad
    let vertices:[Float] = [
    -1.0,-1.0, 0.0,   0.0, 0.0,
    1.0,-1.0, 0.0,   1.0, 0.0,
    1.0, 1.0, 0.0,   1.0, 2732.0/2736.0,
    1.0, 1.0, 0.0,   1.0, 2732.0/2736.0,
    -1.0, 1.0, 0.0,   0.0, 2732.0/2736.0,
    -1.0,-1.0, 0.0,   0.0, 0.0]
    let indices: [UInt16] = [0,1,2,2,4,0]
    
    var stampTextures = TextureBox()
    //var stampTextures: [MTLTexture?] = [nil, nil, nil] //TODO change array size in Shaders.metal
    var brushTexture: MTLTexture! = nil
    var colorPickerTexture: MTLTexture! = nil
    var colorPickerHueTexture: MTLTexture! = nil
    var canvasTexture: MTLTexture! = nil
    var uiTextures: [MTLTexture?] = [nil, nil]
    var uiTexture: MTLTexture! = nil
    var cpTexture: MTLTexture! = nil
    var displayTexture: MTLTexture! = nil
    
    var winwidth: Int = 0
    var winheight: Int = 0
    var txwidth: Int = 0
    var txheight: Int = 0

    var framesIdle: UInt = 0
    
    //ui stuff
    var uitIndex = 0
    let clearColor = MTLClearColorMake(00/255.0, 0/255.0, 0/255.0, 0.0)
    let defaultColor = MTLClearColorMake(200/255.0, 40/255.0, 40/255.0, 1.0)

    var uiManager: UIManager? = nil
    var inputManager: InputManager? = nil

    var standardBrush: Brush? = nil
    
    //MARK: - Setup
    init(d: MTLDevice, with v: MTKView) {
        device = d
        view = v
        txwidth = 2048
        txheight = 2736 // multiple of 16 px tile size
        //may need to change for a different screen
        winwidth = 2048
        winheight = 2732

        super.init()
        createTextures(device: device)
    }
    
    func init2(u: UIManager, i: InputManager) {
        uiManager = u
        inputManager = i
        standardBrush = inputManager?.updatedBrush
        
        createCommandQueue(device: device)
        //commandBuffer = commandQueue.makeCommandBuffer()
        createPipelineState(device: device)
        createBuffers(device: device)
        createDescriptors(device: device)
        
        fence = device.makeFence()
        
        //clearCanvas(color: Color(r: 200, g: 40, b: 40))
        fillBrush(color: Color(r:40, g: 40, b: 200,a:255))
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
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .rgba16Unorm
        do {
            clearPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        } catch {
            print(error.localizedDescription)
        }
        
        // create a brush pipeline
        let brushVertexFunction = library?.makeFunction(name: "brush_vertex")
        let brushFragmentFunction = library?.makeFunction(name: "brush_fragment")

        renderPipelineDescriptor.colorAttachments[0].pixelFormat = .rgba16Unorm
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
        uniformUIBuffer = device.makeBuffer(length: 300 * MemoryLayout<BrushUniform>.stride)
        uniformCPBuffer = device.makeBuffer(length: 30 * MemoryLayout<BrushUniform>.stride)
    }
    
    func createTexture(_ texdesc: MTLTextureDescriptor, size: Vec2) -> Int{
        print("createTexture");
        texdesc.pixelFormat = MTLPixelFormat.rgba8Unorm
        texdesc.usage = [.renderTarget, .shaderRead, .shaderWrite]
        texdesc.storageMode = MTLStorageMode.shared
        texdesc.textureType = MTLTextureType.type2D
        texdesc.width = Int(size.x)
        texdesc.height = Int(size.y)
        stampTextures.t.append(device.makeTexture(descriptor: texdesc))
        print("stamptexures id: \(stampTextures.id)")
        return stampTextures.t.count - 1
    }
    func createTextures(device: MTLDevice) {
        print ("tbox size: \(stampTextures.t.count)")
        // create canvas texture
        let txdesc = MTLTextureDescriptor()
        //txdesc.pixelFormat = MTLPixelFormat.BGRA8Unorm
        txdesc.pixelFormat = MTLPixelFormat.rgba16Unorm
        txdesc.usage = [.renderTarget, .shaderRead, .shaderWrite]
        txdesc.storageMode = MTLStorageMode.shared
        txdesc.textureType = MTLTextureType.type2D
        txdesc.width = txwidth
        txdesc.height = txheight
        displayTexture = device.makeTexture(descriptor: txdesc)
        //txdesc.pixelFormat = MTLPixelFormat.rgba16Unorm
        canvasTexture = device.makeTexture(descriptor: txdesc)
        cpTexture = device.makeTexture(descriptor: txdesc)
        uiTextures[0] = device.makeTexture(descriptor: txdesc)
        uiTextures[1] = device.makeTexture(descriptor: txdesc)
        uiTexture = uiTextures[uitIndex]
        txdesc.usage = [.shaderRead, .shaderWrite]
        txdesc.width = Int(defaultBrushSize)
        txdesc.height = Int(defaultBrushSize)
        //stampTextures.t[0] = device.makeTexture(descriptor: txdesc)
        stampTextures.t.append(device.makeTexture(descriptor: txdesc))
        //txdesc.width = uiManager!.colorPickerDim
        //txdesc.height = uiManager!.colorPickerDim
        ////stampTextures.t[1] = device.makeTexture(descriptor: txdesc)
        //stampTextures.t.append(device.makeTexture(descriptor: txdesc))
        //txdesc.width = uiManager!.widthHue
        //txdesc.height = uiManager!.heightHue
        ////stampTextures.t[2] = device.makeTexture(descriptor: txdesc)
        //stampTextures.t.append(device.makeTexture(descriptor: txdesc))
        
        print ("tbox size: \(stampTextures.t.count)")
        brushTexture = stampTextures.t[0]
        //colorPickerTexture = stampTextures.t[1]
        //colorPickerHueTexture = stampTextures.t[2]
    }
    
    func createDescriptors(device: MTLDevice) {
        rdpCanvas.colorAttachments[0].texture = canvasTexture
        rdpCanvas.colorAttachments[0].loadAction = .load
        rdpCanvas.colorAttachments[0].storeAction = .store
        
        rdpUI.colorAttachments[0].texture = uiTexture
        rdpUI.colorAttachments[0].loadAction = .clear
        rdpUI.colorAttachments[0].clearColor = clearColor
        rdpUI.colorAttachments[0].storeAction = .store
    }
    
    func nextUITexture() -> MTLTexture{
        uitIndex += 1
        uitIndex %= uiTextures.count
        return uiTextures[uitIndex]!
    }
    func fillColor(imgData: UnsafeMutablePointer<UInt16>, width: Int, height: Int, color: Color) -> UnsafeMutablePointer<UInt16>{
        var i = 0
        for _ in 0 ..< height {
            for _ in 0 ..< width {
                imgData[i + 0] = UInt16(color.r) * 256
                imgData[i + 1] = UInt16(color.g) * 256
                imgData[i + 2] = UInt16(color.b) * 256
                imgData[i + 3] = 0xffff
                i += 4
            }
        }
        return imgData
    }
    
    func fillBrush(color: Color) {
        let bytesPerPixel = 8
        let kw = Int(defaultBrushSize)
        let kernelSize = kw * kw * 4
        let brushData = UnsafeMutablePointer<UInt16>.allocate(capacity: kernelSize)
        let center = ivec2(kw/2, kw/2)
        for x in 0 ..< kw {
            for y in 0 ..< kw {
                let i = (y * kw + x) * 4 //4 is num components per pixel
                //if distance from center is more than brush radius, 0 alpha
                brushData[i + 0] = UInt16(color.r) * 256
                brushData[i + 1] = UInt16(color.g) * 256
                brushData[i + 2] = UInt16(color.b) * 256
                if pow(Decimal(x - center.x), 2) + pow(Decimal(y - center.y), 2) < pow(Decimal(kw / 2), 2) {
                    brushData[i + 3] = 0xffff
                } else {
                    brushData[i + 3] = 0
                }
            }
        }
        let region = MTLRegionMake2D(0, 0, kw, kw)
        brushTexture.replace(region: region, mipmapLevel: 0, withBytes: brushData, bytesPerRow: kw * bytesPerPixel)
        brushData.deallocate()
    }
    
    func clearCanvas(color: Color) {
        let bytesPerPixel = 8

        //draw grids
        let w = 8
        let markerColor = Color(r: 0,g: 0,b: 0,a:255)
        var markerData = UnsafeMutablePointer<UInt16>.allocate(capacity: w * w * 4)
        markerData = fillColor(imgData: markerData, width: w, height: w, color: markerColor)
        for row in 0 ... 7 {
            for col in 0 ... 7 {
                let x = row * txwidth / 8
                let y = col * txheight / 8
                let region = MTLRegionMake2D(x, y, w, w)
                canvasTexture.replace(region: region, mipmapLevel: 0, withBytes: markerData, bytesPerRow: w * bytesPerPixel)
            }
        }
        markerData.deallocate()
    }
}

extension Renderer: MTKViewDelegate {

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
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let clearColor = MTLClearColorMake(200/255.0, 40/255.0, 40/255.0, 1.0)
        clearTexture(texture: canvasTexture, color: clearColor, in: view)
        for t in uiTextures {
            clearTexture(texture: t!, color: clearColor, in: view)
        }
    }
    
    /* Primary draw function per frame
     * ignoring replay for now
     * 1. draw brush strokes onto canvas
     * 2. draw UI
     * 3. draw frame by combining brushes and UI
     * later optimizations:
     *  - Only draw UI if UI state changes
     *  - Only draw canvas if canvas needs changing
     *  - don't redraw at all if nothing changes (render pause)
     */
    func draw(in view: MTKView) {
        /*
        if beginReplay {
            beginReplay = false
            let clearColor = MTLClearColorMake(200/255.0, 40/255.0, 40/255.0, 1.0)
            clearTexture(texture: canvasTexture, color: clearColor, in: view)
            clearCanvas(color: Color(r: 200, g: 40, b: 40,a:255))
        } else
        // */
        if true {
            /*
            if (!replay && defaultBrush.inputBuffer.isEmpty) || (replay && replayBrushBuffer.isEmpty) {
                framesIdle += 1
                if framesIdle > 60 {
                    view.isPaused = true
                    framesIdle = 61
                    return
                }
            } else {
                framesIdle = 0
            }
            // */
            
            drawCanvasInstanced(in: view)
            
            uiManager!.getElements(stampTextures, &uniformStagingBuffer)

            //button for resizing brush
            var element = uiManager!.createResizeBrushButton()
            element.color = standardBrush!.color
            uniformStagingBuffer.append(convert(sample: element))
            
            if uiManager!.buttonPressed {
                element = uiManager!.createResizeBrush(brushSize: standardBrush!.size)
                element.color = standardBrush!.color
                uniformStagingBuffer.append(convert(sample: element))
            }
            
            //draw UI
            //note: UI texture implicitly cleared by rdpUI
            drawStroke(stamps: stampTextures.t, instanceBuffer: uniformStagingBuffer, uniformBuffer: uniformStrokeBuffer, rdp: rdpUI, in: view, wait: true)
            uniformStagingBuffer.removeAll(keepingCapacity: true)
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
        
        /* Goals:
         * Skip if next and current positions are the same
         * Draw at least once if current/next are NOT the same
         * Keep spacing at minimum 1 pixel
         * Don't draw too much, increase spacing with larger brushes
         * Keep num draws to 400 or less (stay under upper bound size of uniform buffer)
         */
        var spacing: Float = max(1.0, next.size / 30.0)
        let d = v_len(a: (next.position - current.position))
        if d == 0 {
            return
        }
        var n: Int = max(1, Int(d / spacing))
        if n > 400 {
            n = 400
            spacing = d / Float(n)
        }
        let step = v_norm(a: (next.position - current.position)) * spacing
        let df: Float = (next.force - current.force) / Float(n + 1)
        //print("force: \(c.force) df: \(df) ")
        
        let numpix = pow(current.size, 2) * Float(n)
        print("n: \(n), pix/frame: \(numpix)")
        for _ in 0 ..< n {
            if uniformStagingBuffer.count == 3000 {
                break;
            }
            let strokeSample = convert(sample: current)
            uniformStagingBuffer.append(strokeSample)
            
            current.position = current.position + step
            current.force += df
        }
        let pos = current.position
        current = next
        current.position = pos
    }
    
    func prepareStroke(in view: MTKView, brush: inout Brush) {
        let count = brush.sampleBuffer.count
        if count > 0 {
            print ("renderer: brush samples: \(count)")
        }
        
        let newStroke = !brush.sampleBuffer.isEmpty && brush.sampleBuffer.first!.first
        var c = newStroke ? brush.sampleBuffer.first : brush.prevSample
        for sample in brush.sampleBuffer {
            prepareStrokeSegment(next: sample, current: &(c)!)
        }
        brush.prevSample = c!
        brush.sampleBuffer.removeAll()
    }
    
    /*
    func drawReplayCanvas(in view: MTKView) {
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
            if uniformStagingBuffer.count > 0 {
                drawStroke(stamps: stampTextures, instanceBuffer: uniformStagingBuffer, uniformBuffer: uniformStrokeBuffer, rdp: rdpCanvas, in: view)
                uniformStagingBuffer.removeAll(keepingCapacity: true)
            }
        }
    }
 // */
    
    func drawCanvasInstanced(in view: MTKView) {
        //prepareStroke(in: view, brush: &(standardBrush)!)
        prepareStroke(in: view, brush: &(inputManager!.updatedBrush))
        //prepareStroke(in: view, brush: &defaultBrush)
        //prepareStroke(in: view, brush: &predictedBrush)
        if !uniformStagingBuffer.isEmpty {
            drawStroke(stamps: stampTextures.t, instanceBuffer: uniformStagingBuffer, uniformBuffer: uniformStrokeBuffer, rdp: rdpCanvas, in: view)
            uniformStagingBuffer.removeAll(keepingCapacity: true)
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
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
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
    
    func drawStroke(stamps: [MTLTexture?], instanceBuffer: [BrushUniform], uniformBuffer: MTLBuffer, rdp: MTLRenderPassDescriptor, in view: MTKView, wait: Bool = false) {

        let uniformBuffer_ptr = uniformBuffer.contents()//.assumingMemoryBound(to: Float.self)
        memcpy(uniformBuffer_ptr, instanceBuffer, instanceBuffer.count * MemoryLayout<BrushUniform>.stride)

        let commandBuffer = commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: rdp)
        commandEncoder?.setRenderPipelineState(strokePipelineState)
        
        commandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        commandEncoder?.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        let texRange: CountableRange = 0 ..< stamps.count
        commandEncoder?.setFragmentTextures(stamps, range: texRange)

        commandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count, instanceCount: instanceBuffer.count)
        //commandEncoder?.waitForFence(fence, before: .vertex)
        //commandEncoder?.updateFence(fence, after: .fragment)
        commandEncoder?.endEncoding()
        commandBuffer?.commit()
    }
}


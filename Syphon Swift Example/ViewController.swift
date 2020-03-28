import Cocoa
import AVFoundation
import Syphon

class ViewController: NSViewController {
    
    var displayLink: CVDisplayLink?
    var device: MTLDevice!
    
    var player: AVPlayer?
    var videoOutput: AVPlayerItemVideoOutput!
    var textureCache: CVMetalTextureCache?
    var syphonServer: SyphonMetalServer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        device = MTLCreateSystemDefaultDevice()
        
        player = AVPlayer(url: Bundle.main.url(forResource: "video", withExtension: "mov")!)
        
        let bufferAttributes: [String: Any] = [
            String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA),
            String(kCVPixelBufferMetalCompatibilityKey): true
        ]
        
        videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: bufferAttributes)
        videoOutput.suppressesPlayerRendering = true
        player?.currentItem?.add(videoOutput)
        
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        
        syphonServer = SyphonMetalServer(name: "Video", device: device)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        CVDisplayLinkSetOutputCallback(displayLink!, { (displayLink, inNow, inOutputTime, flagsIn, flagsOut, displayLinkContext) -> CVReturn in
            autoreleasepool {
                // interpret displayLinkContext as this class to call functions
                unsafeBitCast(displayLinkContext, to: ViewController.self).screenRefreshForTime(inOutputTime.pointee)
            }
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())
        
        CVDisplayLinkStart(displayLink!)
        player?.play()
    }
    
    func screenRefreshForTime(_ timestamp: CVTimeStamp) {
        let itemTime = videoOutput.itemTime(for: timestamp)
        
        guard videoOutput.hasNewPixelBuffer(forItemTime: itemTime),
            let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil),
            let textureCache = textureCache
            else { return }
        
        var videoTexture: CVMetalTexture?
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        guard
            CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, .bgra8Unorm, width, height, 0, &videoTexture) == kCVReturnSuccess,
            let newVideoTexture = videoTexture,
            let texture = CVMetalTextureGetTexture(newVideoTexture)
            else { return }
        
        syphonServer?.publishFrameTexture(texture)
    }
    
    @IBAction func rewind(_ sender: AnyObject) {
        player?.seek(to: CMTime.zero)
        player?.play()
    }
}

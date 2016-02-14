import Cocoa
import AVFoundation

class ViewController: NSViewController {
    
    var displayTimer: NSTimer?
    var context: NSOpenGLContext?
    
    var player: AVPlayer?
    var videoOutput: AVPlayerItemVideoOutput!
    var texture = GLuint()
    var size = NSSize(width: 512, height: 512)
    var syphonServer: SyphonServer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        displayTimer = NSTimer.scheduledTimerWithTimeInterval(1 / 60, target: self, selector: "screenRefresh", userInfo: nil, repeats: true)
        
        let contextAttributes: [NSOpenGLPixelFormatAttribute] = [
            NSOpenGLPixelFormatAttribute(NSOpenGLPFADoubleBuffer),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAColorSize), NSOpenGLPixelFormatAttribute(32),
            NSOpenGLPixelFormatAttribute(0)
        ]
        
        context = NSOpenGLContext(format: NSOpenGLPixelFormat(attributes: contextAttributes)!, shareContext: nil)
        context?.makeCurrentContext()
        
        if texture == 0 { glGenTextures(1, &texture) }
        
        syphonServer = SyphonServer(name: "Video", context: context!.CGLContextObj, options: nil)
        
        player = AVPlayer(URL: NSBundle.mainBundle().URLForResource("video", withExtension: "mov")!)
        
        let bufferAttributes: [String: AnyObject] = [
            String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA),
            String(kCVPixelBufferIOSurfacePropertiesKey): [String: AnyObject](),
            String(kCVPixelBufferOpenGLCompatibilityKey): true
        ]
        
        videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: bufferAttributes)
        videoOutput.suppressesPlayerRendering = true
        player?.currentItem?.addOutput(videoOutput)
        
        player?.play()
    }
    
    func screenRefresh() {
        let itemTime = videoOutput.itemTimeForHostTime(CACurrentMediaTime())
        if videoOutput.hasNewPixelBufferForItemTime(itemTime) {
            if let pixelBuffer = videoOutput.copyPixelBufferForItemTime(itemTime, itemTimeForDisplay: nil) {
                if let surface = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() {
                    
                    size = NSSize(width: IOSurfaceGetWidth(surface), height: IOSurfaceGetHeight(surface))
                    
                    context?.makeCurrentContext()
                    
                    glBindTexture(GLenum(GL_TEXTURE_RECTANGLE_EXT), texture)
                    CGLTexImageIOSurface2D(context!.CGLContextObj, GLenum(GL_TEXTURE_RECTANGLE_EXT), GLenum(GL_RGBA), GLsizei(size.width), GLsizei(size.height), GLenum(GL_BGRA), GLenum(GL_UNSIGNED_INT_8_8_8_8_REV), surface, 0)
                }
            }
        }
        
        syphonServer?.publishFrameTexture(texture, textureTarget: GLenum(GL_TEXTURE_RECTANGLE_EXT), imageRegion: NSRect(origin: CGPoint(x: 0, y: 0), size: size), textureDimensions: size, flipped: true)
    }
    
    @IBAction func rewind(sender: AnyObject) {
        player?.seekToTime(kCMTimeZero)
    }
}

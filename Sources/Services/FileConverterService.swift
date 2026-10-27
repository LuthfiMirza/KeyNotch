import Cocoa
import Vision
import ImageIO

public enum TargetImageFormat {
    case jpg(quality: Float)
    case png
    
    var fileExtension: String {
        switch self {
        case .jpg: return "jpg"
        case .png: return "png"
        }
    }
    
    var uti: CFString {
        switch self {
        case .jpg: return "public.jpeg" as CFString
        case .png: return "public.png" as CFString
        }
    }
}

public final class FileConverterService {
    public static let shared = FileConverterService()
    
    private init() {}
    
    // MARK: - Image Conversion & Compression (CGImageSource & CGImageDestination)
    
    public func convertImage(url: URL, to format: TargetImageFormat, completion: @escaping (URL?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let originalName = url.deletingPathExtension().lastPathComponent
            let suffix = format.fileExtension == "jpg" ? "compressed" : "converted"
            let targetFileName = "\(originalName)_\(suffix).\(format.fileExtension)"
            
            // Output in original folder if writable, else standard Downloads folder
            let targetDirectory: URL
            if FileManager.default.isWritableFile(atPath: url.deletingLastPathComponent().path) {
                targetDirectory = url.deletingLastPathComponent()
            } else {
                targetDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? url.deletingLastPathComponent()
            }
            
            let destinationURL = targetDirectory.appendingPathComponent(targetFileName)
            
            guard let destination = CGImageDestinationCreateWithURL(
                destinationURL as CFURL,
                format.uti,
                1,
                nil
            ) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            var options: [CFString: Any] = [:]
            if case .jpg(let quality) = format {
                options[kCGImageDestinationLossyCompressionQuality] = quality
            }
            
            CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
            let success = CGImageDestinationFinalize(destination)
            
            DispatchQueue.main.async {
                if success {
                    IslandState.shared.triggerHUD(
                        HUDPayload(
                            type: .custom,
                            title: "Image Saved",
                            subtitle: targetFileName,
                            iconName: "photo.fill",
                            isSuccess: true
                        )
                    )
                    completion(destinationURL)
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - Quick Vision OCR
    
    public func performOCR(on url: URL, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNRecognizeTextRequest { (request, error) in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                let lines = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                let fullText = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                
                DispatchQueue.main.async {
                    if !fullText.isEmpty {
                        // Copy straight to system clipboard
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(fullText, forType: .string)
                        
                        IslandState.shared.triggerHUD(
                            HUDPayload(
                                type: .custom,
                                title: "OCR Text Copied",
                                subtitle: "\(lines.count) lines extracted",
                                iconName: "text.viewfinder",
                                isSuccess: true
                            )
                        )
                        completion(fullText)
                    } else {
                        IslandState.shared.triggerHUD(
                            HUDPayload(
                                type: .custom,
                                title: "OCR Finished",
                                subtitle: "No text detected in image",
                                iconName: "text.viewfinder",
                                isSuccess: false
                            )
                        )
                        completion(nil)
                    }
                }
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(url: url, options: [:])
            do {
                try handler.perform([request])
            } catch {
                NSLog("[KeyNotch OCR] Error: %@", error.localizedDescription)
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
}

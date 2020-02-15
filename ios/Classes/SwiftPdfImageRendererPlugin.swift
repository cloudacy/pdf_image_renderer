import Flutter
import UIKit

public class SwiftPdfImageRendererPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "pdf_image_renderer", binaryMessenger: registrar.messenger())
    let instance = SwiftPdfImageRendererPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "renderPDFPage":
      result(renderPDFPageHandler(call))
    case "getPDFPageSize":
      result(pdfPageSizeHandler(call))
    case "getPDFPageCount":
      result(pdfPageCountHandler(call))
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func getDictionaryArguments(_ call: FlutterMethodCall) throws -> Dictionary<String, Any> {
    guard let arguments = call.arguments as? Dictionary<String, Any> else {
      throw PdfImageRendererError.badArguments
    }
    
    return arguments
  }
  
  private func getPdfDocument(_ call: FlutterMethodCall) throws -> CGPDFDocument {
    let arguments = try getDictionaryArguments(call)
    
    guard let path = arguments["path"] as? String else {
      throw PdfImageRendererError.badArgument("path")
    }
    
    guard let pdf = CGPDFDocument(URL(fileURLWithPath: path, isDirectory: false) as CFURL) else {
      throw PdfImageRendererError.openError(path)
    }
    
    return pdf
  }
  
  private func getPdfPage(_ call: FlutterMethodCall) throws -> CGPDFPage {
    let arguments = try getDictionaryArguments(call)

    guard var pageIndex = arguments["page"] as? Int else {
      throw PdfImageRendererError.badArgument("page")
    }
    
    // PDF Pages in swift start with 1, so we add 1 to the pageIndex
    pageIndex += 1
    
    let pdf = try getPdfDocument(call)
    
    guard let page = pdf.page(at: pageIndex + 1) else {
      throw PdfImageRendererError.openPageError(pageIndex)
    }
    
    return page
  }
  
  private func renderPDFPageHandler(_ call: FlutterMethodCall) -> Any? {
    let arguments: Dictionary<String, Any>
    let page: CGPDFPage
    
    do {
      page = try getPdfPage(call)
      arguments = try getDictionaryArguments(call)
    } catch {
      return handlePdfError(error)
    }
    
    guard let width = arguments["width"] as? Int else {
      return handlePdfError(PdfImageRendererError.badArgument("width"))
    }
    
    guard let height = arguments["height"] as? Int else {
      return handlePdfError(PdfImageRendererError.badArgument("height"))
    }
    
    let image: UIImage
    let pageRect = page.getBoxRect(CGPDFBox.mediaBox)
    
    let scale = Double(arguments["scale"] as? Int ?? 1)
    
    let x = arguments["x"] as? Int ?? 0
    let y = arguments["y"] as? Int ?? 0
    
    let size = CGSize(width: Double(width) * scale, height: Double(height) * scale)
    let scaleCGFloat = CGFloat(scale)
    let xCGFloat = CGFloat(-x) * scaleCGFloat
    let yCGFloat = CGFloat(-y) * scaleCGFloat

    if #available(iOS 10.0, *) {
      let renderer = UIGraphicsImageRenderer(size: size)

      image = renderer.image {ctx in
        UIColor.white.set()
        ctx.fill(CGRect(x: 0, y: 0, width: Double(width) * scale, height: Double(height) * scale))

        ctx.cgContext.translateBy(x: xCGFloat, y: pageRect.size.height * scaleCGFloat + yCGFloat)
        ctx.cgContext.scaleBy(x: scaleCGFloat, y: -scaleCGFloat)

        ctx.cgContext.drawPDFPage(page)
      }
    } else {
      // Fallback on earlier versions
      UIGraphicsBeginImageContext(size)
      let ctx = UIGraphicsGetCurrentContext()!
      UIColor.white.set()
      ctx.fill(CGRect(x: 0, y: 0, width: Double(width) * scale, height: Double(height) * scale))

      ctx.translateBy(x: xCGFloat, y: pageRect.size.height * scaleCGFloat + yCGFloat)
      ctx.scaleBy(x: scaleCGFloat, y: -scaleCGFloat)

      ctx.drawPDFPage(page)

      image = UIGraphicsGetImageFromCurrentImageContext()!
      UIGraphicsEndImageContext()
    }

    return image.pngData()
  }

  private func pdfPageCountHandler(_ call: FlutterMethodCall) -> Any? {
    let pdf: CGPDFDocument
    
    do {
      pdf = try getPdfDocument(call)
    } catch {
      return handlePdfError(error)
    }
    
    return pdf.numberOfPages
  }

  private func pdfPageSizeHandler(_ call: FlutterMethodCall) -> Any? {
    let page: CGPDFPage
    
    do {
      page = try getPdfPage(call)
    } catch {
      return handlePdfError(error)
    }

    let pageRect = page.getBoxRect(CGPDFBox.mediaBox)
    
    return [
      "width": Int(pageRect.width),
      "height": Int(pageRect.height)
    ]
  }
  
  private func handlePdfError(_ error: Error) -> FlutterError {
    switch error {
    case PdfImageRendererError.badArgument(let argument):
      return FlutterError(code: "BAD_ARGS", message: "Argument \(argument) not set", details: nil)
    default:
      return FlutterError(code: "UNKNOWN_ERROR", message: "An unknown error occured.", details: nil)
    }
  }
}

enum PdfImageRendererError: Error {
  case badArguments
  case badArgument(_ argument: String)
  case openError(_ path: String)
  case openPageError(_ page: Int)
}

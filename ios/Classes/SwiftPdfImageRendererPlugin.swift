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
    case "openPDF":
      openPDFHandler(call, result: result)
    case "closePDF":
      closePDFHandler(call, result: result)
    case "openPDFPage":
      openPDFPageHandler(call, result: result)
    case "renderPDFPage":
      renderPDFPageHandler(call, result: result)
    case "getPDFPageSize":
      pdfPageSizeHandler(call, result: result)
    case "getPDFPageCount":
      pdfPageCountHandler(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private var openPdfs: [Int: CGPDFDocument] = [:]
  private var openPdfPages: [Int: [Int: CGPDFPage]] = [:]
  
  private func getDictionaryArguments(_ call: FlutterMethodCall) throws -> Dictionary<String, Any> {
    guard let arguments = call.arguments as? Dictionary<String, Any> else {
      throw PdfImageRendererError.badArguments
    }
    
    return arguments
  }
  
  private func openPdfDocument(_ call: FlutterMethodCall) throws -> Int {
    let arguments = try getDictionaryArguments(call)
    
    guard let path = arguments["path"] as? String else {
      throw PdfImageRendererError.badArgument("path")
    }
    
    if (openPdfs[path.hashValue] != nil) {
      return path.hashValue
    }

    let pathURL = URL(fileURLWithPath: path, isDirectory: false) as CFURL
    
    guard let pdf = CGPDFDocument(pathURL) else {
      throw PdfImageRendererError.openError(path)
    }
    
    openPdfs[path.hashValue] = pdf
    
    return path.hashValue
  }
  
  private func closePdfDocument(_ hashValue: Int) throws {   
    if (openPdfs[hashValue] == nil) {
      throw PdfImageRendererError.closeError(hashValue)
    }
    
    openPdfs[hashValue] = nil
  }
  
  private func getPdfDocument(_ hashValue: Int) throws -> CGPDFDocument {
    if (openPdfs[hashValue] == nil) {
      throw PdfImageRendererError.notOpen(hashValue)
    }

    return openPdfs[hashValue]!
  }
  
  private func getPdfPage(_ hashValue: Int, pageIndex: Int) throws -> CGPDFPage {
    if (openPdfPages[hashValue] == nil || openPdfPages[hashValue]![pageIndex] == nil) {
      throw PdfImageRendererError.notOpen(hashValue)
    }

    return openPdfPages[hashValue]![pageIndex]!
  }
  
  private func renderPdfPage(page: CGPDFPage, width: Int, height: Int, scale: Double, x: Int, y: Int) -> Data? {
    let image: UIImage
    
    let pageRect = page.getBoxRect(CGPDFBox.mediaBox)
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
  
  private func openPDFHandler(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    NSLog("Start open")

    do {
      let hash = try openPdfDocument(call)
      NSLog("Finish open")
      result(hash)
    } catch {
      result(self.handlePdfError(error))
    }

    result(nil)
  }

  private func closePDFHandler(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    NSLog("Closing PDF")

    do {
      let args = try getDictionaryArguments(call)

      guard let hash = args["pdf"] as? Int else {
        throw PdfImageRendererError.badArgument("pdf")
      }

      try closePdfDocument(hash)
    } catch {
      result(self.handlePdfError(error))
    }

    result(nil)
  }
  
  private func openPDFPageHandler(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    NSLog("Start open page")
    do {
      let args = try getDictionaryArguments(call)
      
      guard let hash = args["pdf"] as? Int else {
        throw PdfImageRendererError.badArgument("pdf")
      }
      
      guard var pageIndex = args["page"] as? Int else {
        throw PdfImageRendererError.badArgument("page")
      }
      
      // PDF Pages in swift start with 1, so we add 1 to the pageIndex
      pageIndex += 1

      let pdf = try getPdfDocumentHandler(args)
      
      guard let page = pdf.page(at: pageIndex) else {
        throw PdfImageRendererError.openPageError(pageIndex)
      }
      
      if (openPdfPages[hash] == nil) {
        openPdfPages[hash] = [:]
      }
      
      openPdfPages[hash]![pageIndex] = page
      NSLog("Finish open page")
      result(pageIndex)
    } catch {
      result(self.handlePdfError(error))
    }

    result(nil)
  }
  
  private func getPdfDocumentHandler(_ args: [String: Any]) throws -> CGPDFDocument {
    guard let hash = args["pdf"] as? Int else {
      throw PdfImageRendererError.badArgument("pdf")
    }
    
    return try getPdfDocument(hash)
  }
  
  private func getPdfPageHandler(_ args: [String: Any]) throws -> CGPDFPage {
    guard let hash = args["pdf"] as? Int else {
      throw PdfImageRendererError.badArgument("pdf")
    }
    
    guard var pageIndex = args["page"] as? Int else {
      throw PdfImageRendererError.badArgument("page")
    }
    
    // PDF Pages in swift start with 1, so we add 1 to the pageIndex
    pageIndex += 1
    
    return try getPdfPage(hash, pageIndex: pageIndex)
  }
  
  private func renderPDFPageHandler(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .background).async {
      let arguments: Dictionary<String, Any>
      let page: CGPDFPage

      do {
        arguments = try self.getDictionaryArguments(call)
        page = try self.getPdfPageHandler(arguments)
      } catch {
        DispatchQueue.main.async {
          result(self.handlePdfError(error))
        }
        return
      }
      
      guard let width = arguments["width"] as? Int else {
        DispatchQueue.main.async {
          result(self.handlePdfError(PdfImageRendererError.badArgument("width")))
        }
        return
      }
      
      guard let height = arguments["height"] as? Int else {
        DispatchQueue.main.async {
          result(self.handlePdfError(PdfImageRendererError.badArgument("height")))
        }
        return
      }
      
      let scale = arguments["scale"] as? Double ?? 1.0
      
      let x = arguments["x"] as? Int ?? 0
      let y = arguments["y"] as? Int ?? 0
      
      var data: Data?
    
      data = self.renderPdfPage(page: page, width: width, height: height, scale: scale, x: x, y: y)
      
      DispatchQueue.main.async {
        result(data)
      }
    }
  }

  private func pdfPageCountHandler(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .background).async {
      let pdf: CGPDFDocument
      
      do {
        let arguments = try self.getDictionaryArguments(call)
        pdf = try self.getPdfDocumentHandler(arguments)
      } catch {
        DispatchQueue.main.async {
          result(self.handlePdfError(error))
        }
        return
      }

      DispatchQueue.main.async {
        result(pdf.numberOfPages)
      }
    }
  }

  private func pdfPageSizeHandler(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .background).async {
      let page: CGPDFPage
      
      do {
        let arguments = try self.getDictionaryArguments(call)
        page = try self.getPdfPageHandler(arguments)
      } catch {
        DispatchQueue.main.async {
          result(self.handlePdfError(error))
        }
        return
      }

      let pageRect = page.getBoxRect(CGPDFBox.mediaBox)

      DispatchQueue.main.async {
        result([
          "width": Int(pageRect.width),
          "height": Int(pageRect.height)
        ])
      }
    }
  }
  
  private func handlePdfError(_ error: Error) -> FlutterError {
    switch error {
    case PdfImageRendererError.badArguments:
      return FlutterError(code: "BAD_ARGS", message: "Bad arguments type", details: "Arguments have to be of type Dictionary<String, Any>.")
    case PdfImageRendererError.badArgument(let argument):
      return FlutterError(code: "BAD_ARGS", message: "Argument \(argument) not set", details: nil)
    case PdfImageRendererError.openError(let path):
      return FlutterError(code: "ERR_OPEN", message: "Error while opening the pdf document for path \(path)", details: nil)
    case PdfImageRendererError.closeError(let hash):
      return FlutterError(code: "ERR_CLOSE", message: "Error while closing the pdf document with hash \(hash)", details: nil)
    case PdfImageRendererError.notOpen(let hash):
      return FlutterError(code: "ERR_NOT_OPEN", message: "The requested pdf document with hash \(hash) is not opened!", details: nil)
    case PdfImageRendererError.openPageError(let page):
      return FlutterError(code: "ERR_OPEN", message: "Error while opening the pdf page \(page))", details: nil)
    default:
      return FlutterError(code: "UNKNOWN_ERROR", message: "An unknown error occured.", details: error)
    }
  }
}

enum PdfImageRendererError: Error {
  case badArguments
  case badArgument(_ argument: String)
  case openError(_ path: String)
  case closeError(_ hashValue: Int)
  case notOpen(_ hashValue: Int)
  case openPageError(_ page: Int)
}

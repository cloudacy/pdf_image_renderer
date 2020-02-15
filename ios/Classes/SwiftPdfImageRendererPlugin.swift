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
    case "getPDFPageSize":
      result(pdfPageSizeHandler(call))
    case "getPDFPageCount":
      result(pdfPageCountHandler(call))
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func pdfPageCountHandler(_ call: FlutterMethodCall) -> Any? {
    guard let arguments = call.arguments as? Dictionary<String, Any> else {
      return PdfImageRendererError.BadArguments(call)
    }
    
    guard let path = arguments["path"] as? String else {
      return PdfImageRendererError.BadArgument("path")
    }
    
    guard let pdf = CGPDFDocument(URL(fileURLWithPath: path, isDirectory: false) as CFURL) else {
      return PdfImageRendererError.PDFOpenError(path)
    }
    
    return pdf.numberOfPages
  }
  
  private func pdfPageSizeHandler(_ call: FlutterMethodCall) -> Any? {
    guard let arguments = call.arguments as? Dictionary<String, Any> else {
      return PdfImageRendererError.BadArguments(call)
    }
    
    guard let path = arguments["path"] as? String else {
      return PdfImageRendererError.BadArgument("path")
    }
    
    guard var pageIndex = arguments["page"] as? Int else {
      return PdfImageRendererError.BadArgument("page")
    }
    
    // PDF Pages in swift start with 1, so we add 1 to the pageIndex
    pageIndex += 1
    
    guard let pdf = CGPDFDocument(URL(fileURLWithPath: path, isDirectory: false) as CFURL) else {
      return PdfImageRendererError.PDFOpenError(path)
    }
    
    guard let page = pdf.page(at: pageIndex + 1) else {
      return PdfImageRendererError.PDFPageOpenError(pageIndex)
    }
    
    let pageRect = page.getBoxRect(CGPDFBox.mediaBox)
    
    return [
      "width": Int(pageRect.width),
      "height": Int(pageRect.height)
    ]
  }
}

class PdfImageRendererError: FlutterError {
  public static func BadArguments(_ call: FlutterMethodCall) -> FlutterError {
    return self.init(code: "BAD_ARGS", message: "Bad arguments type", details: "Arguments have to be of type Dictionary<String, Any> but are \(type(of: call.arguments))")
  }
  
  public static func BadArgument(_ argument: String) -> FlutterError {
    return self.init(code: "BAD_ARGS", message: "Argument '\(argument)' not set", details: nil)
  }
  
  public static func PDFOpenError(_ path: String) -> FlutterError {
    return self.init(code: "ERR_OPEN", message: "Error while opening the pdf document for path \(path))", details: nil)
  }
  
  public static func PDFPageOpenError(_ page: Int) -> FlutterError {
    return self.init(code: "ERR_OPEN", message: "Error while opening the pdf page \(page))", details: nil)
  }
  
  public static func PDFDictionaryOpenError(_ page: Int) -> FlutterError {
    return self.init(code: "ERR_OPEN", message: "Error while opening the pdf page dictionary for page \(page)", details: nil)
  }
}

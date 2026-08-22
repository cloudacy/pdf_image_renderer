import Flutter
import UIKit

public class PdfImageRendererPlugin: NSObject, FlutterPlugin {
  private let taskQueue = DispatchQueue(label: "io.cloudacy.pdf_image_renderer.tasks", qos: .userInitiated, attributes: .concurrent)
  private let pdfStateQueue = DispatchQueue(label: "io.cloudacy.pdf_image_renderer.pdf_states", attributes: .concurrent)

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "pdf_image_renderer", binaryMessenger: registrar.messenger())
    let instance = PdfImageRendererPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "openPDF":
      enqueueTask(call: call, result: result, task: openPDFHandler)
    case "closePDF":
      enqueueTask(call: call, result: result, task: closePDFHandler)
    case "openPDFPage":
      enqueueTask(call: call, result: result, task: openPDFPageHandler)
    case "closePDFPage":
      enqueueTask(call: call, result: result, task: closePDFPageHandler)
    case "renderPDFPage":
      enqueueTask(call: call, result: result, task: renderPDFPageHandler)
    case "getPDFPageSize":
      enqueueTask(call: call, result: result, task: pdfPageSizeHandler)
    case "getPDFPageCount":
      enqueueTask(call: call, result: result, task: pdfPageCountHandler)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func enqueueTask(call: FlutterMethodCall, result: @escaping FlutterResult, task: @escaping ([String: Any]) throws -> Any?) {
    taskQueue.async {
      do {
        guard let args = call.arguments as? [String: Any] else {
          throw PdfImageRendererError.badArguments
        }

        let taskResult = try task(args)

        DispatchQueue.main.async {
          result(taskResult)
        }
      } catch {
        DispatchQueue.main.async {
          result(self.handlePdfError(error))
        }
      }
    }
  }

  private func parsePageIndex(_ args: [String: Any]) throws -> Int {
    guard var pageIndex = args["page"] as? Int else {
      throw PdfImageRendererError.badArgument("page")
    }

    // PDF Pages in swift start with 1, so we add 1 to the pageIndex
    pageIndex += 1

    return pageIndex
  }

  private var _openPdfs: [Int: CGPDFDocument] = [:]
  private var _openPdfPages: [Int: [Int: CGPDFPage]] = [:]

  private func getOpenPdf(key: Int) throws -> CGPDFDocument {
    return try pdfStateQueue.sync {
      guard let openPdf = _openPdfs[key] else {
        throw PdfImageRendererError.notOpen(key)
      }

      return openPdf
    }
  }

  private func isPdfOpen(key: Int) -> Bool {
    return pdfStateQueue.sync {
      return _openPdfs.keys.contains(key)
    }
  }

  private func addOpenPdf(key: Int, pdf: CGPDFDocument) {
    pdfStateQueue.sync(flags: .barrier) {
      if _openPdfs.keys.contains(key) {
        return
      }

      _openPdfs[key] = pdf
    }
  }

  private func removeOpenPdf(key: Int) throws {
    try pdfStateQueue.sync(flags: .barrier) {
      if (!_openPdfs.keys.contains(key)) {
        throw PdfImageRendererError.closeError(key)
      }

      _openPdfPages.removeValue(forKey: key)
      _openPdfs.removeValue(forKey: key)
    }
  }

  private func getOpenPdfPage(key: Int, pageIndex: Int) throws -> CGPDFPage {
    return try pdfStateQueue.sync {
      if (!_openPdfs.keys.contains(key)) {
        throw PdfImageRendererError.notOpen(key)
      }

      guard let openPdfPagesForPdf = _openPdfPages[key],
            let openPdfPage = openPdfPagesForPdf[pageIndex] else {
        throw PdfImageRendererError.notOpen(key)
      }

      return openPdfPage
    }
  }

  private func addOpenPdfPage(key: Int, pageIndex: Int, page: CGPDFPage) throws {
    return try pdfStateQueue.sync(flags: .barrier) {
      if (!_openPdfs.keys.contains(key)) {
        throw PdfImageRendererError.notOpen(key)
      }

      if _openPdfPages[key]?.keys.contains(pageIndex) == true {
        return
      }

      _openPdfPages[key, default: [:]][pageIndex] = page
    }
  }

  private func removeOpenPdfPage(key: Int, pageIndex: Int) throws {
    try pdfStateQueue.sync(flags: .barrier) {
      if (!_openPdfs.keys.contains(key)) {
        throw PdfImageRendererError.notOpen(key)
      }

      guard var openPdfPagesForPdf = _openPdfPages[key] else {
        throw PdfImageRendererError.notOpen(key)
      }

      if (!openPdfPagesForPdf.keys.contains(pageIndex)) {
        throw PdfImageRendererError.closeError(key)
      }

      openPdfPagesForPdf.removeValue(forKey: pageIndex)

      if openPdfPagesForPdf.isEmpty {
        _openPdfPages.removeValue(forKey: key)
      } else {
        _openPdfPages[key] = openPdfPagesForPdf
      }
    }
  }

  private func openPDFHandler(args: [String: Any]) throws -> Int {
    guard let path = args["path"] as? String else {
      throw PdfImageRendererError.badArgument("path")
    }

    if (isPdfOpen(key: path.hashValue)) {
      return path.hashValue
    }

    let pathURL = URL(fileURLWithPath: path, isDirectory: false) as CFURL

    guard let pdf = CGPDFDocument(pathURL) else {
      throw PdfImageRendererError.openError(path)
    }

    // Unlock PDF if required.
    if pdf.isEncrypted && !pdf.isUnlocked {
      if let password = args["password"] as? String {
        pdf.unlockWithPassword(password)
      }

      // Check if PDF is now unlocked.
      if !pdf.isUnlocked {
        throw PdfImageRendererError.badPassword(path)
      }
    }

    addOpenPdf(key: path.hashValue, pdf: pdf)

    return path.hashValue
  }

  private func renderPdfPage(page: CGPDFPage, width: Int, height: Int, scale: Double, x: Int, y: Int) -> Data? {
    let pageRect = page.getBoxRect(.cropBox)
    let size = CGSize(width: width, height: height)

    // Get rotation angle and convert from degrees to radians:
    let angle = CGFloat(page.rotationAngle) * CGFloat.pi / 180
    let rotatedPageRect = pageRect.applying(CGAffineTransform(rotationAngle: angle))

    let transform = page.getDrawingTransform(.cropBox, rect: CGRect(x: 0, y: 0, width: Double(rotatedPageRect.width), height: Double(rotatedPageRect.height)), rotate: 0, preserveAspectRatio: true)

    let imageRendererFormat = UIGraphicsImageRendererFormat()
    imageRendererFormat.opaque = true // White background, no alpha channel required.
    imageRendererFormat.scale = scale

    let imageRenderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: imageRendererFormat)
    let image = imageRenderer.image { uiCtx in
      let ctx = uiCtx.cgContext

      UIColor.white.setFill()
      uiCtx.fill(CGRect(origin: .zero, size: size))

      ctx.translateBy(x: CGFloat(-x), y: rotatedPageRect.size.height - CGFloat(y))
      ctx.scaleBy(x: 1, y: -1)
      ctx.concatenate(transform)

      ctx.drawPDFPage(page)
    }

    return image.pngData()
  }

  private func closePDFHandler(args: [String: Any]) throws -> Int {
    guard let hash = args["pdf"] as? Int else {
      throw PdfImageRendererError.badArgument("pdf")
    }

    try removeOpenPdf(key: hash)

    return hash
  }

  private func openPDFPageHandler(args: [String: Any]) throws -> Int {
    guard let hash = args["pdf"] as? Int else {
      throw PdfImageRendererError.badArgument("pdf")
    }

    let pageIndex = try self.parsePageIndex(args)

    let pdf = try getOpenPdf(key: hash)

    guard let page = pdf.page(at: pageIndex) else {
      throw PdfImageRendererError.openPageError(pageIndex)
    }

    try addOpenPdfPage(key: hash, pageIndex: pageIndex, page: page)

    return pageIndex - 1
  }

  private func closePDFPageHandler(args: [String: Any]) throws -> Int {
    guard let hash = args["pdf"] as? Int else {
      throw PdfImageRendererError.badArgument("pdf")
    }

    let pageIndex = try self.parsePageIndex(args)

    try removeOpenPdfPage(key: hash, pageIndex: pageIndex)

    return hash
  }

  private func renderPDFPageHandler(args: [String: Any]) throws -> Data? {
    guard let hash = args["pdf"] as? Int else {
      throw PdfImageRendererError.badArgument("pdf")
    }

    let pageIndex = try self.parsePageIndex(args)

    guard let width = args["width"] as? Int else {
      throw PdfImageRendererError.badArgument("width")
    }

    guard let height = args["height"] as? Int else {
      throw PdfImageRendererError.badArgument("height")
    }

    let scale = args["scale"] as? Double ?? 1.0

    let x = args["x"] as? Int ?? 0
    let y = args["y"] as? Int ?? 0

    let page = try self.getOpenPdfPage(key: hash, pageIndex: pageIndex)

    let data = self.renderPdfPage(page: page, width: width, height: height, scale: scale, x: x, y: y)

    return data
  }

  private func pdfPageCountHandler(args: [String: Any]) throws -> Int {
    guard let hash = args["pdf"] as? Int else {
      throw PdfImageRendererError.badArgument("pdf")
    }

    let pdf = try self.getOpenPdf(key: hash)

    return pdf.numberOfPages
  }

  private func pdfPageSizeHandler(args: [String: Any]) throws -> [String: Int] {
    guard let hash = args["pdf"] as? Int else {
      throw PdfImageRendererError.badArgument("pdf")
    }

    let pageIndex = try self.parsePageIndex(args)

    let page = try self.getOpenPdfPage(key: hash, pageIndex: pageIndex)

    let pageRect = page.getBoxRect(.cropBox)
    let angle = CGFloat(page.rotationAngle) * CGFloat.pi / 180
    let rotatedPageRect = pageRect.applying(CGAffineTransform(rotationAngle: angle))

    return [
      "width": Int(rotatedPageRect.width),
      "height": Int(rotatedPageRect.height)
    ]
  }

  private func handlePdfError(_ error: Error) -> FlutterError {
    switch error {
    case PdfImageRendererError.badArguments:
      return FlutterError(code: "BAD_ARGS", message: "Bad arguments type", details: "Arguments have to be of type Dictionary<String, Any>.")
    case PdfImageRendererError.badPassword(let pdfPath):
      return FlutterError(code: "BAD_PASSWORD", message: "Bad or missing password", details: pdfPath)
    case PdfImageRendererError.badArgument(let argument):
      return FlutterError(code: "BAD_ARGS", message: "Argument \(argument) not set", details: error.localizedDescription)
    case PdfImageRendererError.openError(let path):
      return FlutterError(code: "ERR_OPEN", message: "Error while opening the pdf document for path \(path)", details: error.localizedDescription)
    case PdfImageRendererError.closeError(let hash):
      return FlutterError(code: "ERR_CLOSE", message: "Error while closing the pdf document with hash \(hash)", details: error.localizedDescription)
    case PdfImageRendererError.notOpen(let hash):
      return FlutterError(code: "ERR_NOT_OPEN", message: "The requested pdf document with hash \(hash) is not opened!", details: error.localizedDescription)
    case PdfImageRendererError.openPageError(let page):
      return FlutterError(code: "ERR_OPEN", message: "Error while opening the pdf page \(page))", details: error.localizedDescription)
    default:
      return FlutterError(code: "UNKNOWN_ERROR", message: "An unknown error occured.", details: error.localizedDescription)
    }
  }
}

enum PdfImageRendererError: Error {
  case badArguments
  case badArgument(_ argument: String)
  case badPassword(_ pdfPath: String)
  case openError(_ path: String)
  case closeError(_ hashValue: Int)
  case notOpen(_ hashValue: Int)
  case openPageError(_ page: Int)
}

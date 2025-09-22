//import SwiftUI
//import MessageUI
//
//struct MailAttachment {
//    let data: Data
//    let mimeType: String   // например "text/plain" или "image/png"
//    let fileName: String   // например "log.txt"
//}
//
//struct MailComposeView: UIViewControllerRepresentable {
//    var to: [String]
//    var subject: String
//    var body: String
//    var isHTML: Bool = false
//    var attachments: [MailAttachment] = []
//
//    @Binding var isPresented: Bool
//    @Binding var result: MFMailComposeResult?
//
//    func makeUIViewController(context: Context) -> MFMailComposeViewController {
//        let vc = MFMailComposeViewController()
//        vc.setToRecipients(to)
//        vc.setSubject(subject)
//        vc.setMessageBody(body, isHTML: isHTML)
//        attachments.forEach { a in
//            vc.addAttachmentData(a.data, mimeType: a.mimeType, fileName: a.fileName)
//        }
//        vc.mailComposeDelegate = context.coordinator
//        return vc
//    }
//
//    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
//
//    func makeCoordinator() -> Coordinator { Coordinator(self) }
//
//    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
//        let parent: MailComposeView
//        init(_ parent: MailComposeView) { self.parent = parent }
//
//        func mailComposeController(_ controller: MFMailComposeViewController,
//                                   didFinishWith result: MFMailComposeResult,
//                                   error: Error?) {
//            parent.result = result
//            parent.isPresented = false
//        }
//    }
//}
//
//extension String {
//    var urlEncoded: String {
//        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
//    }
//}
//
//extension Bundle {
//    var appName: String {
//        (object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
//        ?? (object(forInfoDictionaryKey: "CFBundleName") as? String)
//        ?? "App"
//    }
//    var appVersionBuild: String {
//        let v = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
//        let b = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
//        return "\(v) (\(b))"
//    }
//}

//
//  MailComposeView.swift
//  FitLife
//
//  Created by Виктор Корольков on 07.12.2024.
//

import SwiftUI
import MessageUI

// Компонент для отправки письма
struct MailComposeView: UIViewControllerRepresentable {
    @Binding var showMailView: Bool
    @Binding var result: MFMailComposeResult?

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients(["support@yourapp.com"]) // Email разработчиков
        vc.setSubject("Обратная связь по приложению")
        vc.setMessageBody("Здравствуйте, хотел(а) бы поделиться следующим...", isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailComposeView

        init(_ parent: MailComposeView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.result = result
            parent.showMailView = false
        }
    }
}

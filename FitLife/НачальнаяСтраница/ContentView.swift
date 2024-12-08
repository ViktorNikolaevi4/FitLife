//
//  ContentView.swift
//  FitLife
//
//  Created by Виктор Корольков on 07.12.2024.
//

import SwiftUI
import MessageUI

enum Gender: String, CaseIterable {
    case male = "Мужчина"
    case female = "Женщина"

    var imageName: String {
        switch self {
        case .male:
            return "МужскойПрофиль"
        case .female:
            return "ЖенскийПрофиль"
        }
    }
}

struct ContentView: View {
    @State private var showPopup: Bool = false
    @State private var showMailView: Bool = false
    @State private var mailComposeResult: MFMailComposeResult? = nil
    @State private var showMailErrorAlert: Bool = false
    @State private var selectedGender: Gender? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                GradientView()
                    .ignoresSafeArea()

                VStack(spacing: 100) {
                    Text("Моё Меню !")
                        .font(.title)
                        .foregroundStyle(.white)
                        .padding()

                    VStack(spacing: 100) {
                        HStack(spacing: 40) {
                            ForEach(Gender.allCases, id: \.self) { gender in
                                VStack {
                                    NavigationLink(
                                        destination: MainView(selectedGender: gender),
                                        label: {
                                            CircleView(imageName: gender.imageName)
                                                .opacity(gender == .male ? 0.8 : 1.0)
                                        }
                                    )
                                    Text(gender.rawValue)
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                }
                            }
                        }

                        VStack {
                            Button {
                                showPopup.toggle()
                            } label: {
                                Text("i")
                                    .font(.largeTitle)
                                    .foregroundStyle(.white)
                            }
                            Text("Информация")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }

                        VStack {
                            Text("Ваш личный")
                            Text("Дневник питания")
                        }
                        .foregroundStyle(.white)
                    }
                }

                if showPopup {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                showPopup = false
                            }

                        VStack(spacing: 40) {
                             HStack {
                                 Button(action: {
                                     openAppStoreRating()
                                     print("Оценить приложение")
                                 }) {
                                     VStack {
                                         Image(systemName: "star")
                                             .foregroundColor(.blue)
                                             .font(.title)
                                         Text("Оценить приложение")
                                             .foregroundColor(.blue)
                                     }
                                 }
                                 Button(action: {
                                     // Функция для "Рассказать другу"
                                     shareWithFriend()
                                     print("Рассказать другу")
                                 }) {
                                     VStack {
                                         Image(systemName: "person.2")
                                             .foregroundColor(.blue)
                                             .font(.title)
                                         Text("Рассказать другу")
                                             .foregroundColor(.blue)
                                     }
                                 }
                             }
                             HStack {
                                 Button(action: {
                                     if MFMailComposeViewController.canSendMail() {
                                         showMailView = true
                                     } else {
                                         showMailErrorAlert = true
                                     }
                                 }) {
                                     VStack {
                                         Image(systemName: "envelope")
                                             .foregroundColor(.blue)
                                             .font(.title)
                                         Text("Написать разработчикам")
                                             .foregroundColor(.blue)
                                     }
                                 }
                                 .alert(isPresented: $showMailErrorAlert) {
                                     Alert(
                                         title: Text("Ошибка"),
                                         message: Text("На устройстве не настроен почтовый аккаунт."),
                                         dismissButton: .default(Text("OK"))
                                     )
                                 }

                                 Button(action: {
                                     print("О приложении")
                                 }) {
                                     VStack {
                                         Image(systemName: "info.circle")
                                             .foregroundColor(.blue)
                                             .font(.title)
                                         Text("О приложении")
                                             .foregroundColor(.blue)
                                     }
                                 }
                             }
                             // Кнопка закрытия
                             Button(action: {
                                 showPopup = false // Закрыть всплывающее окно
                             }) {
                                 Text("OK")
                                     .font(.title)
                                     .padding()
                                     .background(Color.white)
                                     .foregroundColor(.blue)
                                     .cornerRadius(10)
                             }
                         }
                         .padding()
                         .frame(width: 300, height: 350)
                         .background(Color.white)
                         .cornerRadius(20)
                         .shadow(radius: 10)
                     }
                 }
             }
        }
        .sheet(isPresented: $showMailView) {
            MailComposeView(showMailView: $showMailView, result: $mailComposeResult)
        }
        .animation(.easeInOut, value: showPopup)
    }

    private func openAppStoreRating() {
        let appID = "1234567890"
        if let url = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    private func shareWithFriend() {
        guard let appURL = URL(string: "https://apps.apple.com/app/id1234567890") else {
            print("Некорректная ссылка на приложение")
            return
        }
        let shareText = "Попробуй это приложение: \(appURL)"
        let activityViewController = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true, completion: nil)
        }
    }
}

#Preview {
    ContentView()
}

//
//  ContentView.swift
//  FitLife
//
//  Created by Виктор Корольков on 07.12.2024.
//

import SwiftUI
import MessageUI
import SwiftData

enum Gender: String, CaseIterable, Codable {
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
    @State private var showInfoCard: Bool = false
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
                    Text("Моё Питание !")
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
                            HStack(spacing: 40) {
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
                            HStack(spacing: 40) {
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
                                     showInfoCard = true
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
                if showInfoCard {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                showInfoCard = false
                            }

                        VStack(spacing: 20) {
                            Text("Моё Питание!")
                                .font(.title)
                                .bold()
                                .foregroundColor(.blue)

                            Text("""
Моё Питание! — это приложение, предлагающее советы и рекомендации, которые помогают пользователям вести здоровый образ жизни. Приложение предоставляет информацию о пользе правильного питания, физических нагрузок и соответствующих привычек, однако при этом оно не может и не должно использоваться для постановки диагноза или лечения заболеваний. Для лечения проконсультируйтесь с врачом.
""")
                                .multilineTextAlignment(.center)
                                .font(.body)
                                .foregroundColor(.black)
                                .padding()

                            Button(action: {
                                showInfoCard = false
                            }) {
                                Text("OK")
                                    .font(.title)
                                    .bold()
                                    .padding()
                                   // .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                        .frame(width: 350)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(radius: 10)
                    }
                }
            }
        }
       // .tint(.white)
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

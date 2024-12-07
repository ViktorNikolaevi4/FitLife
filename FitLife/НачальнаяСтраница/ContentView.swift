//
//  ContentView.swift
//  FitLife
//
//  Created by Виктор Корольков on 07.12.2024.
//

import SwiftUI
import MessageUI

struct ContentView: View {
    @State private var showPopup: Bool = false // Переменная для управления отображением окна
    @State private var showMailView: Bool = false // Для управления показом MailComposeView
    @State private var mailComposeResult: MFMailComposeResult? = nil // Результат отправки
    @State private var showMailErrorAlert: Bool = false

    var body: some View {
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
                        VStack {
                            CircleView(imageName: "МужскойПрофиль")
                                .opacity(0.8)
                            Text("Мужчина")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                        VStack {
                            CircleView(imageName: "ЖенскийПрофиль")
                            Text("Женщина")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                    }

                    VStack {
                        Button {
                            showPopup.toggle() // Переключение состояния для отображения окна
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

            // Всплывающее окно
            if showPopup {
                ZStack {
                    // Полупрозрачный фон за окном
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showPopup = false // Закрыть окно при нажатии на фон
                        }

                    // Содержимое всплывающего окна
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
        .sheet(isPresented: $showMailView) {
            MailComposeView(showMailView: $showMailView, result: $mailComposeResult)
        }
        .animation(.easeInOut, value: showPopup) // Анимация появления/исчезновения окна
    }
    // Функция для перехода в App Store
  private func openAppStoreRating() {
        let appID = "1234567890" // Укажите ваш App Store ID
        if let url = URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    // Функция для "Рассказать другу"
    private func shareWithFriend() {
        guard let appURL = URL(string: "https://apps.apple.com/app/id1234567890") else {
            print("Некорректная ссылка на приложение")
            return
        }
        let shareText = "Попробуй это приложение: \(appURL)"
        let activityViewController = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        // Отображение контроллера
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true, completion: nil)
        }
    }

}

#Preview {
    ContentView()
}

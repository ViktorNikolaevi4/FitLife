//
//  BottomNavigationView.swift
//  FitLife
//
//  Created by Виктор Корольков on 10.12.2024.
//

import SwiftUI

struct BottomNavigationView: View {
    @Binding var selectedDate: Date
    var userData: UserData
    @State private var showWaterTracker = false
    @State private var showBMIPopup = false
    @State private var rationPopupView = false

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    rationPopupView = true
                }) {
                    VStack {
                        Image(systemName: "fork.knife")
                        Text("Рацион")
                    }.foregroundStyle(.white)
                }
                .sheet(isPresented: $rationPopupView) {
                    RationPopupView(gender: userData.gender, selectedDate: $selectedDate)
                        .presentationDetents([
                            .fraction(0.66), // 2/3 экрана
                            .large
                        ])
                        .presentationDragIndicator(.visible)
                }
                Spacer()
                Button(action: {
                    showWaterTracker = true
                }) {
                    VStack {
                        Image(systemName: "drop")
                        Text("Вода")
                    }.foregroundStyle(.white)
                }
                .sheet(isPresented: $showWaterTracker) {
                    WaterTrackerView(userData: userData)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
                Spacer()
                Button(action: {
                    showBMIPopup = true
                }) {
                    VStack {
                        Image(systemName: "scalemass")
                        Text("ИМТ")
                    }
                    .foregroundStyle(.white)
                }
                .sheet(isPresented: $showBMIPopup) {
                    BMIPopupView(userData: userData)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
                Spacer()
                Button(action: {}) {
                    VStack {
                        Image(systemName: "book")
                        Text("Меню")
                    }.foregroundStyle(.white)
                }
                Spacer()
                Button(action: {}) {
                    VStack {
                        Image(systemName: "arrow.up.forward")
                        Text("Стат.")
                    }.foregroundStyle(.white)
                }
                Spacer()
            }
            .padding()
            .cornerRadius(20)
            .shadow(radius: 5)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}


//
//#Preview {
//    BottomNavigationView()
//}

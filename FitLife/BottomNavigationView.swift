//
//  BottomNavigationView.swift
//  FitLife
//
//  Created by Виктор Корольков on 10.12.2024.
//

import SwiftUI

struct BottomNavigationView: View {
    var userData: UserData
    @State private var showWaterTracker = false

    var body: some View {
        HStack {
            Spacer()
            Button(action: {}) {
                VStack {
                    Image(systemName: "fork.knife")
                    Text("Рацион")
                }.foregroundStyle(.white)
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
            }
            Spacer()
            Button(action: {}) {
                VStack {
                    Image(systemName: "scalemass")
                    Text("ИМТ")
                }.foregroundStyle(.white)
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
}

//
//#Preview {
//    BottomNavigationView()
//}
